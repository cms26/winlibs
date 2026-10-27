#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "log4cplus::log4cplusU" for configuration "Debug"
set_property(TARGET log4cplus::log4cplusU APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(log4cplus::log4cplusU PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/lib/liblog4cplusUD.dll.a"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/bin/liblog4cplusUD.dll"
  )

list(APPEND _cmake_import_check_targets log4cplus::log4cplusU )
list(APPEND _cmake_import_check_files_for_log4cplus::log4cplusU "${_IMPORT_PREFIX}/lib/liblog4cplusUD.dll.a" "${_IMPORT_PREFIX}/bin/liblog4cplusUD.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
