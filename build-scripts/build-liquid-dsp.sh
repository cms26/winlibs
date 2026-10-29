#!/bin/bash
# liquid-dsp for 64-bit Windows, built with upstream's CMake build.
#
# Two variants, each with release + debug/ binaries, static + DLL, and
# FFTW (single precision, static, from fftw/) for liquid's FFT-based blocks
# (spgram, fftfilt, firpfbch channelizers, OFDM, qdetector, ...):
#
#   liquid-dsp/liquid-dsp-<ver>        portable baseline (x86-64). liquid's
#       SSE / AVX / AVX-512 dot-product kernels are compiled in with
#       per-function target attributes and chosen at run time (cpuid), so
#       this build runs on any x86-64 CPU and still uses the best kernel.
#   liquid-dsp/liquid-dsp-<ver>-avx2   same, but the rest of the library is
#       also compiled with -mavx2 -mfma -mf16c. Requires an AVX2+FMA CPU
#       (illegal-instruction crash otherwise).
#
# Requires fftw/ to be built first (build-fftw.sh).
source "$(dirname "$0")/env.sh"

VER=1.8.2
FFTW="$REPO_ROOT/fftw/fftw-3.3.10"

if [ ! -d "$SRC/liquid-dsp-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/jgaeddert/liquid-dsp.git "$SRC/liquid-dsp-$VER"
fi

cd "$SRC/liquid-dsp-$VER"
# mingw-w64 has no sys/resource.h; it is only needed for getrusage-based
# timing, which liquid's timer.c does not use on Windows.
sed -i '\|#include <sys/resource.h>|d' src/core/src/timer.c
# getrusage() shim for Windows (GetProcessTimes-based), used by timer.c.
if ! grep -q timer_win32_compat src/core/src/timer.c; then
    cat > src/core/src/timer_win32_compat.h <<'SHIM'
#ifndef LIQUID_TIMER_WIN32_COMPAT_H
#define LIQUID_TIMER_WIN32_COMPAT_H
#ifdef _WIN32
#include <windows.h>
#define RUSAGE_SELF 0
struct rusage { struct timeval ru_utime; struct timeval ru_stime; };
static int getrusage(int who, struct rusage *ru)
{
    FILETIME c, e, k, u;
    ULARGE_INTEGER t;
    (void)who;
    if (!GetProcessTimes(GetCurrentProcess(), &c, &e, &k, &u))
        return -1;
    t.LowPart = u.dwLowDateTime; t.HighPart = u.dwHighDateTime;
    ru->ru_utime.tv_sec  = (long)(t.QuadPart / 10000000ULL);
    ru->ru_utime.tv_usec = (long)((t.QuadPart % 10000000ULL) / 10);
    t.LowPart = k.dwLowDateTime; t.HighPart = k.dwHighDateTime;
    ru->ru_stime.tv_sec  = (long)(t.QuadPart / 10000000ULL);
    ru->ru_stime.tv_usec = (long)((t.QuadPart % 10000000ULL) / 10);
    return 0;
}
#endif
#endif
SHIM
    sed -i 's|#include "liquid.h"|#include "liquid.h"\n#include "timer_win32_compat.h"|' src/core/src/timer.c
fi
# msvcrt-based mingw lacks TIME_UTC/timespec_get and strsep; logging.c needs both.
if ! grep -q logging_win32_compat src/core/src/logging.c; then
    cat > src/core/src/logging_win32_compat.h <<'SHIM'
#ifndef LIQUID_LOGGING_WIN32_COMPAT_H
#define LIQUID_LOGGING_WIN32_COMPAT_H
#ifdef _WIN32
#include <time.h>
#include <string.h>
#ifndef TIME_UTC
#define TIME_UTC 1
static int timespec_get(struct timespec *ts, int base)
{
    clock_gettime(CLOCK_REALTIME, ts);
    return base;
}
#endif
static char *strsep(char **stringp, const char *delim)
{
    char *start = *stringp, *p;
    if (start == NULL)
        return NULL;
    p = strpbrk(start, delim);
    if (p == NULL) {
        *stringp = NULL;
    } else {
        *p = '\0';
        *stringp = p + 1;
    }
    return start;
}
#endif
#endif
SHIM
    sed -i 's|#include "liquid.internal.h"|#include "liquid.internal.h"\n#include "logging_win32_compat.h"|' src/core/src/logging.c
fi

# mingw-w64 has no libc.a (the C runtime is msvcrt), so don't link -lc; and
# link FFTW by full path (the static library) instead of by name, which
# would pick up the FFTW import library / DLL.
python3 - CMakeLists.txt <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
if "winlibs:" not in src:
    old = """    target_link_libraries(${target} c m)
    if (fftw3f_FOUND)
        target_link_libraries(${target} fftw3f)
    endif()"""
    new = """    # winlibs: no libc.a on mingw-w64; FFTW by full path (static library)
    if (NOT MINGW)
        target_link_libraries(${target} c m)
    endif()
    if (fftw3f_FOUND)
        target_link_libraries(${target} ${fftw3f_LIBRARY})
    endif()"""
    if src.count(old) != 1:
        sys.exit("build-liquid-dsp.sh: link block not found in liquid CMakeLists.txt; patch needs updating")
    open(path, "w").write(src.replace(old, new))
PY

# FFTW's planner is not thread-safe, and liquid creates FFTW plans inside
# its objects' create() functions. Make the planner thread-safe once, when
# the library loads, so liquid objects can be created from several threads.
if ! grep -q winlibs_fftw_thread_safe src/fft/src/fft_utilities.c; then
    cat >> src/fft/src/fft_utilities.c <<'C'

#if HAVE_FFTW3_H && !defined LIQUID_FFTOVERRIDE
// winlibs: make FFTW's planner thread-safe when the library loads
__attribute__((constructor)) static void winlibs_fftw_thread_safe(void)
{
    fftwf_make_planner_thread_safe();
}
#endif
C
fi

# build_variant <prefix> <extra C flags>
build_variant() {
    local prefix="$1" extra="$2"
    rm -rf "$prefix"
    for WINLIBS_CONFIG in Release Debug; do
        export WINLIBS_CONFIG
        local iprefix="$prefix" opt="-O3 -DNDEBUG"
        [ "$WINLIBS_CONFIG" = Debug ] && { iprefix="$prefix/debug"; opt="-Og -g"; }
        local b="$BLD/liquid-dsp-$(basename "$prefix")-$WINLIBS_CONFIG"
        rm -rf "$b"
        # SIMD: detection runs test programs, which can't run when cross
        # compiling, so declare the x86 kernels available; liquid picks one
        # at run time from cpuid. FMA3/AMX are not used by liquid's kernels.
        cmake_mingw -S "$SRC/liquid-dsp-$VER" -B "$b" \
            -DCMAKE_INSTALL_PREFIX="$iprefix" \
            -DCMAKE_DEBUG_POSTFIX= \
            -DCMAKE_C_FLAGS_RELEASE="$opt $extra" -DCMAKE_C_FLAGS_DEBUG="$opt $extra" \
            -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON \
            -DBUILD_EXAMPLES=OFF -DBUILD_SANDBOX=OFF -DBUILD_DOC=OFF \
            -DBUILD_AUTOTESTS="${LIQUID_TESTS:-OFF}" -DBUILD_BENCHMARKS="${LIQUID_TESTS:-OFF}" \
            -DENABLE_TIMESTAMPS=OFF -DENABLE_COLOR=OFF \
            -DENABLE_SIMD=ON -DFIND_SIMD=OFF \
            -DC_SSE_FOUND=ON -DC_SSE2_FOUND=ON -DC_SSE3_FOUND=ON -DC_SSSE3_FOUND=ON \
            -DC_SSE41_FOUND=ON -DC_SSE42_FOUND=ON -DC_AVX_FOUND=ON -DC_AVX2_FOUND=ON \
            -DC_AVX512_FOUND=ON \
            -DFIND_FFTW=ON \
            -Dfftw3f_INCLUDE_DIR="$FFTW/include" -Dfftw3f_LIBRARY="$FFTW/lib/libfftw3f.a"
        cmake --build "$b" -j"$JOBS"
        cmake --install "$b"
    done
    # Upstream's own CMake/pkg-config files don't know the debug/ layout or
    # the static FFTW dependency; the winlibs config below replaces them.
    rm -rf "$prefix/lib/cmake" "$prefix/lib/pkgconfig"
    prune_debug_subtree "$prefix/debug"
    strip_prefix "$prefix"

    # CMake package config: package `liquid`, targets liquid::liquid (DLL)
    # and liquid::liquid-static (needs FFTW3::fftw3f + Threads, pulled in by
    # the config), upstream's names.
    local pkg="$prefix/lib/cmake/liquid"
    mkdir -p "$pkg"
    cp "$SCRIPT_DIR/liquid-dsp-cmake/liquidConfig.cmake" "$pkg/"
    cat > "$BLD/liquid-version.cmake" <<'CM'
include(CMakePackageConfigHelpers)
set(CMAKE_SIZEOF_VOID_P 8)   # 64-bit only, like the binaries
write_basic_package_version_file("${OUT}" VERSION "${VER}" COMPATIBILITY SameMinorVersion)
CM
    cmake -DVER="$VER" -DOUT="$pkg/liquidConfigVersion.cmake" -P "$BLD/liquid-version.cmake"

    # Neither DLL may depend on FFTW's DLL (FFTW is linked statically).
    if "${TRIPLET}-objdump" -p "$prefix/bin/libliquid.dll" | grep -qi 'DLL Name: *libfftw'; then
        echo "ERROR: $prefix/bin/libliquid.dll depends on the FFTW DLL" >&2
        return 1
    fi
    echo "liquid-dsp $VER installed to $prefix"
}

build_variant "$REPO_ROOT/liquid-dsp/liquid-dsp-$VER" ""
build_variant "$REPO_ROOT/liquid-dsp/liquid-dsp-$VER-avx2" "-mavx2 -mfma -mf16c"
