# CMake package config for the winlibs Linux oneMKL (mkl/mkl-<ver>).
#
#   find_package(MKL CONFIG REQUIRED)
#   target_link_libraries(mylib PUBLIC MKL::Eigen)   # Eigen using MKL
#   target_link_libraries(mylib PUBLIC MKL::MKL)     # MKL only (BLAS, LAPACK, FFT, VML, ...)
#
# MKL::MKL     MKL headers and libraries. Defaults: ILP64 interface
#              (MKL_ILP64: 64-bit MKL_INT), GNU OpenMP threading (libgomp;
#              consumers get -fopenmp through OpenMP::OpenMP_CXX/_C), static
#              linking (self-contained: nothing from MKL to deploy).
# MKL::Eigen   MKL::MKL + Eigen3::Eigen + EIGEN_USE_MKL_ALL: Eigen's
#              products, decompositions and vectorized math run through MKL
#              (BLAS, LAPACKE, VML). Eigen is found from CMAKE_PREFIX_PATH or
#              the eigen/ folder next to this MKL.
#
# Options, set before find_package (same names and values as Intel's own
# MKLConfig.cmake):
#   MKL_INTERFACE   ilp64 (default) | lp64
#   MKL_THREADING   gnu_thread (default) | sequential
#   MKL_LINK        static (default) | dynamic
#
# With MKL_LINK=dynamic the application needs libmkl_*.so.3 at run time,
# including the CPU-specific kernels MKL loads itself (libmkl_avx2.so.3, ...),
# which deployment tools don't see: install all of MKL_RUNTIME_LIBRARIES next
# to the application, e.g.
#   install(FILES ${MKL_RUNTIME_LIBRARIES} DESTINATION ${CMAKE_INSTALL_LIBDIR})
#
# Not part of this package (it is the application's choice, not MKL's):
# libstdc++'s parallel mode, -D_GLIBCXX_PARALLEL.

cmake_minimum_required(VERSION 3.16)

get_filename_component(_mkl_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

if(NOT DEFINED MKL_INTERFACE)
    set(MKL_INTERFACE ilp64)
endif()
if(NOT DEFINED MKL_THREADING)
    set(MKL_THREADING gnu_thread)
endif()
if(NOT DEFINED MKL_LINK)
    set(MKL_LINK static)
endif()

macro(_mkl_fail msg)
    set(MKL_FOUND FALSE)
    set(MKL_NOT_FOUND_MESSAGE "${msg}")
    unset(_mkl_prefix)
    return()
endmacro()

if(NOT MKL_INTERFACE MATCHES "^(ilp64|lp64)$")
    _mkl_fail("MKL_INTERFACE must be ilp64 or lp64 (is '${MKL_INTERFACE}')")
endif()
if(NOT MKL_THREADING MATCHES "^(gnu_thread|sequential)$")
    _mkl_fail("MKL_THREADING must be gnu_thread or sequential in this build (is '${MKL_THREADING}')")
endif()
if(NOT MKL_LINK MATCHES "^(static|dynamic)$")
    _mkl_fail("MKL_LINK must be static or dynamic (is '${MKL_LINK}')")
endif()

set(MKL_ROOT "${_mkl_prefix}")
set(MKL_INCLUDE_DIR "${_mkl_prefix}/include")
if(MKL_LINK STREQUAL "static")
    set(_mkl_ext ".a")
else()
    set(_mkl_ext ".so")
endif()
set(_mkl_libs
    "${_mkl_prefix}/lib/libmkl_intel_${MKL_INTERFACE}${_mkl_ext}"
    "${_mkl_prefix}/lib/libmkl_${MKL_THREADING}${_mkl_ext}"
    "${_mkl_prefix}/lib/libmkl_core${_mkl_ext}")
foreach(_mkl_file "${MKL_INCLUDE_DIR}/mkl.h" ${_mkl_libs})
    if(NOT EXISTS "${_mkl_file}")
        _mkl_fail("oneMKL file missing: ${_mkl_file}")
    endif()
endforeach()
file(GLOB MKL_RUNTIME_LIBRARIES "${_mkl_prefix}/lib/libmkl_*.so.[0-9]*")

include(CMakeFindDependencyMacro)
find_dependency(Threads)
set(_mkl_deps Threads::Threads m dl)
if(MKL_THREADING STREQUAL "gnu_thread")
    # GNU OpenMP for the languages the project uses (-fopenmp, libgomp)
    get_property(_mkl_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
    set(_mkl_omp_components)
    foreach(_mkl_lang C CXX)
        if(_mkl_lang IN_LIST _mkl_languages)
            list(APPEND _mkl_omp_components ${_mkl_lang})
        endif()
    endforeach()
    find_dependency(OpenMP COMPONENTS ${_mkl_omp_components})
    if(TARGET OpenMP::OpenMP_CXX)
        list(PREPEND _mkl_deps OpenMP::OpenMP_CXX)
    elseif(TARGET OpenMP::OpenMP_C)
        list(PREPEND _mkl_deps OpenMP::OpenMP_C)
    else()
        _mkl_fail("MKL_THREADING=gnu_thread needs OpenMP (C or C++ must be an enabled language)")
    endif()
endif()

if(NOT TARGET MKL::MKL)
    add_library(MKL::MKL INTERFACE IMPORTED)
    set_target_properties(MKL::MKL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${MKL_INCLUDE_DIR}")
    if(MKL_INTERFACE STREQUAL "ilp64")
        set_property(TARGET MKL::MKL PROPERTY INTERFACE_COMPILE_DEFINITIONS MKL_ILP64)
    endif()
    if(MKL_LINK STREQUAL "static")
        # The three archives reference each other: link them as a group.
        if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.24)
            list(JOIN _mkl_libs "," _mkl_group)
            set_property(TARGET MKL::MKL PROPERTY INTERFACE_LINK_LIBRARIES
                "$<LINK_GROUP:RESCAN,${_mkl_group}>" ${_mkl_deps})
            unset(_mkl_group)
        else()
            set_property(TARGET MKL::MKL PROPERTY INTERFACE_LINK_LIBRARIES
                "-Wl,--start-group" ${_mkl_libs} "-Wl,--end-group" ${_mkl_deps})
        endif()
    else()
        # --no-as-needed: libmkl_core is only referenced through the others
        # (some distributions' compilers default to --as-needed).
        set_property(TARGET MKL::MKL PROPERTY INTERFACE_LINK_LIBRARIES
            "-Wl,--no-as-needed" ${_mkl_libs} ${_mkl_deps})
    endif()
endif()

# Eigen with MKL
if(NOT TARGET Eigen3::Eigen)
    file(GLOB _mkl_eigen_dirs "${_mkl_prefix}/../../eigen/eigen-*/share/eigen3/cmake")
    list(SORT _mkl_eigen_dirs COMPARE NATURAL ORDER DESCENDING)
    find_package(Eigen3 CONFIG QUIET HINTS ${_mkl_eigen_dirs})
endif()
if(TARGET Eigen3::Eigen AND NOT TARGET MKL::Eigen)
    add_library(MKL::Eigen INTERFACE IMPORTED)
    set_target_properties(MKL::Eigen PROPERTIES
        INTERFACE_COMPILE_DEFINITIONS EIGEN_USE_MKL_ALL
        INTERFACE_LINK_LIBRARIES "Eigen3::Eigen;MKL::MKL")
endif()

unset(_mkl_libs)
unset(_mkl_deps)
unset(_mkl_ext)
unset(_mkl_file)
unset(_mkl_prefix)
unset(_mkl_eigen_dirs)
set(MKL_FOUND TRUE)
