#!/bin/bash
# Qwt for 64-bit Windows, built against the build-only Qt 6.11.2 from
# build-qt.sh ($WINLIBS_QT); runs with any installed Qt 6.11 or newer.
# Upstream qwt is qmake-only; we use the CMakeLists shipped in build-scripts.
# Source: the official 6.3.0 release (see below). 6.3.0 fixes, among others,
# filled curves with a curve fitter drawing nothing, and blurry legend icons,
# spectrograms and rubber bands on high-DPI screens.
source "$(dirname "$0")/env.sh"

VER=6.3.0
PREFIX="$REPO_ROOT/qwt/$VER"
QT="$WINLIBS_QT"

# The official release tarball (Qwt is published on SourceForge only, which
# build machines often can't reach): Ubuntu's archive carries it unmodified
# (qwt_<ver>.orig.tar.bz2); the checksum is the SourceForge file's
# (qwt-6.3.0.tar.bz2, as Homebrew pins it).
QWT_URL="http://archive.ubuntu.com/ubuntu/pool/universe/q/qwt/qwt_${VER}.orig.tar.bz2"
QWT_SHA256=dcb085896c28aaec5518cbc08c0ee2b4e60ada7ac929d82639f6189851a6129a
if [ ! -d "$SRC/qwt-$VER" ]; then
    curl -fsSL -o "$SRC/qwt-$VER.tar.bz2" "$QWT_URL"
    echo "$QWT_SHA256  $SRC/qwt-$VER.tar.bz2" | sha256sum -c --quiet \
        || { echo "qwt-$VER.tar.bz2: checksum mismatch" >&2; exit 1; }
    tar -xjf "$SRC/qwt-$VER.tar.bz2" -C "$SRC"
    rm "$SRC/qwt-$VER.tar.bz2"
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
