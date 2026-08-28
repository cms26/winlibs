#!/bin/bash
# zlib for 64-bit Windows (mingw-w64 cross build). Support library used by
# openssl/libssh/qt consumers; shared + static.
source "$(dirname "$0")/env.sh"

VER=1.3.2
PREFIX="$REPO_ROOT/zlib/zlib-$VER"

if [ ! -d "$SRC/zlib-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/madler/zlib.git "$SRC/zlib-$VER"
fi

B="$BLD/zlib"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/zlib-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DZLIB_BUILD_TESTING=OFF -DZLIB_BUILD_MINIZIP=OFF
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "zlib $VER installed to $PREFIX"
