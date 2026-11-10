#!/bin/bash
# FFmpeg (shared, LGPL) for Qt Multimedia's FFmpeg backend
# (build-qt-extras.sh), FFmpeg 9.0, the series Qt 6.12 documents (9.0.1;
# 9.0.2 is its bug-fix release, same library versions).
#
#   build-ffmpeg.sh [version]     (default 9.0.2)
#
# Only what Qt needs (avcodec, avformat, avutil, swresample, swscale, plus
# avfilter), built with --disable-autodetect so the libraries need nothing
# beyond glibc, zlib and the OpenSSL from openssl/openssl-<ver> (for https
# streams; copied into Qt's lib/ with it). No hardware video decoding
# (VAAPI/VDPAU): those would make every target machine need libva. No GPL
# or nonfree parts, so the result is LGPL 2.1+ and can be shipped as shared
# libraries next to the application.
#
# The libraries get an $ORIGIN RUNPATH so they find each other and OpenSSL
# when deployed into one folder.
source "$(dirname "$0")/env.sh"

VER="${1:-${FFMPEG_VER:-9.0.2}}"
PREFIX="$PREFIX_ROOT/ffmpeg/ffmpeg-$VER"
OPENSSL="$PREFIX_ROOT/openssl/openssl-$OPENSSL_VER"

if [ ! -d "$SRC/ffmpeg-$VER" ]; then
    git -c advice.detachedHead=false clone -q --depth 1 --branch "n$VER" \
        https://github.com/FFmpeg/FFmpeg.git "$SRC/ffmpeg-$VER"
fi

B="$BLD/ffmpeg-$VER"
rm -rf "$B" "$PREFIX"
mkdir -p "$B"
cd "$B"
PKG_CONFIG_PATH="$OPENSSL/lib/pkgconfig" "$SRC/ffmpeg-$VER/configure" \
    --prefix="$PREFIX" --libdir="$PREFIX/lib" \
    --enable-shared --disable-static --enable-pic \
    --disable-programs --disable-doc --disable-debug \
    --disable-autodetect --enable-zlib --enable-openssl \
    --disable-avdevice \
    --extra-cflags="-I$OPENSSL/include" \
    --extra-ldflags="-L$OPENSSL/lib"
# $ORIGIN RUNPATH for the shared libraries. Added to the generated makefile
# rather than passed to configure, which would expand "$$" (the shell's PID).
# FFmpeg's makefiles expand LDSOFLAGS twice, so $ is written as $$$$; the
# quotes keep the shell from expanding $ORIGIN.
echo "LDSOFLAGS += -Wl,-rpath,'\$\$\$\$ORIGIN'" >> ffbuild/config.mak
make -s -j"$JOBS"
grep -q '#define FFMPEG_LICENSE "LGPL version 2.1 or later"' config.h \
    || { echo "ERROR: not an LGPL build:" >&2; grep FFMPEG_LICENSE config.h >&2; exit 1; }
make -s install
cd /
rm -rf "$B"
strip_prefix "$PREFIX"

# Checks: the libraries Qt needs, with an $ORIGIN RUNPATH.
for l in avcodec avformat avutil swresample swscale; do
    so=$(ls "$PREFIX/lib/lib$l.so."[0-9]* 2>/dev/null | head -1)
    [ -n "$so" ] || { echo "ERROR: lib$l.so not built" >&2; exit 1; }
    [ "$(readelf -d "$so" | grep -c 'RUNPATH.*\[\$ORIGIN\]' || true)" -eq 1 ] \
        || { echo "ERROR: $so has no \$ORIGIN RUNPATH" >&2; readelf -d "$so" | grep -i path; exit 1; }
done
echo "FFmpeg $VER installed to $PREFIX"
