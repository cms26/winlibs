#!/bin/bash
# liquid-dsp for 64-bit Windows (autotools cross build).
source "$(dirname "$0")/env.sh"

VER=1.8.2
PREFIX="$REPO_ROOT/liquid-dsp/liquid-dsp-$VER"

if [ ! -d "$SRC/liquid-dsp-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/jgaeddert/liquid-dsp.git "$SRC/liquid-dsp-$VER"
fi

cd "$SRC/liquid-dsp-$VER"
[ -f configure ] || ./bootstrap.sh
rm -rf "$PREFIX"
make distclean >/dev/null 2>&1 || true
CC="$CC_MINGW" CXX="$CXX_MINGW" ./configure \
    --host=$TRIPLET --prefix="$PREFIX" \
    --enable-simdoverride
make -s -j"$JOBS"
make -s install
strip_prefix "$PREFIX"
echo "liquid-dsp $VER installed to $PREFIX"
