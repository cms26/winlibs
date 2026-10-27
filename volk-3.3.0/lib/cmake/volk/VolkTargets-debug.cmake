#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "Volk::volk" for configuration "Debug"
set_property(TARGET Volk::volk APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(Volk::volk PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/lib/libvolkd.dll.a"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/bin/libvolkd.dll"
  )

list(APPEND _cmake_import_check_targets Volk::volk )
list(APPEND _cmake_import_check_files_for_Volk::volk "${_IMPORT_PREFIX}/lib/libvolkd.dll.a" "${_IMPORT_PREFIX}/bin/libvolkd.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
