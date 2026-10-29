#!/bin/bash
# Qwt for 64-bit Windows, built against the repo's Qt 6.11.2 cross build.
# Upstream qwt is qmake-only; we use the CMakeLists shipped in build-scripts.
# Source: opencor/qwt GitHub mirror (SourceForge upstream mirror).
source "$(dirname "$0")/env.sh"

VER=6.2.0
PREFIX="$REPO_ROOT/qwt/$VER"
QT="$REPO_ROOT/qt/6.11.2"

if [ ! -d "$SRC/qwt-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/opencor/qwt.git "$SRC/qwt-$VER"
fi
cp "$SCRIPT_DIR/qwt-CMakeLists.txt" "$SRC/qwt-$VER/CMakeLists.txt"

rm -rf "$PREFIX"
for CFG in Release Debug; do
    B="$BLD/qwt-$CFG"
    rm -rf "$B"
    cmake -G Ninja -S "$SRC/qwt-$VER" -B "$B" \
        -DCMAKE_TOOLCHAIN_FILE="$QT/lib/cmake/Qt6/qt.toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=$CFG \
        -DCMAKE_DEBUG_POSTFIX=d \
        -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
    [ "$CFG" = Release ] && strip_prefix "$PREFIX"
done
# GitHub rejects files over 100 MB; the full-DWARF static debug archive
# exceeds it (qwtd.dll keeps complete debug symbols).
if [ "$(stat -c%s "$PREFIX/lib/qwt-staticd.a")" -gt 95000000 ]; then
    "$STRIP" --strip-debug "$PREFIX/lib/qwt-staticd.a"
fi

# CMake package config (find_package(qwt CONFIG); targets qwt::qwt and
# qwt::qwt-static), kept in build-scripts/qwt-cmake/.
CMAKE_PKG="$PREFIX/lib/cmake/qwt"
mkdir -p "$CMAKE_PKG"
cp "$SCRIPT_DIR/qwt-cmake/qwtConfig.cmake" "$CMAKE_PKG/"
cat > "$BLD/qwt-version.cmake" <<'EOF'
include(CMakePackageConfigHelpers)
set(CMAKE_SIZEOF_VOID_P 8)   # 64-bit only, like the binaries
write_basic_package_version_file("${OUT}" VERSION "${VER}" COMPATIBILITY SameMinorVersion)
EOF
cmake -DVER="$VER" -DOUT="$CMAKE_PKG/qwtConfigVersion.cmake" -P "$BLD/qwt-version.cmake"
echo "qwt $VER installed to $PREFIX"
