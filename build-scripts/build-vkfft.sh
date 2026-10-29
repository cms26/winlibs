#!/bin/bash
# VkFFT (header-only GPU FFT library). Ships the vkFFT header tree; consumers
# pick the backend (Vulkan/CUDA/HIP/OpenCL/...) via VKFFT_BACKEND.
source "$(dirname "$0")/env.sh"

VER=1.3.4
PREFIX="$REPO_ROOT/vkfft/vkfft-$VER"

if [ ! -d "$SRC/vkfft-$VER" ]; then
    git clone --depth 1 --branch "v$VER" https://github.com/DTolm/VkFFT.git "$SRC/vkfft-$VER"
fi

rm -rf "$PREFIX"
mkdir -p "$PREFIX/include"
cp -r "$SRC/vkfft-$VER/vkFFT" "$PREFIX/include/"
cp "$SRC/vkfft-$VER/LICENSE" "$PREFIX/"

# CMake package config (find_package(VkFFT CONFIG); target VkFFT::VkFFT),
# kept in build-scripts/vkfft-cmake/. Header-only, so arch-independent.
CMAKE_PKG="$PREFIX/share/cmake/VkFFT"
mkdir -p "$CMAKE_PKG"
cp "$SCRIPT_DIR/vkfft-cmake/VkFFTConfig.cmake" "$CMAKE_PKG/"
cat > "$BLD/vkfft-version.cmake" <<'EOF'
include(CMakePackageConfigHelpers)
write_basic_package_version_file("${OUT}" VERSION "${VER}" COMPATIBILITY SameMinorVersion ARCH_INDEPENDENT)
EOF
cmake -DVER="$VER" -DOUT="$CMAKE_PKG/VkFFTConfigVersion.cmake" -P "$BLD/vkfft-version.cmake"
echo "VkFFT $VER installed to $PREFIX"
