#!/bin/bash
# PortAudio v19.7 for 64-bit Windows (WMME/DirectSound/WASAPI/WDM-KS hosts).
source "$(dirname "$0")/env.sh"

VER=19.7.0
PREFIX="$REPO_ROOT/portaudio/portaudio-$VER"

if [ ! -d "$SRC/portaudio-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/PortAudio/portaudio.git "$SRC/portaudio-$VER"
fi

B="$BLD/portaudio"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/portaudio-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DPA_BUILD_SHARED=ON -DPA_BUILD_STATIC=ON \
    -DPA_USE_WASAPI=ON -DPA_USE_WDMKS=ON -DPA_USE_DS=ON -DPA_USE_WMME=ON \
    -DPA_BUILD_TESTS=OFF -DPA_BUILD_EXAMPLES=OFF
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "portaudio $VER installed to $PREFIX"
