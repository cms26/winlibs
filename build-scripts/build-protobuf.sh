#!/bin/bash
# Protocol Buffers (gpb) for 64-bit Windows: static libs + protoc.exe,
# with bundled Abseil.
source "$(dirname "$0")/env.sh"

VER=36.0
PREFIX="$REPO_ROOT/gpb/protobuf-$VER"
ZLIB="$REPO_ROOT/zlib/zlib-1.3.2"

if [ ! -d "$SRC/protobuf-$VER" ]; then
    curl -sSfL -o "$SRC/protobuf-$VER.tar.gz" \
        "https://github.com/protocolbuffers/protobuf/releases/download/v$VER/protobuf-$VER.tar.gz"
    tar -C "$SRC" -xf "$SRC/protobuf-$VER.tar.gz"
fi

B="$BLD/protobuf"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/protobuf-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_PREFIX_PATH="$ZLIB" -DZLIB_ROOT="$ZLIB" \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_PROTOC_BINARIES=ON \
    -Dprotobuf_ABSL_PROVIDER=module \
    -Dprotobuf_WITH_ZLIB=ON
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "protobuf $VER installed to $PREFIX"
