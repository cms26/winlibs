#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "Marble" for configuration "Debug"
set_property(TARGET Marble APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(Marble PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/lib/libmarblewidget-qt6d.dll.a"
  IMPORTED_LINK_DEPENDENT_LIBRARIES_DEBUG "Astro;Qt6::Core;Qt6::Svg;Qt6::PrintSupport;Qt6::Concurrent"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/./libmarblewidget-qt6d.dll"
  )

list(APPEND _cmake_import_check_targets Marble )
list(APPEND _cmake_import_check_files_for_Marble "${_IMPORT_PREFIX}/lib/libmarblewidget-qt6d.dll.a" "${_IMPORT_PREFIX}/./libmarblewidget-qt6d.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
