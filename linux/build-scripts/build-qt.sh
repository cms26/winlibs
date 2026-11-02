#!/bin/bash
# Qt 6.12.0 for Linux x86-64, built on the old-glibc base so it runs on the
# same range of distributions as the application (the official Qt binaries
# need glibc 2.34+).
#
# Modules: qtbase, qtshadertools, qtdeclarative, qtsvg, qtimageformats,
# qtserialport, qt5compat, qtwebsockets, qtgrpc (QtProtobuf/QtGrpc,
# qt_add_protobuf). OpenSSL linked against openssl/openssl-<ver>; protobuf
# from gpb/<ver>.
#
# Third-party code that differs between distributions (ICU, HarfBuzz, PCRE2,
# libpng, libjpeg, double-conversion, libb2, md4c) is Qt's bundled copy, so
# the deployed app doesn't need matching versions on the target. Libraries
# that are part of every desktop (X11/xcb, GL/EGL, fontconfig, freetype,
# glib, zlib, dbus) come from the system.
#
# Requires build-openssl.sh, build-protobuf.sh and build-xcb-cursor.sh.
#
#   build-qt.sh                  qtbase + all modules, then the checks
#   build-qt.sh qtbase           just qtbase
#   build-qt.sh <module>...      just these add-on modules (qtbase installed)
#   build-qt.sh --check          only the checks
# (the Dockerfile builds Qt in several layers, so a rebuild after a failure
# doesn't start Qt from scratch)
source "$(dirname "$0")/env.sh"

VER=$QT_VER
PREFIX="$PREFIX_ROOT/qt/$VER"
OPENSSL="$PREFIX_ROOT/openssl/openssl-$OPENSSL_VER"
PROTOBUF="$PREFIX_ROOT/gpb/$PROTOBUF_VER/c++"
XCB_CURSOR="$PREFIX_ROOT/xcb-util-cursor/0.1.5"
# xcb-util-cursor isn't in the RHEL 8 base repositories (build-xcb-cursor.sh)
export PKG_CONFIG_PATH="$XCB_CURSOR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

ALL_MODULES="qtshadertools qtdeclarative qtsvg qtimageformats qtserialport qt5compat qtwebsockets qtgrpc"
CHECK=0
if [ $# -eq 0 ]; then
    WANT="qtbase $ALL_MODULES"; CHECK=1
elif [ "$1" = --check ]; then
    WANT=""; CHECK=1
else
    WANT="$*"
fi
MODULES=""
for m in $WANT; do [ "$m" = qtbase ] || MODULES="$MODULES $m"; done
for m in $WANT; do
    if [ ! -d "$SRC/$m-$VER" ]; then
        git clone -q --depth 1 --branch "v$VER" "https://github.com/qt/$m.git" "$SRC/$m-$VER"
    fi
done

# Install RPATH: Qt's libraries, plugins and tools find each other through
# $ORIGIN-relative paths (QT_FEATURE_relocatable, default) and OpenSSL is
# copied next to libQt6Network, so the prefix can be moved or deployed.
if [[ " $WANT " == *" qtbase "* ]]; then
    B="$BLD/qt-qtbase"
    rm -rf "$B"
    cmake -G Ninja -S "$SRC/qtbase-$VER" -B "$B" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
        -DQT_FEATURE_xcb=ON -DQT_FEATURE_xcb_xlib=ON -DQT_FEATURE_xlib=ON \
        -DQT_FEATURE_opengl=ON -DQT_FEATURE_egl=ON \
        -DQT_FEATURE_dbus=ON -DQT_FEATURE_dbus_linked=OFF \
        -DQT_FEATURE_icu=OFF \
        -DQT_FEATURE_system_harfbuzz=OFF -DQT_FEATURE_system_pcre2=OFF \
        -DQT_FEATURE_system_png=OFF -DQT_FEATURE_system_jpeg=OFF \
        -DQT_FEATURE_system_doubleconversion=OFF -DQT_FEATURE_system_libb2=OFF \
        -DQT_FEATURE_system_textmarkdownreader=OFF \
        -DQT_FEATURE_system_freetype=ON -DQT_FEATURE_fontconfig=ON \
        -DQT_FEATURE_system_zlib=ON \
        -DQT_FEATURE_sql_sqlite=ON -DQT_FEATURE_system_sqlite=OFF \
        -DQT_FEATURE_sql_odbc=OFF -DQT_FEATURE_sql_psql=OFF -DQT_FEATURE_sql_mysql=OFF \
        -DINPUT_openssl=linked -DOPENSSL_ROOT_DIR="$OPENSSL" -DOPENSSL_USE_STATIC_LIBS=OFF
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
    rm -rf "$B"

    # Ship OpenSSL and xcb-util-cursor inside the Qt prefix (libQt6Network
    # and the xcb plugin link them; $ORIGIN-relative RPATHs find them there).
    cp -a "$OPENSSL"/lib/libssl.so* "$OPENSSL"/lib/libcrypto.so* "$XCB_CURSOR"/lib/libxcb-cursor.so* "$PREFIX/lib/"
    strip_prefix "$PREFIX"
fi

for m in $MODULES; do
    B="$BLD/qt-$m"
    rm -rf "$B"
    PP="$PREFIX"
    # qtgrpc: QtProtobuf/QtGrpc and the qtprotobufgen/qtgrpcgen protoc
    # plugins, built against the repo's protobuf (static, bundled Abseil).
    [ "$m" = qtgrpc ] && PP="$PREFIX;$PROTOBUF"
    cmake -G Ninja -S "$SRC/$m-$VER" -B "$B" \
        -DCMAKE_PREFIX_PATH="$PP" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
    rm -rf "$B"
done

[ -n "$MODULES" ] && strip_prefix "$PREFIX"
[ "$CHECK" = 1 ] || { echo "Qt $VER:$WANT installed to $PREFIX"; exit 0; }

# The modules the app relies on must be there.
for c in Core Gui Widgets Network WebSockets SerialPort Svg OpenGL OpenGLWidgets \
         Concurrent PrintSupport Protobuf Qml Quick Core5Compat; do
    [ -f "$PREFIX/lib/cmake/Qt6$c/Qt6${c}Config.cmake" ] \
        || { echo "ERROR: Qt6$c not installed" >&2; exit 1; }
done
[ -x "$PREFIX/libexec/qtprotobufgen" ] || [ -x "$PREFIX/bin/qtprotobufgen" ] \
    || { echo "ERROR: qtprotobufgen not built" >&2; exit 1; }
[ -f "$PREFIX/plugins/platforms/libqxcb.so" ] \
    || { echo "ERROR: xcb platform plugin not built" >&2; exit 1; }
echo "Qt $VER installed to $PREFIX"
