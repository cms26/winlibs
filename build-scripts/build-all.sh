#!/bin/bash
# Build every library in dependency order. Works directly on a Debian/Ubuntu
# host with the packages from the README (or windows/Dockerfile) installed.
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
    liquid-dsp protobuf mariadb-connector-c
    # boost, then its consumers; boost-1.86 is the legacy-Asio install
    boost boost-1.86 wt cpprestsdk
    # Qt host tools and a build-only Qt for Windows (not shipped), then the
    # Qt consumers
    qt-host qt qwt marble
    # mingw runtime DLLs
    runtime-dlls
    # developer tools (clang-format, clang-tidy) from the official LLVM release
    llvm-tools
)

for lib in "${LIBS[@]}"; do
    echo "=== $lib ($(date +%H:%M)) ==="
    bash "build-$lib.sh"
done
echo "=== all libraries built ==="
