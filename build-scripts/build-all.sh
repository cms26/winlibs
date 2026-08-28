#!/bin/bash
# Build every library in dependency order. Works directly on a Debian/Ubuntu
# host with the packages from the README (or the repo Dockerfile) installed.
#
#   WINLIBS_WORK   scratch dir for sources/builds (default ~/winlibs-work)
#   JOBS           parallel build jobs (default: nproc)
set -euo pipefail
cd "$(dirname "$0")"

LIBS=(
    # support deps first
    zlib openssl
    # header-only
    eigen nlohmann vkfft
    # standalone libraries
    fftw shapelib log4cplus portaudio soapysdr volk libssh flatbuffers
    liquid-dsp protobuf
    # boost, then its consumers
    boost wt cpprestsdk
    # Qt host tools, Qt for Windows, then Qt consumers
    qt-host qt qwt marble
    # mingw runtime DLLs
    runtime-dlls
)

for lib in "${LIBS[@]}"; do
    echo "=== $lib ($(date +%H:%M)) ==="
    bash "build-$lib.sh"
done
echo "=== all libraries built ==="
