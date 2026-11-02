#!/bin/bash
# Header-only libraries: Eigen, nlohmann/json, VkFFT. Same layout and CMake
# packages as the Windows tree (they are architecture independent).
source "$(dirname "$0")/env.sh"

# --- Eigen 3.4.1 ---
VER=3.4.1
PREFIX="$PREFIX_ROOT/eigen/eigen-$VER"
if [ ! -d "$SRC/eigen-$VER" ]; then
    curl -sSfL -o "$SRC/eigen-$VER.tar.gz" \
        "https://gitlab.com/libeigen/eigen/-/archive/$VER/eigen-$VER.tar.gz"
    tar -C "$SRC" -xf "$SRC/eigen-$VER.tar.gz"
fi
rm -rf "$BLD/eigen" "$PREFIX"
cmake -G Ninja -S "$SRC/eigen-$VER" -B "$BLD/eigen" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DEIGEN_BUILD_DOC=OFF -DEIGEN_BUILD_TESTING=OFF -DEIGEN_BUILD_DEMOS=OFF -DBUILD_TESTING=OFF
cmake --install "$BLD/eigen"
echo "eigen $VER installed to $PREFIX"

# --- nlohmann/json 3.12.0 ---
VER=3.12.0
PREFIX="$PREFIX_ROOT/nlohmann/v$VER"
if [ ! -d "$SRC/nlohmann-json-$VER" ]; then
    curl -sSfL -o "$SRC/nlohmann-json-$VER.tar.xz" \
        "https://github.com/nlohmann/json/releases/download/v$VER/json.tar.xz"
    mkdir -p "$SRC/nlohmann-json-$VER"
    tar -C "$SRC/nlohmann-json-$VER" --strip-components=1 -xf "$SRC/nlohmann-json-$VER.tar.xz"
fi
rm -rf "$BLD/nlohmann-json" "$PREFIX"
cmake -G Ninja -S "$SRC/nlohmann-json-$VER" -B "$BLD/nlohmann-json" \
    -DJSON_BuildTests=OFF -DJSON_Install=ON -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --install "$BLD/nlohmann-json"
echo "nlohmann json $VER installed to $PREFIX"

# --- VkFFT 1.3.4 ---
VER=1.3.4
PREFIX="$PREFIX_ROOT/vkfft/vkfft-$VER"
if [ ! -d "$SRC/vkfft-$VER" ]; then
    git clone -q --depth 1 --branch "v$VER" https://github.com/DTolm/VkFFT.git "$SRC/vkfft-$VER"
fi
rm -rf "$PREFIX"
mkdir -p "$PREFIX/include" "$PREFIX/share/cmake/VkFFT"
cp -r "$SRC/vkfft-$VER/vkFFT" "$PREFIX/include/"
cp "$SRC/vkfft-$VER/LICENSE" "$PREFIX/"
cp "$WIN_SCRIPTS/vkfft-cmake/VkFFTConfig.cmake" "$PREFIX/share/cmake/VkFFT/"
cat > "$BLD/vkfft-version.cmake" <<'CM'
include(CMakePackageConfigHelpers)
write_basic_package_version_file("${OUT}" VERSION "${VER}" COMPATIBILITY SameMinorVersion ARCH_INDEPENDENT)
CM
cmake -DVER="$VER" -DOUT="$PREFIX/share/cmake/VkFFT/VkFFTConfigVersion.cmake" -P "$BLD/vkfft-version.cmake"
echo "VkFFT $VER installed to $PREFIX"
