#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "Astro" for configuration "Debug"
set_property(TARGET Astro APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(Astro PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/lib/libastrod.dll.a"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/./libastrod.dll"
  )

list(APPEND _cmake_import_check_targets Astro )
list(APPEND _cmake_import_check_files_for_Astro "${_IMPORT_PREFIX}/lib/libastrod.dll.a" "${_IMPORT_PREFIX}/./libastrod.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
