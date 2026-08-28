#!/bin/bash
# Qwt for 64-bit Windows, built against the repo's Qt 6.11.2 cross build.
# Upstream qwt is qmake-only; we use the CMakeLists shipped in build-scripts.
# Source: opencor/qwt GitHub mirror (SourceForge upstream mirror).
source "$(dirname "$0")/env.sh"

VER=6.2.0
PREFIX="$REPO_ROOT/qwt/qwt-$VER"
QT="$REPO_ROOT/qt/6.11.2"

if [ ! -d "$SRC/qwt-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/opencor/qwt.git "$SRC/qwt-$VER"
fi
cp "$SCRIPT_DIR/qwt-CMakeLists.txt" "$SRC/qwt-$VER/CMakeLists.txt"

B="$BLD/qwt"
rm -rf "$B" "$PREFIX"
cmake -G Ninja -S "$SRC/qwt-$VER" -B "$B" \
    -DCMAKE_TOOLCHAIN_FILE="$QT/lib/cmake/Qt6/qt.toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "qwt $VER installed to $PREFIX"
