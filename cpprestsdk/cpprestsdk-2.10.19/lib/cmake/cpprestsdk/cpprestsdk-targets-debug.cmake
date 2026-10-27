#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "cpprestsdk::cpprest" for configuration "Debug"
set_property(TARGET cpprestsdk::cpprest APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(cpprestsdk::cpprest PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/lib/libcpprest_2_10d.dll.a"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libcpprest_2_10d.dll"
  )

list(APPEND _cmake_import_check_targets cpprestsdk::cpprest )
list(APPEND _cmake_import_check_files_for_cpprestsdk::cpprest "${_IMPORT_PREFIX}/lib/libcpprest_2_10d.dll.a" "${_IMPORT_PREFIX}/lib/libcpprest_2_10d.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
