#!/bin/bash
# Collect the mingw-w64 runtime DLLs that the shared libraries in this repo
# depend on at run time. Ship these next to your application .exe.
source "$(dirname "$0")/env.sh"

PREFIX="$REPO_ROOT/runtime"
mkdir -p "$PREFIX"

GCC_LIBDIR="$(dirname "$($CC_MINGW -print-libgcc-file-name)")"
for dll in libstdc++-6.dll libgcc_s_seh-1.dll; do
    src="$(find "$GCC_LIBDIR" /usr/lib/gcc/$TRIPLET -name "$dll" 2>/dev/null | head -1)"
    [ -n "$src" ] && cp -v "$src" "$PREFIX/"
done
src="$(find /usr/$TRIPLET/lib "$GCC_LIBDIR" -name libwinpthread-1.dll 2>/dev/null | head -1)"
[ -n "$src" ] && cp -v "$src" "$PREFIX/"
"$STRIP" --strip-unneeded "$PREFIX"/*.dll || true

# Command-line tools that link their own shared libraries also need these
# runtime DLLs beside the .exe to run standalone (protoc/flatc are linked
# fully static and need nothing).
for tooldir in "$REPO_ROOT/openssl/openssl-3.5.8/bin" \
               "$REPO_ROOT/soapysdr/soapysdr-0.8.1/bin"; do
    [ -d "$tooldir" ] && cp "$PREFIX"/*.dll "$tooldir/"
done
ls -la "$PREFIX"
