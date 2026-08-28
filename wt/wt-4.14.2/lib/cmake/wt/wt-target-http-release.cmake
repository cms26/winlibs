#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "Wt::HTTP" for configuration "Release"
set_property(TARGET Wt::HTTP APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(Wt::HTTP PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libwthttp.a"
  )

list(APPEND _cmake_import_check_targets Wt::HTTP )
list(APPEND _cmake_import_check_files_for_Wt::HTTP "${_IMPORT_PREFIX}/lib/libwthttp.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
