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

# cmake configured for cross-compiling to Windows.
# WINLIBS_CONFIG selects the configuration (default Release). Debug builds
# install side by side with release using the usual Windows 'd' suffix
# (libfoo.dll / libfood.dll), giving two-config CMake packages.
cmake_mingw() {
    cmake -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
        -DCMAKE_BUILD_TYPE="${WINLIBS_CONFIG:-Release}" \
        -DCMAKE_DEBUG_POSTFIX=d \
        "$@"
}

# Trim a debug/ subtree down to binaries (used by the few libraries whose
# build system cannot produce side-by-side 'd'-suffixed binaries): headers
# and data are shared with the release install.
prune_debug_subtree() {
    rm -rf "$1/include" "$1/share" "$1/cmake" "$1/etc" \
           "$1/lib/cmake" "$1/lib/pkgconfig"
}

# Strip all dlls/exes/static libs under a prefix to keep the repo small.
# Debug subtrees keep their symbols.
strip_prefix() {
    local prefix="$1"
    find "$prefix" -not -path '*/debug/*' -not -path '*/Debug/*' \
        \( -name '*.dll' -o -name '*.exe' \) \
        | xargs -r "$STRIP" --strip-unneeded || true
    find "$prefix" -not -path '*/debug/*' -not -path '*/Debug/*' \
        -name '*.a' ! -name '*.dll.a' \
        | xargs -r "$STRIP" --strip-debug || true
}
