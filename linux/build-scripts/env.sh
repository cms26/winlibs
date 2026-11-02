# Common environment for the winlibs Linux build scripts (native builds).
# Source this from each build-*.sh script.
#
# Host: Rocky/Alma/RHEL 8 with gcc-toolset (see linux/Dockerfile). Building
# on the oldest supported glibc (2.28) is what makes the results run on
# newer distributions too (RHEL 8+/9+, Ubuntu 20.04+, Debian 11+, ...).
#
#   WINLIBS_PREFIX   install root (default /opt/winlibs)
#   WINLIBS_WORK     scratch dir for sources/builds (default ~/winlibs-work)
#   JOBS             parallel build jobs (default: nproc)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$LINUX_DIR")"
# Shared with the Windows build (CMake files, patches).
WIN_SCRIPTS="$REPO_ROOT/build-scripts"

PREFIX_ROOT="${WINLIBS_PREFIX:-/opt/winlibs}"
JOBS="${JOBS:-$(nproc)}"
WORK="${WINLIBS_WORK:-$HOME/winlibs-work}"
SRC="$WORK/src"
BLD="$WORK/build"
mkdir -p "$SRC" "$BLD" "$PREFIX_ROOT"

# Library versions, shared by the scripts that depend on each other.
QT_VER=6.12.0
OPENSSL_VER=3.5.8
FFTW_VER=3.3.10
PROTOBUF_VER=36.0
BOOST_VER_DEFAULT=1.86.0

# gcc-toolset: newer GCC whose binaries still only need the system's
# libstdc++/libgcc (the newer parts are linked in statically from
# libstdc++_nonshared.a).
if [ -z "${WINLIBS_NO_TOOLSET:-}" ] && [ -z "${GCC_TOOLSET_ENABLED:-}" ]; then
    for ts in /opt/rh/gcc-toolset-14 /opt/rh/gcc-toolset-13; do
        if [ -f "$ts/enable" ]; then
            # shellcheck disable=SC1091
            set +u; source "$ts/enable"; set -u
            export GCC_TOOLSET_ENABLED="$ts"
            break
        fi
    done
fi
export CC="${CC:-gcc}" CXX="${CXX:-g++}"

# Release builds, position-independent code everywhere (static libraries
# may end up inside shared libraries or PIE executables), and $ORIGIN
# relative RPATHs so installed shared libraries find their siblings.
cmake_native() {
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE="${WINLIBS_CONFIG:-Release}" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_INSTALL_RPATH='$ORIGIN' \
        "$@"
}

# Strip release binaries under a prefix (shared libraries, executables,
# static archives).
strip_prefix() {
    local prefix="$1"
    find "$prefix" -type f \( -name '*.so' -o -name '*.so.*' \) \
        | xargs -r strip --strip-unneeded 2>/dev/null || true
    find "$prefix" -type f -path '*/bin/*' -perm -u+x \
        | xargs -r strip --strip-unneeded 2>/dev/null || true
    find "$prefix" -type f -name '*.a' \
        | xargs -r strip --strip-debug 2>/dev/null || true
}

# The newest glibc symbol version any ELF file under a prefix requires.
# Used to check that nothing needs more than the build system's glibc.
max_glibc_needed() {
    find "$1" -type f \( -name '*.so*' -o -perm -u+x \) -print0 \
        | xargs -0 -r objdump -T 2>/dev/null \
        | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -V -u | tail -1
}
