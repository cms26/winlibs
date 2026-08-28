#!/bin/bash
# Boost for 64-bit Windows (b2 cross build, shared + static, tagged layout).
# Everything except python/mpi/graph_parallel.
source "$(dirname "$0")/env.sh"

VER=1.92.0
PREFIX="$REPO_ROOT/boost/boost-$VER"

if [ ! -d "$SRC/boost-$VER" ]; then
    curl -sSfL -o "$SRC/boost-$VER.tar.xz" \
        "https://github.com/boostorg/boost/releases/download/boost-$VER/boost-$VER-b2-nodocs.tar.xz"
    tar -C "$SRC" -xf "$SRC/boost-$VER.tar.xz"
fi

cd "$SRC/boost-$VER"
[ -x b2 ] || ./bootstrap.sh
echo "using gcc : mingw : $CXX_MINGW : <archiver>${TRIPLET}-ar <ranlib>${TRIPLET}-ranlib <rc>${TRIPLET}-windres ;" > user-config.jam

rm -rf "$PREFIX"
./b2 --user-config=user-config.jam \
    toolset=gcc-mingw target-os=windows address-model=64 architecture=x86 \
    variant=release link=shared,static runtime-link=shared threading=multi \
    --layout=tagged --prefix="$PREFIX" \
    --without-python --without-mpi --without-graph_parallel \
    -j"$JOBS" install
strip_prefix "$PREFIX"
echo "boost $VER installed to $PREFIX"
