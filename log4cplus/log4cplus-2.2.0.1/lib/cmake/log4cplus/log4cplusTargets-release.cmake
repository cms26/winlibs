#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "log4cplus::log4cplusU" for configuration "Release"
set_property(TARGET log4cplus::log4cplusU APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(log4cplus::log4cplusU PROPERTIES
  IMPORTED_IMPLIB_RELEASE "${_IMPORT_PREFIX}/lib/liblog4cplusU.dll.a"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/liblog4cplusU.dll"
  )

list(APPEND _cmake_import_check_targets log4cplus::log4cplusU )
list(APPEND _cmake_import_check_files_for_log4cplus::log4cplusU "${_IMPORT_PREFIX}/lib/liblog4cplusU.dll.a" "${_IMPORT_PREFIX}/bin/liblog4cplusU.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
