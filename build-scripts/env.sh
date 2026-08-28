# Common environment for all winlibs cross-build scripts.
# Source this from each build-*.sh script.
#
# Host: Linux with the Ubuntu/Debian mingw-w64 toolchain (posix threads
# variant) installed:  apt-get install mingw-w64
# Target: 64-bit Windows (x86_64-w64-mingw32)
#
# Set WINLIBS_WORK to override where sources are unpacked and built.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TOOLCHAIN_FILE="$SCRIPT_DIR/toolchain-mingw64.cmake"

TRIPLET=x86_64-w64-mingw32
JOBS="${JOBS:-$(nproc)}"
WORK="${WINLIBS_WORK:-$HOME/winlibs-work}"
SRC="$WORK/src"
BLD="$WORK/build"
mkdir -p "$SRC" "$BLD"

# Prefer the posix-threads compilers explicitly so the scripts work even when
# update-alternatives still points at the win32-threads variant.
if command -v ${TRIPLET}-gcc-posix >/dev/null 2>&1; then
    export CC_MINGW=${TRIPLET}-gcc-posix
    export CXX_MINGW=${TRIPLET}-g++-posix
else
    export CC_MINGW=${TRIPLET}-gcc
    export CXX_MINGW=${TRIPLET}-g++
fi

STRIP=${TRIPLET}-strip

# cmake configured for cross-compiling to Windows
cmake_mingw() {
    cmake -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
        -DCMAKE_BUILD_TYPE=Release \
        "$@"
}

# Strip all dlls/exes/static libs under a prefix to keep the repo small.
strip_prefix() {
    local prefix="$1"
    find "$prefix" -name '*.dll' -o -name '*.exe' | xargs -r "$STRIP" --strip-unneeded || true
    find "$prefix" -name '*.a' ! -name '*.dll.a' | xargs -r "$STRIP" --strip-debug || true
}
