#!/bin/bash
# MariaDB Connector/C: the MySQL client library for Qt's MySQL driver
# (QMYSQL, build-qt-mysql.sh). Talks to MySQL 8.x/9.x and MariaDB servers,
# including MySQL's default caching_sha2_password login, over TLS with the
# winlibs OpenSSL.
#
#   build-mariadb-connector-c.sh [version]     (default 3.4.11)
#
# LGPL 2.1, unlike MySQL's own libmysqlclient (GPL v2 or an Oracle commercial
# license), so it can be shipped as a shared library with a closed-source
# application, like Qt itself. Qt supports both for QMYSQL; code using
# QSqlDatabase::addDatabase("QMYSQL") is the same either way.
#
# The authentication plugins are built into the library (no plugin folder
# needed at run time). $ORIGIN RUNPATH, so it finds the OpenSSL next to it
# (both are copied into Qt's lib/).
source "$(dirname "$0")/env.sh"

VER="${1:-3.4.11}"
PREFIX="$PREFIX_ROOT/mariadb-connector-c/mariadb-connector-c-$VER"
OPENSSL="$PREFIX_ROOT/openssl/openssl-$OPENSSL_VER"

if [ ! -d "$SRC/mariadb-connector-c-$VER" ]; then
    git -c advice.detachedHead=false clone -q --depth 1 --branch "v$VER" \
        https://github.com/mariadb-corporation/mariadb-connector-c.git "$SRC/mariadb-connector-c-$VER"
fi

B="$BLD/mariadb-connector-c-$VER"
rm -rf "$B" "$PREFIX"
cmake_native -S "$SRC/mariadb-connector-c-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DINSTALL_LIBDIR=lib -DINSTALL_INCLUDEDIR=include/mariadb -DINSTALL_PLUGINDIR=lib/plugin \
    -DWITH_SSL=OPENSSL -DOPENSSL_ROOT_DIR="$OPENSSL" -DOPENSSL_USE_STATIC_LIBS=OFF \
    -DWITH_EXTERNAL_ZLIB=ON \
    -DWITH_UNIT_TESTS=OFF -DWITH_CURL=OFF \
    -DCLIENT_PLUGIN_CACHING_SHA2_PASSWORD=STATIC \
    -DCLIENT_PLUGIN_SHA256_PASSWORD=STATIC \
    -DCLIENT_PLUGIN_CLIENT_ED25519=STATIC \
    -DCLIENT_PLUGIN_PARSEC=STATIC \
    -DCLIENT_PLUGIN_DIALOG=STATIC \
    -DCLIENT_PLUGIN_MYSQL_CLEAR_PASSWORD=STATIC \
    -DCLIENT_PLUGIN_AUTH_GSSAPI_CLIENT=OFF \
    -DCLIENT_PLUGIN_REMOTE_IO=OFF
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
rm -rf "$B"
# Static library and the (now empty) plugin folder aren't used.
rm -rf "$PREFIX"/lib/libmariadbclient.a "$PREFIX/man"
rmdir "$PREFIX/lib/plugin" 2>/dev/null || true
strip_prefix "$PREFIX"

# Checks: the shared library, its RUNPATH, OpenSSL linked, the MySQL-8+
# login plugin built in.
SO=$(ls "$PREFIX"/lib/libmariadb.so.[0-9]* | head -1)
[ -f "$SO" ] || { echo "ERROR: libmariadb.so not built" >&2; exit 1; }
[ "$(readelf -d "$SO" | grep -c 'RUNPATH.*\[\$ORIGIN\]' || true)" -eq 1 ] \
    || { echo "ERROR: $SO has no \$ORIGIN RUNPATH" >&2; readelf -d "$SO" | grep -i path; exit 1; }
[ "$(readelf -d "$SO" | grep -c 'NEEDED.*libssl' || true)" -eq 1 ] \
    || { echo "ERROR: $SO is not linked with OpenSSL" >&2; exit 1; }
[ "$(strings "$SO" | grep -c '^caching_sha2_password$' || true)" -ge 1 ] \
    || { echo "ERROR: caching_sha2_password plugin not built in" >&2; exit 1; }
[ -f "$PREFIX/include/mariadb/mysql.h" ] || { echo "ERROR: mysql.h missing" >&2; exit 1; }
echo "MariaDB Connector/C $VER installed to $PREFIX"
