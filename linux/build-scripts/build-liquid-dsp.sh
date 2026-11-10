#!/bin/bash
# liquid-dsp 1.8.2 with the same performance setup as the Windows build
# (build-scripts/build-liquid-dsp.sh): SSE/AVX dot-product kernels chosen at
# run time (any x86-64 CPU), portable loop below 16 taps, trace logging
# compiled out, -O2 instead of upstream's forced -O3, and FFTW (static,
# single precision) actually enabled for the FFT-based blocks, with a
# thread-safe planner. Shared (libliquid.so, FFTW linked in, not exported)
# and static (libliquid.a, needs FFTW3::fftw3f) libraries.
#
# Requires build-fftw.sh.
source "$(dirname "$0")/env.sh"

VER=1.8.3
PREFIX="$PREFIX_ROOT/liquid-dsp/liquid-dsp-$VER"
FFTW="$PREFIX_ROOT/fftw/fftw-$FFTW_VER"

rm -rf "$SRC/liquid-dsp-$VER"
git clone -q --depth 1 --branch "v$VER" https://github.com/jgaeddert/liquid-dsp.git "$SRC/liquid-dsp-$VER"
cd "$SRC/liquid-dsp-$VER"

# Link FFTW by full path (the static library, not libfftw3f.so) and let the
# build type choose the optimization level (upstream forces -O3, at which
# GCC turns the portable dot product into slower code).
python3 - CMakeLists.txt <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
old = """    if (fftw3f_FOUND)
        target_link_libraries(${target} fftw3f)
    endif()"""
new = """    if (fftw3f_FOUND)
        target_link_libraries(${target} ${fftw3f_LIBRARY})  # winlibs: static FFTW by path
    endif()"""
if src.count(old) != 1:
    sys.exit("liquid: FFTW link block not found in CMakeLists.txt; patch needs updating")
src = src.replace(old, new)
opt_old = "add_compile_options(-Wall -fPIC -O3)"
if src.count(opt_old) != 1:
    sys.exit("liquid: -O3 compile options not found in CMakeLists.txt; patch needs updating")
src = src.replace(opt_old, "add_compile_options(-Wall -fPIC)  # winlibs: optimization from the build type")
open(path, "w").write(src)
PY

# Portable kernel for very short vectors (faster than SIMD below 16 taps).
python3 - src/dotprod/src/dotprod.proto.c <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
old = """    // given implementations, find best method
    liquid_runtime_t selection = liquid_runtime_detect(&impl);"""
new = """    // winlibs: the portable loop is faster than the SIMD kernels for very
    // short vectors
    if (_q->n < 16)
        return DOTPROD(_runtime_select)(_q, LIQUID_RUNTIME_PORT);

    // given implementations, find best method
    liquid_runtime_t selection = liquid_runtime_detect(&impl);"""
if src.count(old) != 1:
    sys.exit("liquid: runtime_detect block not found in dotprod.proto.c; patch needs updating")
open(path, "w").write(src.replace(old, new))
PY

# Thread-safe FFTW planner (liquid creates plans in its create() functions).
cat >> src/fft/src/fft_utilities.c <<'C'

#if HAVE_FFTW3_H && !defined LIQUID_FFTOVERRIDE
// winlibs: make FFTW's planner thread-safe when the library loads
__attribute__((constructor)) static void winlibs_fftw_thread_safe(void)
{
    fftwf_make_planner_thread_safe();
}
#endif
C

B="$BLD/liquid-dsp"
rm -rf "$B" "$PREFIX"
OPT="-O2 -DNDEBUG -DLIQUID_LOG_LEVEL_COMPILE=2 -DHAVE_FFTW3_H=1 -I$FFTW/include"
# SIMD kernels declared available and picked at run time from cpuid
# (detection would otherwise tie the build to the build machine's CPU).
# AVX-512 left out (slower on liquid's misaligned sliding-window loads).
cmake_native -S "$SRC/liquid-dsp-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_FLAGS_RELEASE="$OPT" \
    -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON \
    -DBUILD_EXAMPLES=OFF -DBUILD_SANDBOX=OFF -DBUILD_DOC=OFF \
    -DBUILD_AUTOTESTS="${LIQUID_TESTS:-OFF}" -DBUILD_BENCHMARKS="${LIQUID_TESTS:-OFF}" \
    -DENABLE_TIMESTAMPS=OFF -DENABLE_COLOR=OFF \
    -DENABLE_SIMD=ON -DFIND_SIMD=OFF \
    -DC_SSE_FOUND=ON -DC_SSE2_FOUND=ON -DC_SSE3_FOUND=ON -DC_SSSE3_FOUND=ON \
    -DC_SSE41_FOUND=ON -DC_SSE42_FOUND=ON -DC_AVX_FOUND=ON -DC_AVX2_FOUND=ON \
    -DC_AVX512_FOUND=OFF \
    -DFIND_FFTW=ON \
    -Dfftw3f_INCLUDE_DIR="$FFTW/include" -Dfftw3f_LIBRARY="$FFTW/lib/libfftw3f.a" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--exclude-libs,libfftw3f.a"
cmake --build "$B" -j"$JOBS"
if [ "${LIQUID_TESTS:-OFF}" = ON ]; then (cd "$B" && ./xautotest -q); fi
cmake --install "$B"
rm -rf "$B"
# Upstream's CMake/pkg-config files don't know the static FFTW dependency;
# the winlibs config replaces them.
rm -rf "$PREFIX/lib/cmake" "$PREFIX/lib/pkgconfig"
strip_prefix "$PREFIX"

PKG="$PREFIX/lib/cmake/liquid"
mkdir -p "$PKG"
cp "$SCRIPT_DIR/cmake/liquidConfig.cmake" "$PKG/"
cat > "$BLD/liquid-version.cmake" <<'CM'
include(CMakePackageConfigHelpers)
set(CMAKE_SIZEOF_VOID_P 8)
write_basic_package_version_file("${OUT}" VERSION "${VER}" COMPATIBILITY SameMinorVersion)
CM
cmake -DVER="$VER" -DOUT="$PKG/liquidConfigVersion.cmake" -P "$BLD/liquid-version.cmake"

# Checks (grep -c: see build-fftw.sh): liquid really calls FFTW, the shared
# library neither exports FFTW's symbols nor needs libfftw3f.so.
SO=$(readlink -f "$PREFIX/lib/libliquid.so")
[ "$(nm "$PREFIX/lib/libliquid.a" 2>/dev/null | grep -c ' U fftwf_plan_dft_1d' || true)" -gt 0 ] \
    || { echo "ERROR: libliquid.a does not use FFTW" >&2; exit 1; }
[ "$(nm -D --defined-only "$SO" | grep -c ' fftwf\?_' || true)" -eq 0 ] \
    || { echo "ERROR: libliquid.so exports FFTW symbols" >&2; exit 1; }
[ "$(readelf -d "$SO" | grep -c 'NEEDED.*libfftw' || true)" -eq 0 ] \
    || { echo "ERROR: libliquid.so depends on libfftw3f.so" >&2; exit 1; }
echo "liquid-dsp $VER installed to $PREFIX"
