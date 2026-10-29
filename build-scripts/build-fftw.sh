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
    mv "$SRC/fftw3-$VER" "$SRC/fftw-$VER"
fi
# FFTW 3.3.10's CMakeLists.txt still says `set (FFTW_VERSION 3.3.9)`, so the
# installed FFTW3(f)ConfigVersion.cmake and .pc files report 3.3.9 and
# find_package(FFTW3 3.3.10) fails. Use the real version.
sed -i "s/^set (FFTW_VERSION [0-9.]*)/set (FFTW_VERSION $VER)/" "$SRC/fftw-$VER/CMakeLists.txt"

rm -rf "$PREFIX"
for WINLIBS_CONFIG in Release Debug; do
  export WINLIBS_CONFIG
  for cfg in double single; do
    EXTRA=""
    if [ "$cfg" = single ]; then EXTRA="-DENABLE_FLOAT=ON -DENABLE_SSE=ON"; fi
    for linkage in shared static; do
        B="$BLD/fftw-$cfg-$linkage-$WINLIBS_CONFIG"
        rm -rf "$B"
        SHARED=OFF; [ "$linkage" = shared ] && SHARED=ON
        cmake_mingw -S "$SRC/fftw-$VER" -B "$B" \
            -DCMAKE_INSTALL_PREFIX="$PREFIX" \
            -DBUILD_SHARED_LIBS=$SHARED \
            -DBUILD_TESTS=OFF \
            -DCMAKE_C_FLAGS="-DWITH_OUR_MALLOC" \
            -DENABLE_SSE2=ON -DENABLE_AVX=ON -DENABLE_AVX2=ON \
            -DENABLE_THREADS=ON -DWITH_COMBINED_THREADS=ON \
            $EXTRA
        cmake --build "$B" -j"$JOBS"
        cmake --install "$B"
    done
  done
  [ "$WINLIBS_CONFIG" = Release ] && strip_prefix "$PREFIX"
done
echo "fftw $VER installed to $PREFIX"
