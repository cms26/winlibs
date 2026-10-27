#!/bin/bash
# shapelib for 64-bit Windows.
source "$(dirname "$0")/env.sh"

VER=1.6.3
PREFIX="$REPO_ROOT/shapelib/$VER"

if [ ! -d "$SRC/shapelib-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/OSGeo/shapelib.git "$SRC/shapelib-$VER"
fi

rm -rf "$PREFIX"
for WINLIBS_CONFIG in Release Debug; do
    export WINLIBS_CONFIG
    B="$BLD/shapelib-$WINLIBS_CONFIG"
    rm -rf "$B"
    cmake_mingw -S "$SRC/shapelib-$VER" -B "$B" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHAPELIB_CONTRIB=OFF -DBUILD_TESTING=OFF -DBUILD_APPS=OFF
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
    [ "$WINLIBS_CONFIG" = Release ] && strip_prefix "$PREFIX"
done
echo "shapelib $VER installed to $PREFIX"
