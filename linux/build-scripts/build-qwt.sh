#!/bin/bash
# Qwt 6.2.0 against the Linux Qt build: libqwt.so + libqwt-static.a,
# headers in include/qwt, CMake package `qwt` (qwt::qwt, qwt::qwt-static),
# same names as the Windows build. Uses the repo's CMakeLists for Qwt
# (build-scripts/qwt-CMakeLists.txt) with Linux file naming.
source "$(dirname "$0")/env.sh"

VER=6.2.0
PREFIX="$PREFIX_ROOT/qwt/$VER"
QT="$PREFIX_ROOT/qt/$QT_VER"

if [ ! -d "$SRC/qwt-$VER" ]; then
    git clone -q --depth 1 --branch "v$VER" https://github.com/opencor/qwt.git "$SRC/qwt-$VER"
fi
cp "$WIN_SCRIPTS/qwt-CMakeLists.txt" "$SRC/qwt-$VER/CMakeLists.txt"
# Windows naming (qwt.dll without the lib prefix) -> libqwt.so / libqwt-static.a
python3 - "$SRC/qwt-$VER/CMakeLists.txt" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
for old, new in [('PREFIX "" IMPORT_PREFIX "" DEBUG_POSTFIX d)', 'DEBUG_POSTFIX d)'),
                 ('PREFIX "" OUTPUT_NAME qwt-static DEBUG_POSTFIX d)', 'OUTPUT_NAME qwt-static DEBUG_POSTFIX d)')]:
    if s.count(old) != 1:
        sys.exit("build-qwt.sh (linux): naming block not found in qwt-CMakeLists.txt; patch needs updating")
    s = s.replace(old, new)
open(p, "w").write(s)
PY

B="$BLD/qwt"
rm -rf "$B" "$PREFIX"
cmake_native -S "$SRC/qwt-$VER" -B "$B" \
    -DCMAKE_PREFIX_PATH="$QT" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
rm -rf "$B"
strip_prefix "$PREFIX"

PKG="$PREFIX/lib/cmake/qwt"
mkdir -p "$PKG"
cp "$SCRIPT_DIR/cmake/qwtConfig.cmake" "$PKG/"
cat > "$BLD/qwt-version.cmake" <<'CM'
include(CMakePackageConfigHelpers)
set(CMAKE_SIZEOF_VOID_P 8)
write_basic_package_version_file("${OUT}" VERSION "${VER}" COMPATIBILITY SameMinorVersion)
CM
cmake -DVER="$VER" -DOUT="$PKG/qwtConfigVersion.cmake" -P "$BLD/qwt-version.cmake"
echo "qwt $VER installed to $PREFIX"
