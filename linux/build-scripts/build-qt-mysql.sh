#!/bin/bash
# Qt's MySQL SQL driver (QMYSQL: plugins/sqldrivers/libqsqlmysql.so) for the
# Qt in qt/<QT_VER>, using MariaDB Connector/C (build-mariadb-connector-c.sh)
# as the MySQL client library. libmariadb is copied into Qt's lib/, so Qt's
# deployment ships it with the application like OpenSSL.
#
# Built on its own from qtbase/src/plugins/sqldrivers against the installed
# Qt (the way Qt documents adding a SQL driver), so the cached Qt build
# isn't touched.
source "$(dirname "$0")/env.sh"

VER=$QT_VER
PREFIX="$PREFIX_ROOT/qt/$VER"
CONNECTOR=$(ls -d "$PREFIX_ROOT"/mariadb-connector-c/mariadb-connector-c-* 2>/dev/null | sort -V | tail -1)
[ -n "$CONNECTOR" ] || { echo "ERROR: no MariaDB Connector/C (run build-mariadb-connector-c.sh)" >&2; exit 1; }
[ -x "$PREFIX/bin/qt-cmake" ] || { echo "ERROR: Qt $VER not installed in $PREFIX" >&2; exit 1; }

# Only the sqldrivers folder of qtbase is needed.
Q="$SRC/qtbase-sqldrivers-$VER"
if [ ! -d "$Q" ]; then
    git -c advice.detachedHead=false clone -q --depth 1 --filter=blob:none --sparse \
        --branch "v$VER" https://github.com/qt/qtbase.git "$Q"
    git -C "$Q" sparse-checkout set src/plugins/sqldrivers
fi

B="$BLD/qt-sqldrivers-mysql"
rm -rf "$B"
"$PREFIX/bin/qt-cmake" -G Ninja -S "$Q/src/plugins/sqldrivers" -B "$B" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DFEATURE_sql_mysql=ON \
    -DFEATURE_sql_sqlite=OFF -DFEATURE_sql_psql=OFF -DFEATURE_sql_odbc=OFF \
    -DFEATURE_sql_ibase=OFF -DFEATURE_sql_oci=OFF -DFEATURE_sql_db2=OFF -DFEATURE_sql_mimer=OFF \
    -DMySQL_INCLUDE_DIR="$CONNECTOR/include/mariadb" \
    -DMySQL_LIBRARY="$CONNECTOR/lib/libmariadb.so"
grep -iE "^\s*(MySql|SQLite|PostgreSql|ODBC)\b[^.]*\.{3,}" "$B/config.summary" || true
grep -Eiq "^\s*MySql \.+ yes" "$B/config.summary" \
    || { echo "ERROR: MySQL driver not enabled" >&2; exit 1; }
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
rm -rf "$B"

cp -a "$CONNECTOR"/lib/libmariadb.so* "$PREFIX/lib/"
strip_prefix "$PREFIX"

# Checks: the plugin exists and finds libmariadb (next to Qt's libraries).
PLUGIN="$PREFIX/plugins/sqldrivers/libqsqlmysql.so"
[ -f "$PLUGIN" ] || { echo "ERROR: $PLUGIN not built" >&2; exit 1; }
missing=$(env -u LD_LIBRARY_PATH ldd "$PLUGIN" | grep "not found" || true)
[ -z "$missing" ] || { echo "ERROR: $PLUGIN can't find: $missing" >&2; exit 1; }
env -u LD_LIBRARY_PATH ldd "$PLUGIN" | grep -E "mariadb|ssl|crypto"
echo "Qt $VER MySQL driver (MariaDB Connector/C $(basename "$CONNECTOR" | sed 's/.*-c-//')) installed to $PREFIX"
