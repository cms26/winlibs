#!/bin/bash
# FFTW 3.3.10 for 64-bit Windows — double (fftw3) and single (fftw3f)
# precision, with SIMD codelets and threads. Shared + static.
source "$(dirname "$0")/env.sh"

VER=3.3.10
PREFIX="$REPO_ROOT/fftw/fftw-$VER"

if [ ! -d "$SRC/fftw-$VER" ]; then
    # fftw.org mirror of record; Ubuntu archive carries the identical tarball.
    curl -sSfL -o "$SRC/fftw-$VER.tar.gz" \
        "http://archive.ubuntu.com/ubuntu/pool/main/f/fftw3/fftw3_$VER.orig.tar.gz"
    tar -C "$SRC" -xf "$SRC/fftw-$VER.tar.gz"
fi

rm -rf "$PREFIX"
for cfg in double single; do
    EXTRA=""
    if [ "$cfg" = single ]; then EXTRA="-DENABLE_FLOAT=ON -DENABLE_SSE=ON"; fi
    for linkage in shared static; do
        B="$BLD/fftw-$cfg-$linkage"
        rm -rf "$B"
        SHARED=OFF; [ "$linkage" = shared ] && SHARED=ON
        cmake_mingw -S "$SRC/fftw-$VER" -B "$B" \
            -DCMAKE_INSTALL_PREFIX="$PREFIX" \
            -DBUILD_SHARED_LIBS=$SHARED \
            -DBUILD_TESTS=OFF \
            -DENABLE_SSE2=ON -DENABLE_AVX=ON -DENABLE_AVX2=ON \
            -DENABLE_THREADS=ON -DWITH_COMBINED_THREADS=ON \
            $EXTRA
        cmake --build "$B" -j"$JOBS"
        cmake --install "$B"
    done
done
strip_prefix "$PREFIX"
echo "fftw $VER installed to $PREFIX"
