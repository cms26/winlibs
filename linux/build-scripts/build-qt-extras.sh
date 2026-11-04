#!/bin/bash
# Qt add-on modules built after the main Qt (build-qt.sh), for the Qt in
# qt/<QT_VER>:
#
#   qtmultimedia    Qt Multimedia, FFmpeg backend
#   qtpositioning   Qt Positioning (GeoClue2 over D-Bus, NMEA via Qt Serial
#                   Port), Qt6::Positioning
#   qtlocation      Qt Location (maps, routing; QML-based), Qt6::Location
#
#   build-qt-extras.sh                  all of them, in this order
#   build-qt-extras.sh <module>...      just these
#
# A separate script and Dockerfile step (not part of build-qt.sh), so adding
# modules here doesn't invalidate the cached Qt layers.
#
# Multimedia: FFmpeg from ffmpeg/ffmpeg-<ver> (build-ffmpeg.sh); its shared
# libraries are copied into Qt's lib/ (QT_DEPLOY_FFMPEG), next to OpenSSL,
# so they are deployed with the application like the rest of Qt. Audio goes
# through PulseAudio (libpulse, on every desktop: PulseAudio itself or
# PipeWire's PulseAudio server); PipeWire is used directly if installed
# (loaded at run time). No GStreamer backend: it would make the application
# depend on the target's GStreamer plugins. Needs pulseaudio-libs-devel and
# pipewire-devel (linux/Dockerfile).
source "$(dirname "$0")/env.sh"

VER=$QT_VER
PREFIX="$PREFIX_ROOT/qt/$VER"
ALL="qtmultimedia qtpositioning qtlocation"
MODULES="${*:-$ALL}"
[ -f "$PREFIX/lib/cmake/Qt6/Qt6Config.cmake" ] \
    || { echo "ERROR: Qt $VER not installed in $PREFIX (run build-qt.sh)" >&2; exit 1; }

for m in $MODULES; do
    case " $ALL " in *" $m "*) ;; *) echo "ERROR: unknown module $m (known: $ALL)" >&2; exit 1 ;; esac
    if [ ! -d "$SRC/$m-$VER" ]; then
        git -c advice.detachedHead=false clone -q --depth 1 --branch "v$VER" \
            "https://github.com/qt/$m.git" "$SRC/$m-$VER"
    fi

    EXTRA=()
    if [ "$m" = qtmultimedia ]; then
        # Qt's internal test-helper library (only for Qt's own tests) needs
        # <linux/udmabuf.h>, which RHEL 8's kernel headers (4.18) don't have.
        sed -i 's|^    add_subdirectory(multimediatestlib)|    # winlibs: Qt-internal test helper skipped (needs Linux 4.20+ headers)|' \
            "$SRC/$m-$VER/src/CMakeLists.txt"
        FFMPEG=$(ls -d "$PREFIX_ROOT"/ffmpeg/ffmpeg-* 2>/dev/null | sort -V | tail -1)
        [ -n "$FFMPEG" ] || { echo "ERROR: no FFmpeg in $PREFIX_ROOT/ffmpeg (run build-ffmpeg.sh)" >&2; exit 1; }
        EXTRA=(-DFFMPEG_DIR="$FFMPEG" -DQT_DEPLOY_FFMPEG=ON -DINPUT_ffmpeg=yes
               -DQT_FEATURE_gstreamer=OFF -DQT_FEATURE_pulseaudio=ON)
    fi

    B="$BLD/qt-$m"
    rm -rf "$B"
    cmake -G Ninja -S "$SRC/$m-$VER" -B "$B" \
        -DCMAKE_PREFIX_PATH="$PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
        "${EXTRA[@]}"
    if [ "$m" = qtmultimedia ]; then
        # The configure summary must show the FFmpeg backend and PulseAudio.
        grep -iE "^\s*(ffmpeg|pulseaudio|pipewire|gstreamer|alsa|vaapi)[^.]*\.{3,}" "$B/config.summary" || true
        grep -Eq "^\s*FFmpeg \.+ yes" "$B/config.summary" \
            || { echo "ERROR: Qt Multimedia configured without FFmpeg" >&2; exit 1; }
        grep -Eiq "^\s*pulseaudio \.+ yes" "$B/config.summary" \
            || { echo "ERROR: Qt Multimedia configured without PulseAudio" >&2; exit 1; }
    fi
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
    rm -rf "$B"

    if [ "$m" = qtmultimedia ] && ! ls "$PREFIX"/lib/libavcodec.so.* >/dev/null 2>&1; then
        # QT_DEPLOY_FFMPEG didn't copy them: the FFmpeg plugin needs them.
        cp -a "$FFMPEG"/lib/lib{avcodec,avformat,avutil,swresample,swscale,avfilter}.so* "$PREFIX/lib/"
    fi
done
strip_prefix "$PREFIX"

# Checks for what was built
check() { [ -e "$1" ] || { echo "ERROR: $2 missing: $1" >&2; exit 1; }; }
for m in $MODULES; do
    case $m in
        qtmultimedia)
            check "$PREFIX/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake" Qt6Multimedia
            check "$PREFIX/lib/cmake/Qt6MultimediaWidgets/Qt6MultimediaWidgetsConfig.cmake" Qt6MultimediaWidgets
            PLUGIN="$PREFIX/plugins/multimedia/libffmpegmediaplugin.so"
            check "$PLUGIN" "FFmpeg media plugin"
            missing=$(env -u LD_LIBRARY_PATH ldd "$PLUGIN" | grep "not found" || true)
            [ -z "$missing" ] || { echo "ERROR: $PLUGIN can't find: $missing" >&2; exit 1; } ;;
        qtpositioning)
            check "$PREFIX/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake" Qt6Positioning ;;
        qtlocation)
            check "$PREFIX/lib/cmake/Qt6Location/Qt6LocationConfig.cmake" Qt6Location ;;
    esac
done
echo "Qt $VER: $MODULES installed to $PREFIX"
