#!/bin/bash
# Eigen (header-only) — installs headers + CMake/pkg-config files.
source "$(dirname "$0")/env.sh"

VER=3.4.1
PREFIX="$REPO_ROOT/eigen/eigen-$VER"

if [ ! -d "$SRC/eigen-$VER" ]; then
    curl -sSfL -o "$SRC/eigen-$VER.tar.gz" \
        "https://gitlab.com/libeigen/eigen/-/archive/$VER/eigen-$VER.tar.gz"
    tar -C "$SRC" -xf "$SRC/eigen-$VER.tar.gz"
fi

B="$BLD/eigen"
rm -rf "$B" "$PREFIX"
cmake -G Ninja -S "$SRC/eigen-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DEIGEN_BUILD_DOC=OFF -DEIGEN_BUILD_TESTING=OFF -DEIGEN_BUILD_DEMOS=OFF
cmake --install "$B"
echo "eigen $VER installed to $PREFIX"
