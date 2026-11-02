#!/bin/bash
# FFTW 3.3.10, double (fftw3) and single (fftw3f) precision, shared + static,
# threads, SSE2/AVX/AVX2(+FMA) codelets chosen at run time. Same CMake
# fixes as the Windows build (build-scripts/build-fftw.sh): real version
# number and per-directory SIMD flags, so the library runs on any x86-64 CPU.
source "$(dirname "$0")/env.sh"

VER=$FFTW_VER
PREFIX="$PREFIX_ROOT/fftw/fftw-$VER"

if [ ! -d "$SRC/fftw-$VER" ]; then
    curl -sSfL -o "$SRC/fftw-$VER.tar.gz" \
        "https://archive.ubuntu.com/ubuntu/pool/main/f/fftw3/fftw3_$VER.orig.tar.gz"
    tar -C "$SRC" -xf "$SRC/fftw-$VER.tar.gz"
    mv "$SRC/fftw3-$VER" "$SRC/fftw-$VER"
fi
sed -i "s/^set (FFTW_VERSION [0-9.]*)/set (FFTW_VERSION $VER)/" "$SRC/fftw-$VER/CMakeLists.txt"

# Per-directory SIMD flags: the patch is shared with the Windows script.
# Extract it from there so both builds stay identical.
python3 - "$WIN_SCRIPTS/build-fftw.sh" "$SRC/fftw-$VER/CMakeLists.txt" <<'PY'
import re, sys
script, path = sys.argv[1], sys.argv[2]
s = open(script).read()
patch = re.search(r"python3 - \"\$SRC/fftw-\$VER/CMakeLists.txt\" <<'PY'\n(.*?)\nPY\n", s, re.S)
if not patch:
    sys.exit("build-fftw.sh (linux): SIMD patch not found in the Windows build script")
sys.argv = ["patch", path]
exec(patch.group(1))
PY
grep -q "winlibs: per-directory SIMD flags" "$SRC/fftw-$VER/CMakeLists.txt"

rm -rf "$PREFIX"
# Shared builds first, then static (see the Windows script: the static
# install must come last so the CMake package keeps the static targets).
for linkage in shared static; do
    SHARED=OFF; [ "$linkage" = shared ] && SHARED=ON
    for cfg in double single; do
        EXTRA=""
        [ "$cfg" = single ] && EXTRA="-DENABLE_FLOAT=ON -DENABLE_SSE=ON"
        B="$BLD/fftw-$cfg-$linkage"
        rm -rf "$B"
        cmake_native -S "$SRC/fftw-$VER" -B "$B" \
            -DCMAKE_INSTALL_PREFIX="$PREFIX" \
            -DBUILD_SHARED_LIBS=$SHARED -DBUILD_TESTS=OFF \
            -DENABLE_SSE2=ON -DENABLE_AVX=ON -DENABLE_AVX2=ON \
            -DENABLE_THREADS=ON -DWITH_COMBINED_THREADS=ON \
            $EXTRA
        cmake --build "$B" -j"$JOBS"
        cmake --install "$B"
        rm -rf "$B"
    done
done
strip_prefix "$PREFIX"

# The generic code must not use AVX: check one non-SIMD object's worth by
# disassembling the planner entry point for VEX-encoded (v*) instructions.
# (grep -c, not grep -q: with pipefail, grep -q's early exit makes the
# producer fail with SIGPIPE.)
AVX_INSNS=$(objdump -d --no-show-raw-insn "$PREFIX/lib/libfftw3f.a" 2>/dev/null \
    | awk '/<fftwf_plan_dft_1d>:/{f=1;next} /^$/{f=0} f' | grep -cE '\sv[a-z]+' || true)
if [ "$AVX_INSNS" -ne 0 ]; then
    echo "ERROR: fftwf_plan_dft_1d uses AVX instructions (SIMD flags leaked)" >&2
    exit 1
fi
for p in fftw3 fftw3f; do
    [ -f "$PREFIX/lib/cmake/$p/FFTW3LibraryDepends-release.cmake" ] || {
        echo "ERROR: lib/cmake/$p/FFTW3LibraryDepends-release.cmake missing" >&2; exit 1; }
done
echo "fftw $VER installed to $PREFIX"
