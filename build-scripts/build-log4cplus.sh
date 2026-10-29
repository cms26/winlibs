#!/bin/bash
# log4cplus for 64-bit Windows.
#
# Two variants are built, each in its own prefix because both install a
# log4cplusConfig.cmake / log4cplusTargets.cmake that would overwrite each
# other:
#
#   log4cplus/log4cplus-<ver>             Unicode (tchar = wchar_t)
#       target log4cplus::log4cplusU, liblog4cplusU.dll / liblog4cplusUD.dll
#       Depends on the mingw runtime DLLs in runtime/.
#
#   log4cplus/log4cplus-<ver>-nonunicode  narrow (tchar = char)
#       target log4cplus::log4cplus,  liblog4cplus.dll  / liblog4cplusD.dll
#       libgcc, libstdc++ and winpthread are linked statically into the DLL
#       (log4cplus' own LOG4CPLUS_MINGW_STATIC_RUNTIME option), so it needs
#       no mingw runtime DLLs next to it.
source "$(dirname "$0")/env.sh"

VER=2.2.0.1
TAG=REL_2_2_0_1
OBJDUMP=${TRIPLET}-objdump

if [ ! -d "$SRC/log4cplus-$VER" ]; then
    curl -sSfL -o "$SRC/log4cplus-$VER.tar.xz" \
        "https://github.com/log4cplus/log4cplus/releases/download/$TAG/log4cplus-$VER.tar.xz"
    tar -C "$SRC" -xf "$SRC/log4cplus-$VER.tar.xz"
fi

# build_variant <name> <prefix> <extra cmake args...>
build_variant() {
    local name="$1" prefix="$2"
    shift 2
    rm -rf "$prefix"
    for WINLIBS_CONFIG in Release Debug; do
        export WINLIBS_CONFIG
        local b="$BLD/log4cplus-$name-$WINLIBS_CONFIG"
        rm -rf "$b"
        cmake_mingw -S "$SRC/log4cplus-$VER" -B "$b" \
            -DCMAKE_INSTALL_PREFIX="$prefix" \
            -DLOG4CPLUS_BUILD_TESTING=OFF -DLOG4CPLUS_BUILD_LOGGINGSERVER=OFF \
            -DWITH_UNIT_TESTS=OFF \
            "$@"
        cmake --build "$b" -j"$JOBS"
        cmake --install "$b"
        if [ "$WINLIBS_CONFIG" = Release ]; then strip_prefix "$prefix"; fi
    done
    echo "log4cplus $VER ($name) installed to $prefix"
}

# Fail the build if any DLL in a prefix still imports a mingw runtime DLL.
check_no_runtime_deps() {
    local dll bad=0
    compgen -G "$1/bin/*.dll" >/dev/null || { echo "ERROR: no DLLs in $1/bin" >&2; return 1; }
    for dll in "$1"/bin/*.dll; do
        if "$OBJDUMP" -p "$dll" | grep -Ei 'DLL Name: *(libstdc\+\+|libgcc_s|libwinpthread)'; then
            echo "ERROR: $dll still depends on the mingw runtime DLLs" >&2
            bad=1
        fi
    done
    return $bad
}

# Unicode variant: same as before (log4cplus defaults UNICODE=ON on Windows,
# made explicit here).
build_variant unicode "$REPO_ROOT/log4cplus/log4cplus-$VER" \
    -DUNICODE=ON

# Narrow (non-Unicode) variant with the mingw runtime linked statically.
NARROW_PREFIX="$REPO_ROOT/log4cplus/log4cplus-$VER-nonunicode"
build_variant nonunicode "$NARROW_PREFIX" \
    -DUNICODE=OFF \
    -DLOG4CPLUS_MINGW_STATIC_RUNTIME=ON
check_no_runtime_deps "$NARROW_PREFIX"
echo "verified: $NARROW_PREFIX/bin has no mingw runtime DLL dependencies"
