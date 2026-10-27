#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "flatbuffers::flatbuffers_shared" for configuration "Debug"
set_property(TARGET flatbuffers::flatbuffers_shared APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(flatbuffers::flatbuffers_shared PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/lib/libflatbuffersd.dll.a"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libflatbuffersd.dll"
  )

list(APPEND _cmake_import_check_targets flatbuffers::flatbuffers_shared )
list(APPEND _cmake_import_check_files_for_flatbuffers::flatbuffers_shared "${_IMPORT_PREFIX}/lib/libflatbuffersd.dll.a" "${_IMPORT_PREFIX}/lib/libflatbuffersd.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
