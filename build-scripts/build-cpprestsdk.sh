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

# mingw-w64 fixes: cpprest's _WIN32 branches assume MSVC.
COMPAT="$SRC/cpprestsdk-$VER/Release/include/cpprest/details/cpprest_compat.h"
if ! grep -q __MINGW32__ "$COMPAT"; then
    # noexcept/constexpr are always available with GCC; _ASSERTE is MSVC crtdbg.
    sed -i 's|#if _MSC_VER >= 1900|#if defined(__MINGW32__) \|\| _MSC_VER >= 1900|' "$COMPAT"
    sed -i 's|#include <sal.h>|#include <sal.h>\n#ifdef __MINGW32__\n#include <assert.h>\n#ifndef _ASSERTE\n#define _ASSERTE(x) assert(x)\n#endif\n#ifndef _ReturnAddress\n#define _ReturnAddress() __builtin_return_address(0)\n#endif\n#ifndef __assume\n#define __assume(x) do { if (!(x)) __builtin_unreachable(); } while (false)\n#endif\n#endif|' "$COMPAT"
# The Windows code paths need C++14 (std::enable_if_t etc.).
sed -i 's|-std=c++11|-std=c++14|g' "$SRC/cpprestsdk-$VER/Release/CMakeLists.txt"
# mingw ships Windows headers with lowercase names (case matters when
# cross-compiling from a case-sensitive filesystem).
grep -rl -e '<Wincrypt.h>' -e '<Strsafe.h>' -e '<VersionHelpers.h>' \
    "$SRC/cpprestsdk-$VER/Release" | while read -r f; do
    sed -i 's|<Wincrypt.h>|<wincrypt.h>|; s|<Strsafe.h>|<strsafe.h>|; s|<VersionHelpers.h>|<versionhelpers.h>|' "$f"
done
fi
SAFEINT="$SRC/cpprestsdk-$VER/Release/include/cpprest/details/SafeInt3.hpp"
if ! grep -q __MINGW32__ "$SAFEINT"; then
    # mingw's winnt.h C_ASSERT expands to an extern declaration, which is
    # invalid at class scope; use static_assert instead.
    sed -i 's|#ifndef C_ASSERT|#ifdef __MINGW32__\n#undef C_ASSERT\n#define C_ASSERT(e) static_assert((e), "C_ASSERT")\n#endif\n#ifndef C_ASSERT|' "$SAFEINT"
fi

export WINLIBS_FIND_ROOT="$BOOST;$OPENSSL;$ZLIB"
B="$BLD/cpprestsdk"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/cpprestsdk-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_TESTS=OFF -DBUILD_SAMPLES=OFF -DWERROR=OFF \
    -DCPPREST_EXCLUDE_BROTLI=ON \
    -DBoost_ROOT="$BOOST" -DOPENSSL_ROOT_DIR="$OPENSSL" -DZLIB_ROOT="$ZLIB"
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "cpprestsdk $VER installed to $PREFIX"
