#!/bin/bash
# C++ REST SDK (casablanca) for 64-bit Windows, against repo boost + openssl.
source "$(dirname "$0")/env.sh"

VER=2.10.19
PREFIX="$REPO_ROOT/cpprestsdk/cpprestsdk-$VER"
BOOST="$REPO_ROOT/boost/boost-1.92.0"
OPENSSL="$REPO_ROOT/openssl/openssl-3.5.8"
ZLIB="$REPO_ROOT/zlib/zlib-1.3.2"

if [ ! -d "$SRC/cpprestsdk-$VER" ]; then
    git clone --recursive --depth 1 --branch "v$VER" \
        https://github.com/microsoft/cpprestsdk.git "$SRC/cpprestsdk-$VER"
fi

# SDKDDKVer.h is an MSVC Windows-SDK header that mingw-w64 does not ship;
# provide a stub (mingw's headers default _WIN32_WINNT themselves).
cat > "$SRC/cpprestsdk-$VER/Release/include/SDKDDKVer.h" <<'EOF'
#pragma once
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif
EOF

export WINLIBS_FIND_ROOT="$BOOST;$OPENSSL;$ZLIB"
B="$BLD/cpprestsdk"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/cpprestsdk-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_TESTS=OFF -DBUILD_SAMPLES=OFF -DWERROR=OFF \
    -DCPPREST_EXCLUDE_BROTLI=ON \
    -DCPPREST_PPLX_IMPL=linux \
    -DCPPREST_HTTP_CLIENT_IMPL=asio -DCPPREST_HTTP_LISTENER_IMPL=asio \
    -DCPPREST_FILEIO_IMPL=posix -DCPPREST_WEBSOCKETS_IMPL=asio \
    -DBoost_ROOT="$BOOST" -DOPENSSL_ROOT_DIR="$OPENSSL" -DZLIB_ROOT="$ZLIB"
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "cpprestsdk $VER installed to $PREFIX"
