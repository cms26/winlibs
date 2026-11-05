#!/bin/bash
# Boost (b2, shared + static, tagged layout), everything except
# python/mpi/graph_parallel.
#
#   build-boost.sh [version]     (default 1.92.0, BOOST_VER_DEFAULT in env.sh)
#
# Shared libraries get an $ORIGIN RUNPATH so they find each other (e.g.
# boost_log -> boost_thread) when deployed next to the application. (b2's
# dll-path feature can't be used for that: it breaks the install targets,
# "No best alternative for libs/predef/install".)
#
# 1.92.0 is the default, the same version as on Windows. Each version
# installs to its own boost/boost-<version> prefix, so another one can be
# added next to it, e.g. "build-boost.sh 1.86.0" for the last release with
# the classic Boost.Asio API (io_service, ...), which 1.87 removed.
source "$(dirname "$0")/env.sh"

VER="${1:-$BOOST_VER_DEFAULT}"
PREFIX="$PREFIX_ROOT/boost/boost-$VER"

if [ ! -d "$SRC/boost-$VER" ]; then
    curl -sSfL -o "$SRC/boost-$VER.tar.xz" \
        "https://github.com/boostorg/boost/releases/download/boost-$VER/boost-$VER-b2-nodocs.tar.xz"
    tar -C "$SRC" -xf "$SRC/boost-$VER.tar.xz"
fi

cd "$SRC/boost-$VER"
[ -x b2 ] || ./bootstrap.sh --with-toolset=gcc
echo "using gcc : : $CXX ;" > user-config.jam

rm -rf "$PREFIX"
./b2 --user-config=user-config.jam --build-dir="$BLD/boost-$VER" \
    toolset=gcc address-model=64 architecture=x86 \
    variant=release link=shared,static runtime-link=shared threading=multi \
    cxxflags=-fPIC cflags=-fPIC "linkflags=-Wl,-rpath,'\$ORIGIN'" boost.locale.icu=off \
    --layout=tagged --prefix="$PREFIX" \
    --without-python --without-mpi --without-graph_parallel \
    -j"$JOBS" -d0 install
rm -rf "$BLD/boost-$VER"
strip_prefix "$PREFIX"
[ "$(readelf -d "$PREFIX/lib/libboost_log-mt-x64.so.$VER" | grep -c 'RUNPATH.*\[\$ORIGIN\]' || true)" -eq 1 ] \
    || { echo "ERROR: Boost shared libraries have no \$ORIGIN RUNPATH" >&2; exit 1; }
[ -f "$PREFIX/lib/cmake/Boost-$VER/BoostConfig.cmake" ] \
    || { echo "ERROR: Boost CMake package missing" >&2; exit 1; }
echo "boost $VER installed to $PREFIX"
