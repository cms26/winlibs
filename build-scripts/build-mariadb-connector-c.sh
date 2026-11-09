#!/bin/bash
# MariaDB Connector/C for 64-bit Windows (mingw-w64 cross build): the MySQL
# client library for Qt's MySQL driver (QMYSQL). Qt doesn't ship that driver;
# windows/build-qt-mysql-driver.ps1 builds it against the installed Qt with
# this library.
#
#   build-mariadb-connector-c.sh [version]     (default 3.4.11)
#
# Talks to MySQL 8.x/9.x and MariaDB servers, including MySQL's default
# caching_sha2_password login. LGPL 2.1 (MySQL's own libmysqlclient is GPL v2
# or an Oracle commercial license), so it can ship with a closed-source app.
#
# TLS uses Schannel, Windows' own TLS (the connector's default on Windows,
# and what the Qt installer's Qt uses): no OpenSSL DLLs, and server
# certificates are checked against the Windows certificate store. zlib
# (compressed protocol) is built in. Authentication plugins are built into
# the DLL, so no plugin folder is needed at run time.
#
# Output: bin/libmariadb.dll, lib/liblibmariadb.dll.a, include/mariadb/.
# Release only (Qt's MinGW builds are release-only too).
source "$(dirname "$0")/env.sh"

VER="${1:-3.4.11}"
PREFIX="$REPO_ROOT/mariadb-connector-c/mariadb-connector-c-$VER"

if [ ! -d "$SRC/mariadb-connector-c-$VER" ]; then
    git -c advice.detachedHead=false clone -q --depth 1 --branch "v$VER" \
        https://github.com/mariadb-corporation/mariadb-connector-c.git "$SRC/mariadb-connector-c-$VER"
fi

B="$BLD/mariadb-connector-c-$VER"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/mariadb-connector-c-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_SHARED_LINKER_FLAGS="-static" \
    -DINSTALL_BINDIR=bin -DINSTALL_LIBDIR=lib -DINSTALL_INCLUDEDIR=include/mariadb \
    -DINSTALL_PLUGINDIR=lib/plugin \
    -DWITH_SSL=SCHANNEL \
    -DWITH_EXTERNAL_ZLIB=OFF \
    -DWITH_UNIT_TESTS=OFF -DWITH_CURL=OFF -DWITH_MSI=OFF \
    -DCLIENT_PLUGIN_CACHING_SHA2_PASSWORD=STATIC \
    -DCLIENT_PLUGIN_SHA256_PASSWORD=STATIC \
    -DCLIENT_PLUGIN_CLIENT_ED25519=STATIC \
    -DCLIENT_PLUGIN_PARSEC=STATIC \
    -DCLIENT_PLUGIN_DIALOG=STATIC \
    -DCLIENT_PLUGIN_MYSQL_CLEAR_PASSWORD=STATIC \
    -DCLIENT_PLUGIN_AUTH_GSSAPI_CLIENT=OFF \
    -DCLIENT_PLUGIN_REMOTE_IO=OFF \
    -DCLIENT_PLUGIN_PVIO_SHMEM=STATIC
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
rm -rf "$B"
rm -rf "$PREFIX/man" "$PREFIX"/lib/libmariadbclient.a "$PREFIX"/lib/mariadbclient.lib
rmdir "$PREFIX/lib/plugin" 2>/dev/null || true
# The connector installs its DLL into lib/; Windows convention is bin/.
mkdir -p "$PREFIX/bin"
for dll in "$PREFIX"/lib/*.dll; do
    [ -e "$dll" ] && mv "$dll" "$PREFIX/bin/"
done
strip_prefix "$PREFIX"

# Checks: the DLL and import library exist, the DLL needs only Windows
# system DLLs (the mingw runtime, libgcc and winpthread, is linked in
# statically: no dependency on the mingw version Qt ships), and the MySQL 8+
# login is built in.
DLL="$PREFIX/bin/libmariadb.dll"
[ -f "$DLL" ] || { echo "ERROR: $DLL not built" >&2; ls -R "$PREFIX" >&2; exit 1; }
ls "$PREFIX"/lib/*mariadb*.dll.a >/dev/null || { echo "ERROR: import library missing" >&2; exit 1; }
IMPORTS=$(${TRIPLET}-objdump -p "$DLL" | sed -n 's/^\s*DLL Name: //p')
echo "libmariadb.dll imports:" $IMPORTS
if echo "$IMPORTS" | grep -iE "^(libgcc|libstdc|libwinpthread)"; then
    echo "ERROR: $DLL depends on a mingw runtime DLL" >&2; exit 1
fi
[ "$(strings "$DLL" | grep -c '^caching_sha2_password$' || true)" -ge 1 ] \
    || { echo "ERROR: caching_sha2_password plugin not built in" >&2; exit 1; }
[ -f "$PREFIX/include/mariadb/mysql.h" ] || { echo "ERROR: mysql.h missing" >&2; exit 1; }
echo "MariaDB Connector/C $VER (Windows x64, Schannel) installed to $PREFIX"
