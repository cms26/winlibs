#!/bin/bash
# Protocol Buffers (gpb) for 64-bit Windows: static libs + protoc.exe,
# with bundled Abseil.
#
# Installed in the legacy codelibrary layout:
#   gpb/<ver>/bin/            protoc.exe and plugins
#   gpb/<ver>/c++/            headers (google/, absl/, upb/, ...)
#   gpb/<ver>/c++/lib/        static libs + cmake/pkgconfig files
source "$(dirname "$0")/env.sh"

VER=36.0
PREFIX="$REPO_ROOT/gpb/$VER"
ZLIB="$REPO_ROOT/zlib/zlib-1.3.2"

if [ ! -d "$SRC/protobuf-$VER" ]; then
    git clone --depth 1 --branch "v$VER" --recurse-submodules --shallow-submodules \
        https://github.com/protocolbuffers/protobuf.git "$SRC/protobuf-$VER"
fi

B="$BLD/protobuf"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/protobuf-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX/c++" \
    -DCMAKE_PREFIX_PATH="$ZLIB" -DZLIB_ROOT="$ZLIB" \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_PROTOC_BINARIES=ON \
    -Dprotobuf_WITH_ZLIB=ON
cmake --build "$B" -j"$JOBS"
cmake --install "$B"

# Debug variant into c++/debug/lib. -Og -g1 keeps the static archives under
# GitHub's 100 MB per-file limit while keeping assertions, backtraces and
# line-level stepping. protoc is a build tool; no debug variant.
WINLIBS_CONFIG=Debug; export WINLIBS_CONFIG
BD="$BLD/protobuf-debug"
rm -rf "$BD"
cmake_mingw -S "$SRC/protobuf-$VER" -B "$BD" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX/c++/debug" \
    -DCMAKE_C_FLAGS_DEBUG="-Og -g1" -DCMAKE_CXX_FLAGS_DEBUG="-Og -g1" \
    -DCMAKE_PREFIX_PATH="$ZLIB" -DZLIB_ROOT="$ZLIB" \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
    -Dprotobuf_WITH_ZLIB=ON
cmake --build "$BD" -j"$JOBS"
cmake --install "$BD"
prune_debug_subtree "$PREFIX/c++/debug"
rm -rf "$PREFIX/c++/debug/bin"
unset WINLIBS_CONFIG

# Rearrange into the legacy layout: tools out of c++/, headers at c++/ root.
mv "$PREFIX/c++/bin" "$PREFIX/bin"
mv "$PREFIX/c++/include/"* "$PREFIX/c++/"
rmdir "$PREFIX/c++/include"
# Keep the cmake package configs working from their new location
# (configs live at c++/lib/cmake/<pkg>, so _IMPORT_PREFIX = c++).
grep -rl '${_IMPORT_PREFIX}/include' "$PREFIX/c++/lib/cmake" | while read -r f; do
    sed -i 's|${_IMPORT_PREFIX}/include|${_IMPORT_PREFIX}|g' "$f"
done
grep -rl '${_IMPORT_PREFIX}/bin/' "$PREFIX/c++/lib/cmake" | while read -r f; do
    sed -i 's|${_IMPORT_PREFIX}/bin/|${_IMPORT_PREFIX}/../bin/|g' "$f"
done
# Relocatable pkg-config files (headers sit at the c++ prefix root).
find "$PREFIX/c++/lib/pkgconfig" -name '*.pc' | while read -r f; do
    sed -i 's|^prefix=.*|prefix=${pcfiledir}/../..|; s|^exec_prefix=.*|exec_prefix=${prefix}|; s|^libdir=.*|libdir=${prefix}/lib|; s|^includedir=.*|includedir=${prefix}|' "$f"
done

strip_prefix "$PREFIX"
echo "protobuf $VER installed to $PREFIX"
