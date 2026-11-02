# CMake package config for the winlibs Linux liquid-dsp build (same package
# and target names as the Windows one and upstream):
#
#   find_package(liquid CONFIG REQUIRED)
#   target_link_libraries(app PRIVATE liquid::liquid-static)  # libliquid.a
#   target_link_libraries(app PRIVATE liquid::liquid)         # libliquid.so
#
# Runs on any x86-64 CPU (SSE/AVX kernels chosen at run time).
#
# liquid is linked against FFTW (single precision, static). libliquid.so
# contains it; liquid::liquid-static needs FFTW3::fftw3f, which this config
# loads from the FFTW3f package (put fftw/fftw-3.3.10 on CMAKE_PREFIX_PATH;
# the sibling folder of this install is also tried).
#
# C++ users: #include <complex> before <liquid/liquid.h> so that
# liquid_float_complex is std::complex<float>.

get_filename_component(_liquid_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(liquid_INCLUDE_DIR "${_liquid_prefix}/include")
set(liquid_INCLUDE_DIRS "${liquid_INCLUDE_DIR}")

foreach(_liquid_file
        "${_liquid_prefix}/include/liquid/liquid.h"
        "${_liquid_prefix}/lib/libliquid.a"
        "${_liquid_prefix}/lib/libliquid.so")
    if(NOT EXISTS "${_liquid_file}")
        set(liquid_FOUND FALSE)
        set(liquid_NOT_FOUND_MESSAGE "liquid-dsp file missing: ${_liquid_file}")
        unset(_liquid_file)
        unset(_liquid_prefix)
        return()
    endif()
endforeach()
unset(_liquid_file)

include(CMakeFindDependencyMacro)
find_dependency(Threads)
if(NOT TARGET FFTW3::fftw3f)
    find_package(FFTW3f CONFIG QUIET
        HINTS "${_liquid_prefix}/../../fftw/fftw-3.3.10/lib/cmake/fftw3f")
endif()
set(_liquid_static_deps Threads::Threads m)
if(TARGET FFTW3::fftw3f)
    list(PREPEND _liquid_static_deps FFTW3::fftw3f)
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
        IMPORTED_LOCATION "${_liquid_prefix}/lib/libliquid.a")
endif()

if(NOT TARGET liquid::liquid)
    add_library(liquid::liquid SHARED IMPORTED)
    file(REAL_PATH "${_liquid_prefix}/lib/libliquid.so" _liquid_so)
    set_target_properties(liquid::liquid PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_liquid_prefix}/include"
        IMPORTED_LOCATION "${_liquid_so}")
    unset(_liquid_so)
endif()

unset(_liquid_static_deps)
unset(_liquid_prefix)
set(liquid_FOUND TRUE)
