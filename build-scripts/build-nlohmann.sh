#!/bin/bash
# nlohmann/json (header-only).
source "$(dirname "$0")/env.sh"

VER=3.12.0
PREFIX="$REPO_ROOT/nlohmann/v$VER"

if [ ! -f "$SRC/nlohmann-$VER-include.zip" ]; then
    curl -sSfL -o "$SRC/nlohmann-$VER-include.zip" \
        "https://github.com/nlohmann/json/releases/download/v$VER/include.zip"
fi

rm -rf "$PREFIX"
mkdir -p "$PREFIX"
unzip -q -o "$SRC/nlohmann-$VER-include.zip" -d "$PREFIX"
echo "nlohmann json $VER installed to $PREFIX"
