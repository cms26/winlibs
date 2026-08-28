#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "flatbuffers::flatbuffers_shared" for configuration "Release"
set_property(TARGET flatbuffers::flatbuffers_shared APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(flatbuffers::flatbuffers_shared PROPERTIES
  IMPORTED_IMPLIB_RELEASE "${_IMPORT_PREFIX}/lib/libflatbuffers.dll.a"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libflatbuffers.dll"
  )

list(APPEND _cmake_import_check_targets flatbuffers::flatbuffers_shared )
list(APPEND _cmake_import_check_files_for_flatbuffers::flatbuffers_shared "${_IMPORT_PREFIX}/lib/libflatbuffers.dll.a" "${_IMPORT_PREFIX}/lib/libflatbuffers.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
