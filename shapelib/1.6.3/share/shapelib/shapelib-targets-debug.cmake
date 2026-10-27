#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "shapelib::shp" for configuration "Debug"
set_property(TARGET shapelib::shp APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(shapelib::shp PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/lib/libshpd.dll.a"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/bin/libshpd.dll"
  )

list(APPEND _cmake_import_check_targets shapelib::shp )
list(APPEND _cmake_import_check_files_for_shapelib::shp "${_IMPORT_PREFIX}/lib/libshpd.dll.a" "${_IMPORT_PREFIX}/bin/libshpd.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
