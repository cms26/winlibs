#!/bin/bash
# Wt (web toolkit) for 64-bit Windows, against repo boost + openssl + zlib.
# HTTP connector + bundled sqlite3 Dbo backend; no FCGI (unix-only).
source "$(dirname "$0")/env.sh"

VER=4.14.2
PREFIX="$REPO_ROOT/wt/wt-$VER"
BOOST="$REPO_ROOT/boost/boost-1.92.0"
OPENSSL="$REPO_ROOT/openssl/openssl-3.5.8"
ZLIB="$REPO_ROOT/zlib/zlib-1.3.2"

if [ ! -d "$SRC/wt-$VER" ]; then
    git clone --depth 1 --branch "$VER" https://github.com/emweb/wt.git "$SRC/wt-$VER"
fi

export WINLIBS_FIND_ROOT="$BOOST;$OPENSSL;$ZLIB"
rm -rf "$PREFIX"
for WINLIBS_CONFIG in Release Debug; do
    export WINLIBS_CONFIG
    IPREFIX="$PREFIX"; [ "$WINLIBS_CONFIG" = Debug ] && IPREFIX="$PREFIX/debug"
    B="$BLD/wt-$WINLIBS_CONFIG"
    rm -rf "$B"
    # -Og -g1 in debug: full -g static archives would exceed GitHub's
    # 100 MB per-file limit.
    cmake_mingw -S "$SRC/wt-$VER" -B "$B" \
        -DCMAKE_INSTALL_PREFIX="$IPREFIX" \
        -DCMAKE_C_FLAGS_DEBUG="-Og -g1" -DCMAKE_CXX_FLAGS_DEBUG="-Og -g1" \
        -DBOOST_PREFIX="$BOOST" -DOPENSSL_PREFIX="$OPENSSL" -DZLIB_ROOT="$ZLIB" \
        -DCONNECTOR_FCGI=OFF -DCONNECTOR_HTTP=ON \
        -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF \
        -DENABLE_QT4=OFF -DENABLE_QT5=OFF -DENABLE_QT6=OFF \
        -DENABLE_POSTGRES=OFF -DENABLE_MYSQL=OFF -DENABLE_MSSQLSERVER=OFF \
        -DENABLE_FIREBIRD=OFF -DENABLE_PANGO=OFF \
        -DENABLE_SQLITE=ON -DENABLE_SSL=ON -DENABLE_LIBWTTEST=OFF
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"

    # Wt's Windows default CONFIGDIR is the absolute path c:/witty; installing
    # from Linux renders that as a literal "c:" directory under the prefix,
    # which is an invalid filename on Windows and breaks git checkout there.
    # Keep the sample config under etc/wt instead (at run time Wt still looks
    # in c:/witty by default, or wherever --config points).
    if [ -d "$IPREFIX/c:" ]; then
        mkdir -p "$IPREFIX/etc/wt"
        mv "$IPREFIX/c:/witty/"* "$IPREFIX/etc/wt/"
        rm -rf "$IPREFIX/c:"
    fi
done
prune_debug_subtree "$PREFIX/debug"
strip_prefix "$PREFIX"
echo "wt $VER installed to $PREFIX"
