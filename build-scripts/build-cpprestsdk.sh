#!/bin/bash
# C++ REST SDK (casablanca) for 64-bit Windows, against repo boost + openssl.
source "$(dirname "$0")/env.sh"

VER=2.10.19
PREFIX="$REPO_ROOT/cpprestsdk/cpprestsdk-$VER"
OPENSSL="$REPO_ROOT/openssl/openssl-3.5.8"
ZLIB="$REPO_ROOT/zlib/zlib-1.3.2"

# cpprestsdk 2.10.x (archived upstream) requires the classic Boost.Asio API
# (io_service etc.) that Boost removed in 1.87, so it gets a private static
# Boost 1.86 that is linked into the cpprest DLL and not shipped separately.
BOOST_VER=1.86.0
BOOST="$WORK/boost-cpprest"
if [ ! -f "$BOOST/lib/libboost_system-mt-x64.a" ]; then
    if [ ! -d "$SRC/boost-$BOOST_VER" ]; then
        curl -sSfL -o "$SRC/boost-$BOOST_VER.tar.xz" \
            "https://github.com/boostorg/boost/releases/download/boost-$BOOST_VER/boost-$BOOST_VER-b2-nodocs.tar.xz"
        tar -C "$SRC" -xf "$SRC/boost-$BOOST_VER.tar.xz"
    fi
    cd "$SRC/boost-$BOOST_VER"
    [ -x b2 ] || ./bootstrap.sh
    echo "using gcc : mingw : $CXX_MINGW : <archiver>${TRIPLET}-ar <ranlib>${TRIPLET}-ranlib <rc>${TRIPLET}-windres ;" > user-config.jam
    ./b2 --user-config=user-config.jam \
        toolset=gcc-mingw target-os=windows address-model=64 architecture=x86 \
        variant=release link=static runtime-link=shared threading=multi \
        --layout=tagged --prefix="$BOOST" \
        --with-system --with-thread --with-chrono --with-atomic \
        --with-date_time --with-regex --with-random --with-filesystem \
        -j"$JOBS" install
fi

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
    sed -i 's|#include <sal.h>|#include <sal.h>\n#ifdef __MINGW32__\n#include <assert.h>\n#include <intrin.h>\n#ifndef _ASSERTE\n#define _ASSERTE(x) assert(x)\n#endif\n#ifndef _ReturnAddress\n#define _ReturnAddress() __builtin_return_address(0)\n#endif\n#ifndef __assume\n#define __assume(x) do { if (!(x)) __builtin_unreachable(); } while (false)\n#endif\n#endif|' "$COMPAT"
fi
# The Windows code paths need C++14 (std::enable_if_t etc.).
sed -i 's|-std=c++11|-std=c++14|g' "$SRC/cpprestsdk-$VER/Release/CMakeLists.txt"
# cpprest's U() macro breaks Boost headers that use U as a template parameter
# with a function-style initializer (boost/move). Build the library itself
# with _TURN_OFF_PLATFORM_STRING and use _XPLATSTR internally instead.
 { grep -rl 'U("' "$SRC/cpprestsdk-$VER/Release/src" || true; } | while read -r f; do
    sed -i 's/\bU(")/_XPLATSTR(")/g; s/\bU("/_XPLATSTR("/g' "$f"
done
{ grep -rl "U('" "$SRC/cpprestsdk-$VER/Release/src" || true; } | while read -r f; do
    sed -i "s/\bU('/_XPLATSTR('/g" "$f"
done
# Unqualified pplx type in the MSVC-oriented Concurrency shim.
sed -i 's|std::shared_ptr<scheduler_interface>|std::shared_ptr<pplx::scheduler_interface>|g' \
    "$SRC/cpprestsdk-$VER/Release/src/pplx/pplxwin.cpp"
# mingw winerror.h lacks the WININET_E_* HRESULT aliases.
WINHTTP_CPP="$SRC/cpprestsdk-$VER/Release/src/http/client/http_client_winhttp.cpp"
if ! grep -q 'define WININET_E_INCORRECT_HANDLE_STATE' "$WINHTTP_CPP"; then
    sed -i '0,/#include "stdafx.h"/s//#include "stdafx.h"\n#ifndef WININET_E_INCORRECT_HANDLE_STATE\n#define WININET_E_INCORRECT_HANDLE_STATE ((HRESULT)0x80072EF3L)\n#endif/' "$WINHTTP_CPP"
fi
# asio's terminate_threads exists only in its win_thread backend; the
# mingw-posix build uses asio's posix_thread, which has no such API.
TP_CPP="$SRC/cpprestsdk-$VER/Release/src/pplx/threadpool.cpp"
if ! grep -q __MINGW32__ "$TP_CPP"; then
    python3 - "$TP_CPP" <<'PYEOF'
import sys
path = sys.argv[1]
s = open(path).read()
old = """        bool terminate_threads = boost::asio::detail::thread::terminate_threads();
        boost::asio::detail::thread::set_terminate_threads(true);
        get_shared().~threadpool_impl();
        boost::asio::detail::thread::set_terminate_threads(terminate_threads);"""
new = """#ifndef __MINGW32__
        bool terminate_threads = boost::asio::detail::thread::terminate_threads();
        boost::asio::detail::thread::set_terminate_threads(true);
#endif
        get_shared().~threadpool_impl();
#ifndef __MINGW32__
        boost::asio::detail::thread::set_terminate_threads(terminate_threads);
#endif"""
assert old in s, "threadpool.cpp pattern not found"
open(path, "w").write(s.replace(old, new, 1))
PYEOF
fi

# The MSVC-CRT-specific fileio_win32.cpp does not build with GCC; use the
# posix implementation with pread/pwrite shims for mingw.
FIO="$SRC/cpprestsdk-$VER/Release/src/streams/fileio_posix.cpp"
if ! grep -q __MINGW32__ "$FIO"; then
    python3 - "$FIO" <<'PYEOF'
import sys
p = sys.argv[1]; s = open(p).read()
shim = """#ifdef __MINGW32__
#include <boost/asio.hpp>
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
static ssize_t cpprest_pread(int fd, void* buf, size_t n, long long off)
{
    OVERLAPPED o; memset(&o, 0, sizeof(o));
    o.Offset = (DWORD)off; o.OffsetHigh = (DWORD)((unsigned long long)off >> 32);
    DWORD got = 0;
    HANDLE h = (HANDLE)_get_osfhandle(fd);
    if (!ReadFile(h, buf, (DWORD)n, &got, &o))
        return GetLastError() == ERROR_HANDLE_EOF ? 0 : -1;
    return (ssize_t)got;
}
static ssize_t cpprest_pwrite(int fd, const void* buf, size_t n, long long off)
{
    OVERLAPPED o; memset(&o, 0, sizeof(o));
    o.Offset = (DWORD)off; o.OffsetHigh = (DWORD)((unsigned long long)off >> 32);
    DWORD put = 0;
    HANDLE h = (HANDLE)_get_osfhandle(fd);
    if (!WriteFile(h, buf, (DWORD)n, &put, &o)) return -1;
    return (ssize_t)put;
}
#define pread cpprest_pread
#define pwrite cpprest_pwrite
#endif
"""
marker = '#include "stdafx.h"'
assert marker in s
s = s.replace(marker, marker + "\n" + shim, 1)
open(p, "w").write(s)
PYEOF
fi

# mingw ships Windows headers with lowercase names (case matters when
# cross-compiling from a case-sensitive filesystem).
{ grep -rl -e '<Wincrypt.h>' -e '<Strsafe.h>' -e '<VersionHelpers.h>' \
    "$SRC/cpprestsdk-$VER/Release" || true; } | while read -r f; do
    sed -i 's|<Wincrypt.h>|<wincrypt.h>|; s|<Strsafe.h>|<strsafe.h>|; s|<VersionHelpers.h>|<versionhelpers.h>|' "$f"
done
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
    -DCMAKE_CXX_FLAGS="-D_TURN_OFF_PLATFORM_STRING" \
    -DCPPREST_EXCLUDE_BROTLI=ON \
    -DCPPREST_FILEIO_IMPL=posix \
    -DBoost_ROOT="$BOOST" -DBoost_USE_STATIC_LIBS=ON \
    -DOPENSSL_ROOT_DIR="$OPENSSL" -DZLIB_ROOT="$ZLIB"
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "cpprestsdk $VER installed to $PREFIX"
