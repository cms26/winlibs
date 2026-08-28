#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "Wt::DboSqlite3" for configuration "Release"
set_property(TARGET Wt::DboSqlite3 APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(Wt::DboSqlite3 PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "C;CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libwtdbosqlite3.a"
  )

list(APPEND _cmake_import_check_targets Wt::DboSqlite3 )
list(APPEND _cmake_import_check_files_for_Wt::DboSqlite3 "${_IMPORT_PREFIX}/lib/libwtdbosqlite3.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
