#!/bin/bash
# Protocol Buffers (gpb) 36.0: static libraries (position independent) with
# bundled Abseil, plus protoc. Same legacy layout as the Windows tree, so
# CMake paths match on both platforms:
#   gpb/<ver>/bin/        protoc and plugins
#   gpb/<ver>/c++/        headers (google/, absl/, upb/, ...)
#   gpb/<ver>/c++/lib/    static libs + cmake/pkgconfig files
# Qt's qtgrpc module (qt_add_protobuf, QtProtobuf) is built against this.
source "$(dirname "$0")/env.sh"

VER=$PROTOBUF_VER
PREFIX="$PREFIX_ROOT/gpb/$VER"

if [ ! -d "$SRC/protobuf-$VER" ]; then
    git clone -q --depth 1 --branch "v$VER" --recurse-submodules --shallow-submodules \
        https://github.com/protocolbuffers/protobuf.git "$SRC/protobuf-$VER"
fi

B="$BLD/protobuf"
rm -rf "$B" "$PREFIX"
# protoc linked with static libstdc++/libgcc so the tool itself runs
# anywhere (it is only a build tool).
cmake_native -S "$SRC/protobuf-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX/c++" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_PROTOC_BINARIES=ON \
    -Dprotobuf_WITH_ZLIB=ON
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
rm -rf "$B"
strip_prefix "$PREFIX"

# Legacy layout (same transformation as build-scripts/build-protobuf.sh).
mv "$PREFIX/c++/bin" "$PREFIX/bin"
mv "$PREFIX/c++/include/"* "$PREFIX/c++/"
rmdir "$PREFIX/c++/include"
{ grep -rl '${_IMPORT_PREFIX}/include' "$PREFIX/c++/lib/cmake" || true; } | while read -r f; do
    sed -i 's|${_IMPORT_PREFIX}/include|${_IMPORT_PREFIX}|g' "$f"
done
{ grep -rl '${_IMPORT_PREFIX}/bin/' "$PREFIX/c++/lib/cmake" || true; } | while read -r f; do
    sed -i 's|${_IMPORT_PREFIX}/bin/|${_IMPORT_PREFIX}/../bin/|g' "$f"
done
find "$PREFIX/c++/lib/pkgconfig" -name '*.pc' | while read -r f; do
    sed -i 's|^prefix=.*|prefix=${pcfiledir}/../..|; s|^exec_prefix=.*|exec_prefix=${prefix}|; s|^libdir=.*|libdir=${prefix}/lib|; s|^includedir=.*|includedir=${prefix}|' "$f"
done
"$PREFIX/bin/protoc" --version
echo "protobuf $VER installed to $PREFIX"
