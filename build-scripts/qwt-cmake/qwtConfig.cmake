# CMake package config for the winlibs Qwt build.
#
# Qwt upstream is qmake-only and installs no CMake files; build-qwt.sh copies
# this file (plus a generated qwtConfigVersion.cmake) into
# <prefix>/lib/cmake/qwt. Package and target names follow the common
# community convention (vcpkg's qwt port):
#
#   find_package(qwt CONFIG REQUIRED)
#   target_link_libraries(app PRIVATE qwt::qwt)          # qwt.dll  (adds QWT_DLL)
#   target_link_libraries(app PRIVATE qwt::qwt-static)   # qwt-static.a
#
# Headers are included as #include <qwt_plot.h>. Release binaries are
# qwt.dll/qwt.dll.a/qwt-static.a, debug ones carry a 'd' suffix, all in lib/.
# RelWithDebInfo/MinSizeRel use the release binaries.
#
# Qwt was built against Qt 6 (qt/6.11.2 in this repo); this config loads the
# Qt 6 modules it needs, so Qt must be findable (CMAKE_PREFIX_PATH).

include(CMakeFindDependencyMacro)
find_dependency(Qt6 COMPONENTS Core Gui Widgets Concurrent PrintSupport Svg OpenGL OpenGLWidgets)

get_filename_component(_qwt_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(qwt_INCLUDE_DIR "${_qwt_prefix}/include/qwt")
set(qwt_INCLUDE_DIRS "${qwt_INCLUDE_DIR}")

foreach(_qwt_file
        "${_qwt_prefix}/include/qwt/qwt_global.h"
        "${_qwt_prefix}/lib/qwt.dll"
        "${_qwt_prefix}/lib/qwt.dll.a"
        "${_qwt_prefix}/lib/qwt-static.a")
    if(NOT EXISTS "${_qwt_file}")
        set(qwt_FOUND FALSE)
        set(qwt_NOT_FOUND_MESSAGE "Qwt file missing: ${_qwt_file}")
        unset(_qwt_file)
        unset(_qwt_prefix)
        return()
    endif()
endforeach()
unset(_qwt_file)

set(_qwt_qt_libs
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Concurrent Qt6::PrintSupport
    Qt6::Svg Qt6::OpenGL Qt6::OpenGLWidgets)

if(NOT TARGET qwt::qwt)
    add_library(qwt::qwt SHARED IMPORTED)
    set_target_properties(qwt::qwt PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_qwt_prefix}/include/qwt"
        INTERFACE_COMPILE_DEFINITIONS "QWT_DLL"
        INTERFACE_LINK_LIBRARIES "${_qwt_qt_libs}"
        IMPORTED_IMPLIB_RELEASE "${_qwt_prefix}/lib/qwt.dll.a"
        IMPORTED_LOCATION_RELEASE "${_qwt_prefix}/lib/qwt.dll"
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
        MAP_IMPORTED_CONFIG_MINSIZEREL Release
    )
    set_property(TARGET qwt::qwt APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
    if(EXISTS "${_qwt_prefix}/lib/qwtd.dll.a")
        set_property(TARGET qwt::qwt APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
        set_target_properties(qwt::qwt PROPERTIES
            IMPORTED_IMPLIB_DEBUG "${_qwt_prefix}/lib/qwtd.dll.a"
            IMPORTED_LOCATION_DEBUG "${_qwt_prefix}/lib/qwtd.dll")
    endif()
endif()

if(NOT TARGET qwt::qwt-static)
    add_library(qwt::qwt-static STATIC IMPORTED)
    set_target_properties(qwt::qwt-static PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_qwt_prefix}/include/qwt"
        INTERFACE_LINK_LIBRARIES "${_qwt_qt_libs}"
        IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
        IMPORTED_LOCATION_RELEASE "${_qwt_prefix}/lib/qwt-static.a"
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
        MAP_IMPORTED_CONFIG_MINSIZEREL Release
    )
    set_property(TARGET qwt::qwt-static APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
    if(EXISTS "${_qwt_prefix}/lib/qwt-staticd.a")
        set_property(TARGET qwt::qwt-static APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
        set_target_properties(qwt::qwt-static PROPERTIES
            IMPORTED_LOCATION_DEBUG "${_qwt_prefix}/lib/qwt-staticd.a")
    endif()
endif()

unset(_qwt_qt_libs)
unset(_qwt_prefix)
set(qwt_FOUND TRUE)
