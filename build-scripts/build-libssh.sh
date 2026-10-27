#!/bin/bash
# libssh for 64-bit Windows, linked against the repo's OpenSSL and zlib.
source "$(dirname "$0")/env.sh"

VER=0.12.2
PREFIX="$REPO_ROOT/libssh/libssh-$VER"
OPENSSL="$REPO_ROOT/openssl/openssl-3.5.8"
ZLIB="$REPO_ROOT/zlib/zlib-1.3.2"

if [ ! -d "$SRC/libssh-$VER" ]; then
    curl -sSfL -o "$SRC/libssh-$VER.tar.gz" \
        "https://gitlab.com/libssh/libssh-mirror/-/archive/libssh-$VER/libssh-mirror-libssh-$VER.tar.gz"
    mkdir -p "$SRC/libssh-$VER"
    tar -C "$SRC/libssh-$VER" --strip-components=1 -xf "$SRC/libssh-$VER.tar.gz"
fi

export WINLIBS_FIND_ROOT="$OPENSSL;$ZLIB"
rm -rf "$PREFIX"
for WINLIBS_CONFIG in Release Debug; do
    export WINLIBS_CONFIG
    IPREFIX="$PREFIX"; [ "$WINLIBS_CONFIG" = Debug ] && IPREFIX="$PREFIX/debug"
    B="$BLD/libssh-$WINLIBS_CONFIG"
    rm -rf "$B"
    cmake_mingw -S "$SRC/libssh-$VER" -B "$B" \
        -DCMAKE_INSTALL_PREFIX="$IPREFIX" \
        -DCMAKE_PREFIX_PATH="$OPENSSL;$ZLIB" \
        -DOPENSSL_ROOT_DIR="$OPENSSL" \
        -DZLIB_ROOT="$ZLIB" \
        -DWITH_EXAMPLES=OFF -DUNIT_TESTING=OFF -DWITH_SERVER=ON
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
done
prune_debug_subtree "$PREFIX/debug"
strip_prefix "$PREFIX"
echo "libssh $VER installed to $PREFIX"
