#!/bin/bash
# Protocol Buffers (gpb) for 64-bit Windows: static libs + protoc.exe,
# with bundled Abseil.
source "$(dirname "$0")/env.sh"

VER=36.0
PREFIX="$REPO_ROOT/gpb/protobuf-$VER"
ZLIB="$REPO_ROOT/zlib/zlib-1.3.2"

if [ ! -d "$SRC/protobuf-$VER" ]; then
    git clone --depth 1 --branch "v$VER" --recurse-submodules --shallow-submodules \
        https://github.com/protocolbuffers/protobuf.git "$SRC/protobuf-$VER"
fi

B="$BLD/protobuf"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/protobuf-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_PREFIX_PATH="$ZLIB" -DZLIB_ROOT="$ZLIB" \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_PROTOC_BINARIES=ON \
    -Dprotobuf_WITH_ZLIB=ON
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "protobuf $VER installed to $PREFIX"
