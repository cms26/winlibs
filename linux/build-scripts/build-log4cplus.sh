#!/bin/bash
# log4cplus 2.2.0.1, narrow (tchar = char; target log4cplus::log4cplus),
# matching the Windows log4cplus-<ver>-nonunicode install and its prefix
# name. (On Linux, UNICODE builds use wchar_t like on Windows; the app uses
# the narrow build, so only that one is built.)
source "$(dirname "$0")/env.sh"

VER=2.2.0.1
TAG=REL_2_2_0_1
PREFIX="$PREFIX_ROOT/log4cplus/log4cplus-$VER-nonunicode"

if [ ! -d "$SRC/log4cplus-$VER" ]; then
    curl -sSfL -o "$SRC/log4cplus-$VER.tar.xz" \
        "https://github.com/log4cplus/log4cplus/releases/download/$TAG/log4cplus-$VER.tar.xz"
    tar -C "$SRC" -xf "$SRC/log4cplus-$VER.tar.xz"
fi

B="$BLD/log4cplus"
rm -rf "$B" "$PREFIX"
cmake_native -S "$SRC/log4cplus-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DUNICODE=OFF \
    -DLOG4CPLUS_BUILD_TESTING=OFF -DLOG4CPLUS_BUILD_LOGGINGSERVER=OFF \
    -DWITH_UNIT_TESTS=OFF
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
rm -rf "$B"
strip_prefix "$PREFIX"
[ -f "$PREFIX/lib/cmake/log4cplus/log4cplusConfig.cmake" ] \
    || { echo "ERROR: log4cplus CMake package missing" >&2; exit 1; }
echo "log4cplus $VER (narrow) installed to $PREFIX"
