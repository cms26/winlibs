#!/bin/bash
# FlatBuffers for 64-bit Windows: libflatbuffers + flatc.exe.
source "$(dirname "$0")/env.sh"

VER=25.12.19
PREFIX="$REPO_ROOT/flatbuffer/$VER"

if [ ! -d "$SRC/flatbuffers-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/google/flatbuffers.git "$SRC/flatbuffers-$VER"
fi

rm -rf "$PREFIX"
for WINLIBS_CONFIG in Release Debug; do
    export WINLIBS_CONFIG
    # flatc.exe is a build tool, not a library; no debug variant needed.
    FLATC=ON; [ "$WINLIBS_CONFIG" = Debug ] && FLATC=OFF
    IPREFIX="$PREFIX"; [ "$WINLIBS_CONFIG" = Debug ] && IPREFIX="$PREFIX/debug"
    B="$BLD/flatbuffers-$WINLIBS_CONFIG"
    rm -rf "$B"
    cmake_mingw -S "$SRC/flatbuffers-$VER" -B "$B" \
        -DCMAKE_INSTALL_PREFIX="$IPREFIX" \
        -DFLATBUFFERS_BUILD_TESTS=OFF -DFLATBUFFERS_BUILD_FLATC=$FLATC \
        -DFLATBUFFERS_BUILD_SHAREDLIB=ON
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
done
prune_debug_subtree "$PREFIX/debug"
strip_prefix "$PREFIX"
echo "flatbuffers $VER installed to $PREFIX"
