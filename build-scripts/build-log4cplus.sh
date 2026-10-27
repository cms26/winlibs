#!/bin/bash
# log4cplus for 64-bit Windows.
source "$(dirname "$0")/env.sh"

VER=2.2.0.1
TAG=REL_2_2_0_1
PREFIX="$REPO_ROOT/log4cplus/log4cplus-$VER"

if [ ! -d "$SRC/log4cplus-$VER" ]; then
    curl -sSfL -o "$SRC/log4cplus-$VER.tar.xz" \
        "https://github.com/log4cplus/log4cplus/releases/download/$TAG/log4cplus-$VER.tar.xz"
    tar -C "$SRC" -xf "$SRC/log4cplus-$VER.tar.xz"
fi

rm -rf "$PREFIX"
for WINLIBS_CONFIG in Release Debug; do
    export WINLIBS_CONFIG
    B="$BLD/log4cplus-$WINLIBS_CONFIG"
    rm -rf "$B"
    cmake_mingw -S "$SRC/log4cplus-$VER" -B "$B" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DLOG4CPLUS_BUILD_TESTING=OFF -DLOG4CPLUS_BUILD_LOGGINGSERVER=OFF \
        -DWITH_UNIT_TESTS=OFF
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
    [ "$WINLIBS_CONFIG" = Release ] && strip_prefix "$PREFIX"
done
echo "log4cplus $VER installed to $PREFIX"
