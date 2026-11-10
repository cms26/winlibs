#!/bin/bash
# Qwt 6.3.0 against the Linux Qt build: libqwt.so + libqwt-static.a,
# headers in include/qwt, CMake package `qwt` (qwt::qwt, qwt::qwt-static),
# same names as the Windows build. Uses the repo's CMakeLists for Qwt
# (build-scripts/qwt-CMakeLists.txt) with Linux file naming.
source "$(dirname "$0")/env.sh"

VER=6.3.0
PREFIX="$PREFIX_ROOT/qwt/$VER"
QT="$PREFIX_ROOT/qt/$QT_VER"

# The official release tarball (Qwt is published on SourceForge only, which
# build machines often can't reach): Ubuntu's archive carries it unmodified
# (qwt_<ver>.orig.tar.bz2); the checksum is the SourceForge file's
# (qwt-6.3.0.tar.bz2, as Homebrew pins it).
QWT_URL="https://archive.ubuntu.com/ubuntu/pool/universe/q/qwt/qwt_${VER}.orig.tar.bz2"
QWT_SHA256=dcb085896c28aaec5518cbc08c0ee2b4e60ada7ac929d82639f6189851a6129a
if [ ! -d "$SRC/qwt-$VER" ]; then
    curl -fsSL -o "$SRC/qwt-$VER.tar.bz2" "$QWT_URL"
    echo "$QWT_SHA256  $SRC/qwt-$VER.tar.bz2" | sha256sum -c --quiet \
        || { echo "qwt-$VER.tar.bz2: checksum mismatch" >&2; exit 1; }
    tar -xjf "$SRC/qwt-$VER.tar.bz2" -C "$SRC"
    rm "$SRC/qwt-$VER.tar.bz2"
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
