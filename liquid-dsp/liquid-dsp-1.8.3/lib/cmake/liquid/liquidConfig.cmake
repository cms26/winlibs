# CMake package config for the winlibs liquid-dsp build.
#
# build-liquid-dsp.sh installs this file (plus a generated
# liquidConfigVersion.cmake) into <prefix>/lib/cmake/liquid, replacing
# upstream's own config, which knows neither the debug/ layout nor the
# static FFTW dependency. Package and target names are upstream's:
#
#   find_package(liquid CONFIG REQUIRED)
#   target_link_libraries(app PRIVATE liquid::liquid-static)  # static lib
#   target_link_libraries(app PRIVATE liquid::liquid)         # DLL
#
# Runs on any x86-64 CPU (SSE/AVX kernels chosen at run time).
#
# liquid is linked against FFTW (single precision, static). The DLL contains
# it; liquid::liquid-static needs FFTW3::fftw3f, which this config loads from
# the FFTW3f package (put fftw/fftw-3.3.10 on CMAKE_PREFIX_PATH; the winlibs
# sibling folder is also tried).
#
# Release binaries are in <prefix>/{lib,bin}, debug ones in
# <prefix>/debug/{lib,bin} (same file names). Both targets carry both
# configurations; RelWithDebInfo/MinSizeRel use the release binaries.
#
# C++ users: #include <complex> before <liquid/liquid.h> so that
# liquid_float_complex is std::complex<float>.

get_filename_component(_liquid_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(liquid_INCLUDE_DIR "${_liquid_prefix}/include")
set(liquid_INCLUDE_DIRS "${liquid_INCLUDE_DIR}")

foreach(_liquid_file
        "${_liquid_prefix}/include/liquid/liquid.h"
        "${_liquid_prefix}/lib/libliquid.a"
        "${_liquid_prefix}/lib/libliquid.dll.a"
        "${_liquid_prefix}/bin/libliquid.dll")
    if(NOT EXISTS "${_liquid_file}")
        set(liquid_FOUND FALSE)
        set(liquid_NOT_FOUND_MESSAGE "liquid-dsp file missing: ${_liquid_file}")
        unset(_liquid_file)
        unset(_liquid_prefix)
        return()
    endif()
endforeach()
unset(_liquid_file)

# Dependencies of the static library: FFTW (single precision) and threads.
include(CMakeFindDependencyMacro)
find_dependency(Threads)
if(NOT TARGET FFTW3::fftw3f)
    find_package(FFTW3f CONFIG QUIET
        HINTS "${_liquid_prefix}/../../fftw/fftw-3.3.10/lib/cmake/fftw3f")
endif()
set(_liquid_static_deps Threads::Threads)
if(TARGET FFTW3::fftw3f)
    list(APPEND _liquid_static_deps FFTW3::fftw3f)
else()
    message(WARNING "liquid: FFTW3f package not found; liquid::liquid-static will "
                    "fail to link (undefined fftwf_*). Add fftw/fftw-3.3.10 to CMAKE_PREFIX_PATH.")
endif()

if(NOT TARGET liquid::liquid-static)
    add_library(liquid::liquid-static STATIC IMPORTED)
    set_target_properties(liquid::liquid-static PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_liquid_prefix}/include"
        INTERFACE_LINK_LIBRARIES "${_liquid_static_deps}"
        IMPORTED_LINK_INTERFACE_LANGUAGES "C"
        IMPORTED_LOCATION_RELEASE "${_liquid_prefix}/lib/libliquid.a"
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
        MAP_IMPORTED_CONFIG_MINSIZEREL Release
    )
    set_property(TARGET liquid::liquid-static APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
    if(EXISTS "${_liquid_prefix}/debug/lib/libliquid.a")
        set_property(TARGET liquid::liquid-static APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
        set_target_properties(liquid::liquid-static PROPERTIES
            IMPORTED_LOCATION_DEBUG "${_liquid_prefix}/debug/lib/libliquid.a")
    endif()
endif()

if(NOT TARGET liquid::liquid)
    add_library(liquid::liquid SHARED IMPORTED)
    set_target_properties(liquid::liquid PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_liquid_prefix}/include"
        IMPORTED_IMPLIB_RELEASE "${_liquid_prefix}/lib/libliquid.dll.a"
        IMPORTED_LOCATION_RELEASE "${_liquid_prefix}/bin/libliquid.dll"
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
        MAP_IMPORTED_CONFIG_MINSIZEREL Release
    )
    set_property(TARGET liquid::liquid APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
    if(EXISTS "${_liquid_prefix}/debug/lib/libliquid.dll.a")
        set_property(TARGET liquid::liquid APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
        set_target_properties(liquid::liquid PROPERTIES
            IMPORTED_IMPLIB_DEBUG "${_liquid_prefix}/debug/lib/libliquid.dll.a"
            IMPORTED_LOCATION_DEBUG "${_liquid_prefix}/debug/bin/libliquid.dll")
    endif()
endif()

unset(_liquid_static_deps)
unset(_liquid_prefix)
set(liquid_FOUND TRUE)
