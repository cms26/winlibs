#!/bin/bash
# nlohmann/json (header-only).
#
# Layout: the upstream include.zip (include/, single_include/, LICENSE.MIT,
# ...) plus the upstream CMake package config and pkg-config files from a
# CMake install of the release source, so consumers can use
#   find_package(nlohmann_json CONFIG REQUIRED)
#   target_link_libraries(app PRIVATE nlohmann_json::nlohmann_json)
# exactly as with the distribution packages on Linux.
source "$(dirname "$0")/env.sh"

VER=3.12.0
PREFIX="$REPO_ROOT/nlohmann/v$VER"

if [ ! -f "$SRC/nlohmann-$VER-include.zip" ]; then
    curl -sSfL -o "$SRC/nlohmann-$VER-include.zip" \
        "https://github.com/nlohmann/json/releases/download/v$VER/include.zip"
fi
if [ ! -d "$SRC/nlohmann-json-$VER" ]; then
    curl -sSfL -o "$SRC/nlohmann-json-$VER.tar.xz" \
        "https://github.com/nlohmann/json/releases/download/v$VER/json.tar.xz"
    mkdir -p "$SRC/nlohmann-json-$VER"
    tar -C "$SRC/nlohmann-json-$VER" --strip-components=1 -xf "$SRC/nlohmann-json-$VER.tar.xz"
fi

rm -rf "$PREFIX"
mkdir -p "$PREFIX"
unzip -q -o "$SRC/nlohmann-$VER-include.zip" -d "$PREFIX"

# Header-only, so no cross toolchain is needed; the generated config locates
# the headers relative to its own path (share/cmake/nlohmann_json -> include/).
B="$BLD/nlohmann-json"
STAGE="$BLD/nlohmann-json-install"
rm -rf "$B" "$STAGE"
cmake -G Ninja -S "$SRC/nlohmann-json-$VER" -B "$B" \
    -DJSON_BuildTests=OFF -DJSON_Install=ON -DCMAKE_INSTALL_PREFIX="$STAGE"
cmake --install "$B"

# The installed headers must match the include.zip ones we ship.
diff -r "$STAGE/include/nlohmann" "$PREFIX/include/nlohmann"
cp -r "$STAGE/share" "$PREFIX/"
# pkg-config file: use a relocatable prefix instead of the staging path.
sed -i 's#^prefix=.*#prefix=${pcfiledir}/../..#' "$PREFIX/share/pkgconfig/nlohmann_json.pc"
echo "nlohmann json $VER installed to $PREFIX"
