#!/bin/bash
# FFTW 3.3.10 for 64-bit Windows — double (fftw3) and single (fftw3f)
# precision, with SIMD codelets and threads. Shared + static.
source "$(dirname "$0")/env.sh"

VER=3.3.10
PREFIX="$REPO_ROOT/fftw/fftw-$VER"

if [ ! -d "$SRC/fftw-$VER" ]; then
    # fftw.org mirror of record; Ubuntu archive carries the identical tarball.
    curl -sSfL -o "$SRC/fftw-$VER.tar.gz" \
        "https://archive.ubuntu.com/ubuntu/pool/main/f/fftw3/fftw3_$VER.orig.tar.gz"
    tar -C "$SRC" -xf "$SRC/fftw-$VER.tar.gz"
    mv "$SRC/fftw3-$VER" "$SRC/fftw-$VER"
fi
# FFTW 3.3.10's CMakeLists.txt still says `set (FFTW_VERSION 3.3.9)`, so the
# installed FFTW3(f)ConfigVersion.cmake and .pc files report 3.3.9 and
# find_package(FFTW3 3.3.10) fails. Use the real version.
sed -i "s/^set (FFTW_VERSION [0-9.]*)/set (FFTW_VERSION $VER)/" "$SRC/fftw-$VER/CMakeLists.txt"

# FFTW's CMake build adds the SSE/SSE2/AVX/AVX2/FMA flags to the *whole*
# library, so the generic code, the planner and even the SSE2 codelets are
# compiled with AVX2+FMA and the library crashes (illegal instruction) on
# CPUs without them, defeating FFTW's runtime CPU detection. Apply each flag
# only to its own SIMD codelet directories, as FFTW's autotools build does.
python3 - "$SRC/fftw-$VER/CMakeLists.txt" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path).read()
if "winlibs: per-directory SIMD flags" in src:
    sys.exit(0)
pattern = re.compile(
    r"if \(HAVE_SSE\)\n  target_compile_options \(\$\{fftw3_lib\} PRIVATE \$\{SSE_FLAG\}\)\nendif \(\)\n"
    r"if \(HAVE_SSE2\)\n  target_compile_options \(\$\{fftw3_lib\} PRIVATE \$\{SSE2_FLAG\}\)\nendif \(\)\n"
    r"if \(HAVE_AVX\)\n  target_compile_options \(\$\{fftw3_lib\} PRIVATE \$\{AVX_FLAG\}\)\nendif \(\)\n"
    r"if \(HAVE_AVX2\)\n  target_compile_options \(\$\{fftw3_lib\} PRIVATE \$\{AVX2_FLAG\}\)\nendif \(\)\n"
    r"if \(HAVE_FMA\)\n  target_compile_options \(\$\{fftw3_lib\} PRIVATE \$\{FMA_FLAG\}\)\nendif \(\)\n")
replacement = """# winlibs: per-directory SIMD flags (as in FFTW's autotools build), so the
# rest of the library stays baseline and runtime CPU detection works.
if (HAVE_SSE2)
  set (_winlibs_sse2_opts ${SSE_FLAG} ${SSE2_FLAG})
  set_source_files_properties (${fftw_dft_simd_sse2_SOURCE} ${fftw_rdft_simd_sse2_SOURCE}
    PROPERTIES COMPILE_OPTIONS "${_winlibs_sse2_opts}")
endif ()
if (HAVE_AVX)
  set_source_files_properties (${fftw_dft_simd_avx_SOURCE} ${fftw_rdft_simd_avx_SOURCE}
    PROPERTIES COMPILE_OPTIONS "${AVX_FLAG}")
endif ()
if (HAVE_AVX2)
  set_source_files_properties (${fftw_dft_simd_avx2_SOURCE} ${fftw_rdft_simd_avx2_SOURCE}
    PROPERTIES COMPILE_OPTIONS "${AVX2_FLAG};${FMA_FLAG}")
endif ()
"""
new, n = pattern.subn(replacement, src)
if n != 1:
    sys.exit("build-fftw.sh: SIMD flag block not found in FFTW CMakeLists.txt; patch needs updating")
open(path, "w").write(new)
PY

rm -rf "$PREFIX"
# Install order matters for the CMake package: shared and static installs
# write different FFTW3LibraryDepends.cmake files (SHARED vs STATIC IMPORTED
# targets), and whenever that file changes CMake deletes the other
# configurations' FFTW3LibraryDepends-<config>.cmake. Installing
# Release, Debug, shared, static (the old order) left only the static Debug
# configuration, so *Release* consumers of FFTW3::fftw3f linked the
# unoptimized debug library. Install all shared builds first, then static
# Release and static Debug back to back, so the package keeps both
# configurations of the (static) targets.
for linkage in shared static; do
  SHARED=OFF; [ "$linkage" = shared ] && SHARED=ON
  for WINLIBS_CONFIG in Release Debug; do
    export WINLIBS_CONFIG
    for cfg in double single; do
        EXTRA=""
        if [ "$cfg" = single ]; then EXTRA="-DENABLE_FLOAT=ON -DENABLE_SSE=ON"; fi
        B="$BLD/fftw-$cfg-$linkage-$WINLIBS_CONFIG"
        rm -rf "$B"
        cmake_mingw -S "$SRC/fftw-$VER" -B "$B" \
            -DCMAKE_INSTALL_PREFIX="$PREFIX" \
            -DBUILD_SHARED_LIBS=$SHARED \
            -DBUILD_TESTS=OFF \
            -DCMAKE_C_FLAGS="-DWITH_OUR_MALLOC" \
            -DENABLE_SSE2=ON -DENABLE_AVX=ON -DENABLE_AVX2=ON \
            -DENABLE_THREADS=ON -DWITH_COMBINED_THREADS=ON \
            $EXTRA
        cmake --build "$B" -j"$JOBS"
        cmake --install "$B"
    done
  done
done

# Strip the release binaries only (debug ones keep their symbols; they share
# lib/ and bin/ with a 'd' suffix, so strip_prefix can't tell them apart).
for f in "$PREFIX"/bin/libfftw3.dll "$PREFIX"/bin/libfftw3f.dll; do
    "$STRIP" --strip-unneeded "$f"
done
for f in "$PREFIX"/lib/libfftw3.a "$PREFIX"/lib/libfftw3f.a; do
    "$STRIP" --strip-debug "$f"
done

# Both configurations must be in the CMake package.
for p in fftw3 fftw3f; do
    for c in release debug; do
        [ -f "$PREFIX/lib/cmake/$p/FFTW3LibraryDepends-$c.cmake" ] || {
            echo "ERROR: lib/cmake/$p/FFTW3LibraryDepends-$c.cmake missing" >&2; exit 1; }
    done
done
echo "fftw $VER installed to $PREFIX"
