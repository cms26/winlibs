#!/bin/bash
# xcb-util-cursor 0.1.5. Qt's xcb platform plugin requires it (Qt 6.5+),
# but RHEL/Rocky 8 only has it in EPEL, and many target machines don't
# have it installed either ("xcb-cursor0 or libxcb-cursor0 is needed to
# load the Qt xcb platform plugin"). Built here and copied into Qt's lib/
# by build-qt.sh, so the deployed application carries its own copy.
#
# Upstream builds with autotools plus a git submodule hosted on
# freedesktop.org; the library is four C files, so it is compiled directly.
source "$(dirname "$0")/env.sh"

VER=0.1.5
PREFIX="$PREFIX_ROOT/xcb-util-cursor/$VER"

rm -rf "$SRC/xcb-util-cursor-$VER"
git clone -q --depth 1 --branch "xcb-util-cursor-$VER" \
    https://github.com/gitlab-freedesktop-mirrors/libxcb-cursor.git "$SRC/xcb-util-cursor-$VER"
cd "$SRC/xcb-util-cursor-$VER/cursor"

# Same gperf options as upstream's Makefile.am.
gperf --includes --struct-type --language=ANSI-C --switch=1 shape_to_id.gperf > shape_to_id.c

DEPS="xcb xcb-render xcb-renderutil xcb-image"
rm -rf "$PREFIX"
mkdir -p "$PREFIX/lib/pkgconfig" "$PREFIX/include/xcb"
# soname libxcb-cursor.so.0 as upstream (libtool -version-info 0:0:0);
# only the xcb_cursor_* API is exported, as upstream.
printf '{ global: xcb_cursor_*; local: *; };\n' > exports.map
# XCURSORPATH: upstream's default cursor theme search path (configure.ac).
gcc -O2 -fPIC -shared -DHAVE_ENDIAN_H -DHAVE_LE32TOH \
    -DXCURSORPATH='"~/.icons:/usr/share/icons:/usr/share/pixmaps:/usr/X11R6/lib/X11/icons"' \
    $(pkg-config --cflags $DEPS) \
    cursor.c shape_to_id.c load_cursor.c parse_cursor_file.c \
    -Wl,-soname,libxcb-cursor.so.0 -Wl,--version-script=exports.map -Wl,--no-undefined \
    $(pkg-config --libs $DEPS) \
    -o "$PREFIX/lib/libxcb-cursor.so.0.0.0"
ln -s libxcb-cursor.so.0.0.0 "$PREFIX/lib/libxcb-cursor.so.0"
ln -s libxcb-cursor.so.0 "$PREFIX/lib/libxcb-cursor.so"
cp xcb_cursor.h "$PREFIX/include/xcb/"
sed -e "s|@prefix@|\${pcfiledir}/../..|; s|@exec_prefix@|\${prefix}|; s|@libdir@|\${prefix}/lib|; s|@includedir@|\${prefix}/include|; s|@PACKAGE_VERSION@|$VER|; s|@LIBS@||" \
    xcb-cursor.pc.in > "$PREFIX/lib/pkgconfig/xcb-cursor.pc"
cp ../COPYING "$PREFIX/"
strip --strip-unneeded "$PREFIX/lib/libxcb-cursor.so.0.0.0"
[ "$(nm -D --defined-only "$PREFIX/lib/libxcb-cursor.so.0" | grep -c ' xcb_cursor_context_new' || true)" -eq 1 ] \
    || { echo "ERROR: libxcb-cursor does not export xcb_cursor_context_new" >&2; exit 1; }
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" pkg-config --modversion xcb-cursor
echo "xcb-util-cursor $VER installed to $PREFIX"
