#!/bin/bash
# liquid-dsp for 64-bit Windows (autotools cross build).
source "$(dirname "$0")/env.sh"

VER=1.8.2
PREFIX="$REPO_ROOT/liquid-dsp/liquid-dsp-$VER"

if [ ! -d "$SRC/liquid-dsp-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/jgaeddert/liquid-dsp.git "$SRC/liquid-dsp-$VER"
fi

cd "$SRC/liquid-dsp-$VER"
# mingw-w64 has no libc.a (the C runtime is msvcrt); relax the hard
# AC_CHECK_LIB([c],...) error so the cross configure can proceed.
sed -i 's|AC_CHECK_LIB(\[c\],\[main\],\[\],\[AC_MSG_ERROR(Could not use standard C library)\],   \[\])|AC_CHECK_LIB([c],[main],[],[AC_MSG_WARN(no separate libc; assuming msvcrt)],[])|' configure.ac
# mingw-w64 has no sys/resource.h; it is only needed for getrusage-based
# timing, which liquid's timer.c does not use on Windows.
sed -i 's|getopt.h sys/resource.h float.h|getopt.h float.h|' configure.ac
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
rm -f configure
./bootstrap.sh
rm -rf "$PREFIX"
make distclean >/dev/null 2>&1 || true
CC="$CC_MINGW" CXX="$CXX_MINGW" ./configure \
    --host=$TRIPLET --prefix="$PREFIX" \
    --enable-simdoverride
make -s -j"$JOBS"
make -s install
strip_prefix "$PREFIX"
echo "liquid-dsp $VER installed to $PREFIX"
