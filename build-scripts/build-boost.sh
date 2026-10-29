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

# Fixes for cross-building Boost <= 1.86 (all fixed upstream by 1.87/1.92,
# so nothing here applies to newer versions):
#
# - Boost.Process declares its Windows system libs (shell32, advapi32,
#   ntdll, user32) only when the *build host* is Windows
#   (`if [ os.name ] = NT`): "Unable to find file or target named
#   .../libs/process/build//advapi32". Declare them unconditionally (they are
#   `explicit`, so harmless elsewhere), and add the Winsock libs its Asio
#   code needs (undefined __imp_WSAStartup otherwise).
# - Boost.Context deduces its assembler ABI/format from the build host
#   (sysv/elf on Linux) and fails to assemble for Windows: pin abi=ms/pe.
# - Boost.Stacktrace's from_exception library is POSIX-only for GCC
#   (needs dlfcn.h): don't build it. The other stacktrace libs are built.
TARGET_ABI=()
if [ "$(printf '%s\n' "$VER" 1.87.0 | sort -V | head -1)" != 1.87.0 ]; then
    PJ=libs/process/build/Jamfile
    sed -i 's/^if \[ os\.name \] = NT$/if true/' "$PJ"
    if ! grep -q 'lib ws2_32 ;' "$PJ"; then
        sed -i 's/^  lib advapi32 ;$/  lib advapi32 ;\n  lib ws2_32 ;\n  lib mswsock ;/' "$PJ"
        sed -i 's/^  explicit shell32 advapi32 ntdll user32 ;$/  explicit shell32 advapi32 ntdll user32 ws2_32 mswsock ;/' "$PJ"
        sed -i 's/^\( *\)<target-os>windows:<library>advapi32$/&\n\1<target-os>windows:<library>ws2_32\n\1<target-os>windows:<library>mswsock/' "$PJ"
    fi
    TARGET_ABI=(abi=ms binary-format=pe boost.stacktrace.from_exception=off)
fi

echo "using gcc : mingw : $CXX_MINGW : <archiver>${TRIPLET}-ar <ranlib>${TRIPLET}-ranlib <rc>${TRIPLET}-windres ;" > user-config.jam

rm -rf "$PREFIX"
./b2 --user-config=user-config.jam \
    toolset=gcc-mingw target-os=windows address-model=64 architecture=x86 "${TARGET_ABI[@]}" \
    variant=release link=shared,static runtime-link=shared threading=multi \
    --layout=tagged --prefix="$PREFIX" \
    --without-python --without-mpi --without-graph_parallel \
    -j"$JOBS" install
strip_prefix "$PREFIX"

# Debug variant: tagged layout adds the -d- tag (libboost_X-mt-d-x64) so the
# debug libraries coexist with release in the same lib dir. -Og -g1 keeps
# the static archives under GitHub's 100 MB per-file limit.
./b2 --user-config=user-config.jam \
    toolset=gcc-mingw target-os=windows address-model=64 architecture=x86 "${TARGET_ABI[@]}" \
    variant=debug cxxflags="-Og -g1" link=shared,static runtime-link=shared threading=multi \
    --layout=tagged --prefix="$PREFIX" \
    --without-python --without-mpi --without-graph_parallel \
    -j"$JOBS" install
echo "boost $VER installed to $PREFIX"
