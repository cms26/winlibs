# CMake package config for the winlibs VkFFT install (header-only).
#
# Upstream VkFFT installs no CMake files; build-vkfft.sh copies this file
# (plus a generated VkFFTConfigVersion.cmake) into
# <prefix>/share/cmake/VkFFT. Mirrors upstream's in-tree `VkFFT` INTERFACE
# target (include dir + VKFFT_BACKEND define):
#
#   set(VKFFT_BACKEND 3)                  # before find_package; see below
#   find_package(VkFFT CONFIG REQUIRED)
#   target_link_libraries(app PRIVATE VkFFT::VkFFT OpenCL::OpenCL)
#
# VKFFT_BACKEND: 0 Vulkan (default, as upstream), 1 CUDA, 2 HIP, 3 OpenCL,
# 4 Level Zero, 5 Metal. The backend's own SDK is not part of this package:
# link it yourself (e.g. Vulkan::Vulkan + glslang for 0, OpenCL::OpenCL for 3).
#
# Both #include <vkFFT.h> (upstream style) and #include <vkFFT/vkFFT.h> work.

get_filename_component(_vkfft_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

if(NOT EXISTS "${_vkfft_prefix}/include/vkFFT/vkFFT.h")
    set(VkFFT_FOUND FALSE)
    set(VkFFT_NOT_FOUND_MESSAGE "VkFFT header missing: ${_vkfft_prefix}/include/vkFFT/vkFFT.h")
    unset(_vkfft_prefix)
    return()
endif()

# Only create the cache default when nothing set it: before CMake policy
# CMP0126 (3.21), set(CACHE) would hide a normal set(VKFFT_BACKEND 3).
if(NOT DEFINED VKFFT_BACKEND)
    set(VKFFT_BACKEND 0 CACHE STRING "VkFFT backend: 0 Vulkan, 1 CUDA, 2 HIP, 3 OpenCL, 4 Level Zero, 5 Metal")
endif()

set(VkFFT_INCLUDE_DIRS "${_vkfft_prefix}/include/vkFFT;${_vkfft_prefix}/include")

if(NOT TARGET VkFFT::VkFFT)
    add_library(VkFFT::VkFFT INTERFACE IMPORTED)
    set_target_properties(VkFFT::VkFFT PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VkFFT_INCLUDE_DIRS}"
        INTERFACE_COMPILE_DEFINITIONS "VKFFT_BACKEND=${VKFFT_BACKEND}"
    )
endif()

unset(_vkfft_prefix)
set(VkFFT_FOUND TRUE)
