#!/bin/bash
# Boost for 64-bit Windows (b2 cross build, shared + static, tagged layout).
# Everything except python/mpi/graph_parallel.
#
#   build-boost.sh [version]     (default 1.92.0)
#
# Each version installs to its own boost/boost-<version> prefix, so several
# can coexist. build-boost-1.86.sh uses this for the 1.86.0 install kept for
# code that still needs the classic Boost.Asio API (io_service, etc.) that
# Boost removed in 1.87.
source "$(dirname "$0")/env.sh"

VER="${1:-1.92.0}"
PREFIX="$REPO_ROOT/boost/boost-$VER"

if [ ! -d "$SRC/boost-$VER" ]; then
    curl -sSfL -o "$SRC/boost-$VER.tar.xz" \
        "https://github.com/boostorg/boost/releases/download/boost-$VER/boost-$VER-b2-nodocs.tar.xz"
    tar -C "$SRC" -xf "$SRC/boost-$VER.tar.xz"
fi

cd "$SRC/boost-$VER"
[ -x b2 ] || ./bootstrap.sh

# Boost <= 1.86: Boost.Process declares its Windows system libs (shell32,
# advapi32, ntdll, user32) only when the *build host* is Windows
# (`if [ os.name ] = NT`), so cross builds fail with "Unable to find file or
# target named .../libs/process/build//advapi32". Fixed upstream in 1.87;
# declare them unconditionally (they are `explicit`, so harmless elsewhere).
sed -i 's/^if \[ os\.name \] = NT$/if true/' libs/process/build/Jamfile

echo "using gcc : mingw : $CXX_MINGW : <archiver>${TRIPLET}-ar <ranlib>${TRIPLET}-ranlib <rc>${TRIPLET}-windres ;" > user-config.jam

rm -rf "$PREFIX"
./b2 --user-config=user-config.jam \
    toolset=gcc-mingw target-os=windows address-model=64 architecture=x86 \
    variant=release link=shared,static runtime-link=shared threading=multi \
    --layout=tagged --prefix="$PREFIX" \
    --without-python --without-mpi --without-graph_parallel \
    -j"$JOBS" install
strip_prefix "$PREFIX"

# Debug variant: tagged layout adds the -d- tag (libboost_X-mt-d-x64) so the
# debug libraries coexist with release in the same lib dir. -Og -g1 keeps
# the static archives under GitHub's 100 MB per-file limit.
./b2 --user-config=user-config.jam \
    toolset=gcc-mingw target-os=windows address-model=64 architecture=x86 \
    variant=debug cxxflags="-Og -g1" link=shared,static runtime-link=shared threading=multi \
    --layout=tagged --prefix="$PREFIX" \
    --without-python --without-mpi --without-graph_parallel \
    -j"$JOBS" install
echo "boost $VER installed to $PREFIX"
