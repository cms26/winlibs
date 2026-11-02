# CMake package config for the winlibs Linux Qwt build (same package and
# target names as the Windows one):
#
#   find_package(qwt CONFIG REQUIRED)
#   target_link_libraries(app PRIVATE qwt::qwt)          # libqwt.so
#   target_link_libraries(app PRIVATE qwt::qwt-static)   # libqwt-static.a
#
# Headers are included as #include <qwt_plot.h>. Qwt was built against the
# Qt in qt/<ver> of this tree; this config loads the Qt 6 modules it needs,
# so Qt must be findable (CMAKE_PREFIX_PATH).

include(CMakeFindDependencyMacro)
find_dependency(Qt6 COMPONENTS Core Gui Widgets Concurrent PrintSupport Svg OpenGL OpenGLWidgets)

get_filename_component(_qwt_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(qwt_INCLUDE_DIR "${_qwt_prefix}/include/qwt")
set(qwt_INCLUDE_DIRS "${qwt_INCLUDE_DIR}")

foreach(_qwt_file
        "${_qwt_prefix}/include/qwt/qwt_global.h"
        "${_qwt_prefix}/lib/libqwt.so"
        "${_qwt_prefix}/lib/libqwt-static.a")
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
    file(REAL_PATH "${_qwt_prefix}/lib/libqwt.so" _qwt_so)
    set_target_properties(qwt::qwt PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_qwt_prefix}/include/qwt"
        INTERFACE_COMPILE_DEFINITIONS "QWT_DLL"
        INTERFACE_LINK_LIBRARIES "${_qwt_qt_libs}"
        IMPORTED_LOCATION "${_qwt_so}")
    unset(_qwt_so)
endif()

if(NOT TARGET qwt::qwt-static)
    add_library(qwt::qwt-static STATIC IMPORTED)
    set_target_properties(qwt::qwt-static PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_qwt_prefix}/include/qwt"
        INTERFACE_LINK_LIBRARIES "${_qwt_qt_libs}"
        IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
        IMPORTED_LOCATION "${_qwt_prefix}/lib/libqwt-static.a")
endif()

unset(_qwt_qt_libs)
unset(_qwt_prefix)
set(qwt_FOUND TRUE)
