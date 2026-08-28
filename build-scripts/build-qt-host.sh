#!/bin/bash
# Qt 6.11.2 HOST tools build (runs on the Linux build host, NOT shipped).
# Provides moc/rcc/uic/etc. for the Windows cross build via QT_HOST_PATH.
source "$(dirname "$0")/env.sh"

VER=6.11.2
HOST_PREFIX="$WORK/qt-host-$VER"

if [ ! -d "$SRC/qtbase-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/qt/qtbase.git "$SRC/qtbase-$VER"
fi

B="$BLD/qt-host"
rm -rf "$B"
cmake -G Ninja -S "$SRC/qtbase-$VER" -B "$B" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$HOST_PREFIX" \
    -DQT_FEATURE_gui=OFF -DQT_FEATURE_widgets=OFF \
    -DQT_FEATURE_sql=OFF -DQT_FEATURE_dbus=OFF \
    -DQT_FEATURE_icu=OFF \
    -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
echo "Qt $VER host tools installed to $HOST_PREFIX"
