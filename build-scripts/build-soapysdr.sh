#!/bin/bash
# SoapySDR for 64-bit Windows (library + SoapySDRUtil, no python bindings).
source "$(dirname "$0")/env.sh"

VER=0.8.1
PREFIX="$REPO_ROOT/soapysdr/soapysdr-$VER"

if [ ! -d "$SRC/soapysdr-$VER" ]; then
    git clone --depth 1 --branch "soapy-sdr-$VER" https://github.com/pothosware/SoapySDR.git "$SRC/soapysdr-$VER"
fi

B="$BLD/soapysdr"
rm -rf "$B" "$PREFIX"
cmake_mingw -S "$SRC/soapysdr-$VER" -B "$B" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DENABLE_PYTHON=OFF -DENABLE_PYTHON3=OFF -DENABLE_TESTS=OFF
cmake --build "$B" -j"$JOBS"
cmake --install "$B"
strip_prefix "$PREFIX"
echo "SoapySDR $VER installed to $PREFIX"
