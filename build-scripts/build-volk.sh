#!/bin/bash
# VOLK (Vector Optimized Library of Kernels) for 64-bit Windows.
# Requires python3-mako on the build host.
source "$(dirname "$0")/env.sh"

VER=3.3.0
PREFIX="$REPO_ROOT/volk-$VER"

if [ ! -d "$SRC/volk-$VER" ]; then
    git clone --recursive --depth 1 --branch "v$VER" https://github.com/gnuradio/volk.git "$SRC/volk-$VER"
fi

rm -rf "$PREFIX"
for WINLIBS_CONFIG in Release Debug; do
    export WINLIBS_CONFIG
    IPREFIX="$PREFIX"; [ "$WINLIBS_CONFIG" = Debug ] && IPREFIX="$PREFIX/debug"
    B="$BLD/volk-$WINLIBS_CONFIG"
    rm -rf "$B"
    cmake_mingw -S "$SRC/volk-$VER" -B "$B" \
        -DCMAKE_INSTALL_PREFIX="$IPREFIX" \
        -DENABLE_TESTING=OFF -DENABLE_MODTOOL=OFF \
        -DCMAKE_CROSSCOMPILING_EMULATOR=/bin/false
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
done
prune_debug_subtree "$PREFIX/debug"
strip_prefix "$PREFIX"
echo "volk $VER installed to $PREFIX"
