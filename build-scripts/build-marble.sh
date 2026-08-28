#!/bin/bash
# Marble (KDE map widget) for 64-bit Windows against the repo's Qt 6.11.2.
# Library-only build (no apps/tools/tests/designer plugin), no KDE Frameworks.
source "$(dirname "$0")/env.sh"

VER=26.08.0
ECM_VER=6.17.0
PREFIX="$REPO_ROOT/marble/marble-$VER"
QT="$REPO_ROOT/qt/6.11.2"
ZLIB="$REPO_ROOT/zlib/zlib-1.3.2"

if [ ! -d "$SRC/marble-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/KDE/marble.git "$SRC/marble-$VER"
fi
if [ ! -d "$SRC/ecm-$ECM_VER" ]; then
    git clone --depth 1 --branch "v$ECM_VER" \
        https://github.com/KDE/extra-cmake-modules.git "$SRC/ecm-$ECM_VER"
fi

# ECM is a host-side, arch-independent CMake module set.
ECM_PREFIX="$WORK/ecm"
if [ ! -d "$ECM_PREFIX" ]; then
    cmake -S "$SRC/ecm-$ECM_VER" -B "$BLD/ecm" -DCMAKE_INSTALL_PREFIX="$ECM_PREFIX" -DBUILD_TESTING=OFF
    cmake --install "$BLD/ecm"
fi

export WINLIBS_FIND_ROOT="$ZLIB"
B="$BLD/marble"
rm -rf "$B" "$PREFIX"
cmake -G Ninja -S "$SRC/marble-$VER" -B "$B" \
    -DCMAKE_TOOLCHAIN_FILE="$QT/lib/cmake/Qt6/qt.toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DECM_DIR="$ECM_PREFIX/share/ECM/cmake" \
    -DZLIB_ROOT="$ZLIB" \
    -DBUILD_MARBLE_TESTS=OFF -DBUILD_MARBLE_TOOLS=OFF \
    -DBUILD_MARBLE_EXAMPLES=OFF -DBUILD_MARBLE_APPS=OFF \
    -DWITH_DESIGNER_PLUGIN=OFF -DBUILD_WITH_DBUS=OFF
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "marble $VER installed to $PREFIX"
