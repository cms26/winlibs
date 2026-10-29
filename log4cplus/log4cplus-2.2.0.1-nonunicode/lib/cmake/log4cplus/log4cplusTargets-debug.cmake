#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "log4cplus::log4cplus" for configuration "Debug"
set_property(TARGET log4cplus::log4cplus APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(log4cplus::log4cplus PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/lib/liblog4cplusD.dll.a"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/bin/liblog4cplusD.dll"
  )

list(APPEND _cmake_import_check_targets log4cplus::log4cplus )
list(APPEND _cmake_import_check_files_for_log4cplus::log4cplus "${_IMPORT_PREFIX}/lib/liblog4cplusD.dll.a" "${_IMPORT_PREFIX}/bin/liblog4cplusD.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
