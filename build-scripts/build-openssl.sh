#!/bin/bash
# OpenSSL 3.5 LTS for 64-bit Windows (mingw-w64 cross build).
source "$(dirname "$0")/env.sh"

VER=3.5.8
PREFIX="$REPO_ROOT/openssl/openssl-$VER"

if [ ! -d "$SRC/openssl-$VER" ]; then
    curl -sSfL -o "$SRC/openssl-$VER.tar.gz" \
        "https://github.com/openssl/openssl/releases/download/openssl-$VER/openssl-$VER.tar.gz"
    tar -C "$SRC" -xf "$SRC/openssl-$VER.tar.gz"
fi

cd "$SRC/openssl-$VER"
./Configure mingw64 shared \
    --cross-compile-prefix=${TRIPLET}- \
    --prefix="$PREFIX" \
    --libdir=lib \
    no-tests no-docs
make -s -j"$JOBS"
rm -rf "$PREFIX"
make -s install_sw
strip_prefix "$PREFIX"
echo "openssl $VER installed to $PREFIX"
