# CMake toolchain file for cross-compiling to 64-bit Windows with mingw-w64.
# Usage: cmake -DCMAKE_TOOLCHAIN_FILE=<repo>/build-scripts/toolchain-mingw64.cmake ...
# The same libraries can be built natively on Windows under MSYS2 (MINGW64
# shell) by omitting this file entirely.

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(TOOLCHAIN_PREFIX x86_64-w64-mingw32)

# Use the posix-threads variant of the Ubuntu/Debian mingw-w64 toolchain
# (required for std::thread / Qt).
find_program(MINGW_CC  NAMES ${TOOLCHAIN_PREFIX}-gcc-posix ${TOOLCHAIN_PREFIX}-gcc)
find_program(MINGW_CXX NAMES ${TOOLCHAIN_PREFIX}-g++-posix ${TOOLCHAIN_PREFIX}-g++)

set(CMAKE_C_COMPILER   ${MINGW_CC})
set(CMAKE_CXX_COMPILER ${MINGW_CXX})
set(CMAKE_RC_COMPILER  ${TOOLCHAIN_PREFIX}-windres)
set(CMAKE_AR           ${TOOLCHAIN_PREFIX}-ar)
set(CMAKE_RANLIB       ${TOOLCHAIN_PREFIX}-ranlib)

# Dependencies from this repo (openssl, zlib, boost, ...) can be exposed to
# find_package/find_library by listing their prefixes (semicolon separated)
# in the WINLIBS_FIND_ROOT environment variable.
set(CMAKE_FIND_ROOT_PATH /usr/${TOOLCHAIN_PREFIX})
if(DEFINED ENV{WINLIBS_FIND_ROOT})
    list(APPEND CMAKE_FIND_ROOT_PATH $ENV{WINLIBS_FIND_ROOT})
endif()

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
