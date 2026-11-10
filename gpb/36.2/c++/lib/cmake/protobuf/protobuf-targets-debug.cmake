#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "protobuf::libprotobuf-lite" for configuration "Debug"
set_property(TARGET protobuf::libprotobuf-lite APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(protobuf::libprotobuf-lite PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libprotobuf-lited.a"
  )

list(APPEND _cmake_import_check_targets protobuf::libprotobuf-lite )
list(APPEND _cmake_import_check_files_for_protobuf::libprotobuf-lite "${_IMPORT_PREFIX}/lib/libprotobuf-lited.a" )

# Import target "protobuf::libprotobuf" for configuration "Debug"
set_property(TARGET protobuf::libprotobuf APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(protobuf::libprotobuf PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libprotobufd.a"
  )

list(APPEND _cmake_import_check_targets protobuf::libprotobuf )
list(APPEND _cmake_import_check_files_for_protobuf::libprotobuf "${_IMPORT_PREFIX}/lib/libprotobufd.a" )

# Import target "protobuf::libupb" for configuration "Debug"
set_property(TARGET protobuf::libupb APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(protobuf::libupb PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "C"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libupbd.a"
  )

list(APPEND _cmake_import_check_targets protobuf::libupb )
list(APPEND _cmake_import_check_files_for_protobuf::libupb "${_IMPORT_PREFIX}/lib/libupbd.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
