#!/bin/bash
# Qt 6.11.2 HOST tools build (runs on the Linux build host, NOT shipped).
# Provides moc/rcc/uic/etc. for the Windows cross build via QT_HOST_PATH.
source "$(dirname "$0")/env.sh"

VER=6.11.2
HOST_PREFIX="$WORK/qt-host-$VER"

# gui/widgets must stay enabled: the host qtshadertools/qtdeclarative tools
# (qsb, qmlcachegen, ...) that the Windows cross build needs depend on them.
for m in qtbase qtshadertools qtdeclarative; do
    if [ ! -d "$SRC/$m-$VER" ]; then
        git clone --depth 1 --branch "v$VER" "https://github.com/qt/$m.git" "$SRC/$m-$VER"
    fi
    B="$BLD/qt-host-$m"
    rm -rf "$B"
    EXTRA=""
    if [ "$m" = qtbase ]; then
        EXTRA="-DQT_FEATURE_sql=OFF -DQT_FEATURE_dbus=OFF -DQT_FEATURE_icu=OFF"
    fi
    cmake -G Ninja -S "$SRC/$m-$VER" -B "$B" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$HOST_PREFIX" \
        -DCMAKE_PREFIX_PATH="$HOST_PREFIX" \
        -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
        $EXTRA
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
done
echo "Qt $VER host tools installed to $HOST_PREFIX"
