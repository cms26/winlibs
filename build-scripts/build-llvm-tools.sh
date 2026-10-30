#!/bin/bash
# LLVM source-code tools for Windows x64: clang-format, clang-tidy,
# clang-apply-replacements, plus the git-clang-format and run-clang-tidy
# helper scripts and clang's builtin headers (clang-tidy needs them, found
# via ../lib/clang/<major>/include relative to the exe).
#
# These are developer tools, not libraries: they are taken unmodified from
# the official LLVM Windows release (statically linked, no VC runtime
# needed) rather than built here. They work with any compiler, including
# the GCC/MinGW toolchain the libraries in this repo are built with.
#
# Installs to tools/llvm-<ver>/{bin,lib/clang/<major>/include,LICENSE.TXT}.
source "$(dirname "$0")/env.sh"

VER=23.1.4
MAJOR=${VER%%.*}
PREFIX="$REPO_ROOT/tools/llvm-$VER"
PKG="clang+llvm-$VER-x86_64-pc-windows-msvc"
ARCHIVE="$SRC/$PKG.tar.xz"

if [ ! -f "$ARCHIVE" ]; then
    curl -sSfL -o "$ARCHIVE" \
        "https://github.com/llvm/llvm-project/releases/download/llvmorg-$VER/$PKG.tar.xz"
fi

X="$BLD/llvm-tools-$VER"
rm -rf "$X" "$PREFIX"
mkdir -p "$X"
tar -C "$X" -xJf "$ARCHIVE" \
    "$PKG/bin/clang-format.exe" \
    "$PKG/bin/clang-tidy.exe" \
    "$PKG/bin/clang-apply-replacements.exe" \
    "$PKG/bin/git-clang-format" \
    "$PKG/bin/git-clang-format.bat" \
    "$PKG/bin/run-clang-tidy" \
    "$PKG/lib/clang/$MAJOR/include" \
    "$PKG/include/llvm/Support/LICENSE.TXT"

mkdir -p "$PREFIX/bin" "$PREFIX/lib/clang/$MAJOR"
cp "$X/$PKG"/bin/* "$PREFIX/bin/"
cp -r "$X/$PKG/lib/clang/$MAJOR/include" "$PREFIX/lib/clang/$MAJOR/"
cp "$X/$PKG/include/llvm/Support/LICENSE.TXT" "$PREFIX/LICENSE.TXT"

# GitHub rejects files over 100 MB.
if find "$PREFIX" -type f -size +95M | grep -q .; then
    echo "ERROR: a file in $PREFIX is too large for GitHub" >&2
    exit 1
fi
echo "LLVM tools $VER installed to $PREFIX"
