#!/bin/bash
# Build every Linux library in dependency order (native, on Rocky/Alma 8
# with gcc-toolset; see linux/Dockerfile for the package list).
#
#   WINLIBS_PREFIX   install root (default /opt/winlibs)
#   WINLIBS_WORK     scratch dir for sources/builds (default ~/winlibs-work)
#   JOBS             parallel build jobs (default: nproc)
set -euo pipefail
cd "$(dirname "$0")"

LIBS=(header-only openssl fftw liquid-dsp log4cplus boost protobuf xcb-cursor qt qwt)

for lib in "${LIBS[@]}"; do
    echo "=== $lib ($(date +%H:%M)) ==="
    bash "build-$lib.sh"
done
source ./env.sh
echo "=== all libraries built in $PREFIX_ROOT (newest glibc symbol needed: $(max_glibc_needed "$PREFIX_ROOT")) ==="
