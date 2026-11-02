#!/bin/bash
# OpenSSL 3.5 LTS (shared + static). Qt links against it; it ships with the
# application, so the app doesn't depend on the target's OpenSSL version
# (RHEL 8 has 1.1.1, newer distributions 3.x).
source "$(dirname "$0")/env.sh"

VER=$OPENSSL_VER
PREFIX="$PREFIX_ROOT/openssl/openssl-$VER"

if [ ! -d "$SRC/openssl-$VER" ]; then
    curl -sSfL -o "$SRC/openssl-$VER.tar.gz" \
        "https://github.com/openssl/openssl/releases/download/openssl-$VER/openssl-$VER.tar.gz"
    tar -C "$SRC" -xf "$SRC/openssl-$VER.tar.gz"
fi

cd "$SRC/openssl-$VER"
rm -rf "$PREFIX"
make distclean >/dev/null 2>&1 || true
# The default OPENSSLDIR (certificates/config) would be inside the prefix,
# which doesn't exist on the target machines; use the system location.
./Configure linux-x86_64 shared \
    --prefix="$PREFIX" --libdir=lib --openssldir=/etc/pki/tls \
    '-Wl,-rpath,$$ORIGIN' \
    no-tests no-docs
make -s -j"$JOBS"
make -s install_sw
strip_prefix "$PREFIX"
make distclean >/dev/null 2>&1 || true
echo "openssl $VER installed to $PREFIX"
