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
echo "VkFFT $VER installed to $PREFIX"
