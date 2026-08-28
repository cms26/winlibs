#!/bin/bash
# FlatBuffers for 64-bit Windows: libflatbuffers + flatc.exe.
source "$(dirname "$0")/env.sh"

VER=25.12.19
PREFIX="$REPO_ROOT/flatbuffer/$VER"

if [ ! -d "$SRC/flatbuffers-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/google/flatbuffers.git "$SRC/flatbuffers-$VER"
fi

B="$BLD/flatbuffers"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/flatbuffers-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DFLATBUFFERS_BUILD_TESTS=OFF -DFLATBUFFERS_BUILD_FLATC=ON \
    -DFLATBUFFERS_BUILD_SHAREDLIB=ON
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "flatbuffers $VER installed to $PREFIX"
