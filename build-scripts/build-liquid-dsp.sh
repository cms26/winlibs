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
