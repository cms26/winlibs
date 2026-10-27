#!/bin/bash
# SoapySDR for 64-bit Windows (library + SoapySDRUtil, no python bindings).
source "$(dirname "$0")/env.sh"

VER=0.8.1
PREFIX="$REPO_ROOT/soapysdr/soapysdr-$VER"

if [ ! -d "$SRC/soapysdr-$VER" ]; then
    git clone --depth 1 --branch "soapy-sdr-$VER" https://github.com/pothosware/SoapySDR.git "$SRC/soapysdr-$VER"
fi

rm -rf "$PREFIX"
# Legacy codelibrary layout: per-config subfolders lib/Release and lib/Debug
# with same-named binaries, rather than side-by-side 'd'-suffixed files.
# Debug installs first so the release pass keeps bin/SoapySDRUtil.exe.
for WINLIBS_CONFIG in Debug Release; do
    export WINLIBS_CONFIG
    B="$BLD/soapysdr-$WINLIBS_CONFIG"
    rm -rf "$B"
    cmake_mingw -S "$SRC/soapysdr-$VER" -B "$B" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_DEBUG_POSTFIX= \
        -DENABLE_PYTHON=OFF -DENABLE_PYTHON3=OFF -DENABLE_TESTS=OFF
    cmake --build "$B" -j"$JOBS"
    cmake --install "$B"
    [ "$WINLIBS_CONFIG" = Release ] && strip_prefix "$PREFIX"

    CFGDIR="$PREFIX/lib/$WINLIBS_CONFIG"
    mkdir -p "$CFGDIR"
    mv "$PREFIX/bin/libSoapySDR.dll" "$CFGDIR/"
    mv "$PREFIX/lib/libSoapySDR.dll.a" "$CFGDIR/"
    # Point the exported cmake targets at the per-config location.
    CFGLOWER=$(echo "$WINLIBS_CONFIG" | tr 'A-Z' 'a-z')
    EXP="$PREFIX/cmake/SoapySDRExport-$CFGLOWER.cmake"
    [ -f "$EXP" ] && sed -i "s|\${_IMPORT_PREFIX}/lib/libSoapySDR|\${_IMPORT_PREFIX}/lib/$WINLIBS_CONFIG/libSoapySDR|g; s|\${_IMPORT_PREFIX}/bin/libSoapySDR|\${_IMPORT_PREFIX}/lib/$WINLIBS_CONFIG/libSoapySDR|g" "$EXP"
done
# SoapySDRUtil.exe (release) needs the DLL beside it to run standalone.
cp "$PREFIX/lib/Release/libSoapySDR.dll" "$PREFIX/bin/"
echo "SoapySDR $VER installed to $PREFIX"
