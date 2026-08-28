# winlibs — prebuilt Windows x64 libraries (mingw-w64)

Prebuilt C/C++ libraries for **64-bit Windows**, compiled with the
**mingw-w64** toolchain (GCC 13, posix threads, SEH exceptions). Other
projects link against these directly: each library folder contains the
usual `include/`, `lib/` (import + static libraries) and `bin/` (DLLs)
layout.

This repo recreates the layout of the old VS2017 codelibrary, updated to
Qt 6.11.2 and the latest stable / long-term-support release of every other
library.

## Contents

| Folder | Library | Version | Notes |
|---|---|---|---|
| `boost/boost-1.92.0` | Boost | 1.92.0 | shared + static, tagged layout; no python/mpi |
| `cpprestsdk/cpprestsdk-2.10.19` | C++ REST SDK | 2.10.19 | final upstream release (project archived); winhttp client, asio listener, websocketpp websockets, Boost 1.86 statically linked in |
| `eigen/eigen-3.4.1` | Eigen | 3.4.1 | header-only, 3.4 LTS branch |
| `fftw/fftw-3.3.10` | FFTW | 3.3.10 | double + single precision, SSE2/AVX/AVX2, threads |
| `flatbuffer/25.12.19` | FlatBuffers | 25.12.19 | includes Windows `flatc.exe` |
| `gpb/protobuf-36.0` | Protocol Buffers | 36.0 | static libs + `protoc.exe`, bundled Abseil |
| `libssh/libssh-0.12.2` | libssh | 0.12.2 | linked against repo OpenSSL + zlib |
| `liquid-dsp/liquid-dsp-1.8.2` | liquid-dsp | 1.8.2 | small Win32 compat shims (getrusage/timespec_get/strsep) |
| `log4cplus/log4cplus-2.2.0.1` | log4cplus | 2.2.0.1 | |
| `marble/marble-26.08.0` | Marble | 26.08.0 (KDE Gear) | Qt6 build, library only |
| `nlohmann/v3.12.0` | nlohmann/json | 3.12.0 | header-only |
| `openssl/openssl-3.5.8` | OpenSSL | 3.5.8 | 3.5 LTS line |
| `portaudio/portaudio-19.7.0` | PortAudio | v19.7.0 | WMME/DirectSound/WASAPI/WDM-KS |
| `qt/6.11.2` | Qt | 6.11.2 | qtbase, qtsvg, qtimageformats, qtserialport, qt5compat, qtshadertools, qtdeclarative (QtQuick/QML); OpenSSL linked |
| `qwt/qwt-6.2.0` | Qwt | 6.2.0 | built against Qt 6.11.2; headers in `include/qwt`; newest release available from an accessible mirror (6.3.0 is SourceForge-only) |
| `shapelib/1.6.3` | Shapelib | 1.6.3 | |
| `soapysdr/soapysdr-0.8.1` | SoapySDR | 0.8.1 | no python bindings |
| `vkfft/vkfft-1.3.4` | VkFFT | 1.3.4 | header-only |
| `volk-3.3.0` | VOLK | 3.3.0 | |
| `wt/wt-4.14.2` | Wt | 4.14.2 | HTTP connector, sqlite3 Dbo backend |
| `zlib/zlib-1.3.2` | zlib | 1.3.2 | support dependency |
| `runtime/` | mingw-w64 runtime DLLs | GCC 13 | ship next to your .exe |

## Using the libraries

- **Compiler**: link with a mingw-w64 GCC toolchain (MSYS2 MINGW64, or the
  cross toolchain). The C++ libraries use the GCC ABI — they are **not**
  link-compatible with MSVC. C libraries (openssl, fftw, zlib, portaudio,
  liquid-dsp, shapelib, ...) can be used from MSVC via their DLLs/import libs.
- **CMake**: most libraries install CMake package configs, e.g.
  `-DCMAKE_PREFIX_PATH=<repo>/qt/6.11.2;<repo>/openssl/openssl-3.5.8;...`
- **Runtime**: applications need the DLLs from the library `bin/` folders
  plus `runtime/*.dll` (`libstdc++-6.dll`, `libgcc_s_seh-1.dll`,
  `libwinpthread-1.dll`) on `PATH` or next to the executable.
- **Qt**: use `qt/6.11.2` as a normal Qt installation prefix
  (`find_package(Qt6 ...)` with `CMAKE_PREFIX_PATH`, or point Qt Creator at
  it). OpenSSL-backed TLS requires `libssl-3-x64.dll`/`libcrypto-3-x64.dll`
  from `openssl/openssl-3.5.8/bin` at run time. The QML VectorImage element
  (`quick_vectorimage`) is disabled in this build.
- **cpprestsdk**: built with the portable pplx (`winpplx`) and
  `_TURN_OFF_PLATFORM_STRING`; use `_XPLATSTR()`/`utility::string_t`
  conventions as usual — the `U()` convenience macro still works in consumer
  code that does not define `_TURN_OFF_PLATFORM_STRING`.

## Rebuilding

Every library was produced by a script in [`build-scripts/`](build-scripts/),
cross-compiled on Linux with the Ubuntu mingw-w64 package.

**One-step rebuild with Docker** (see the [`Dockerfile`](Dockerfile) header
for output-extraction commands; takes several hours, ~40 GB scratch):

```sh
docker build -t winlibs .
```

**Directly on a Debian/Ubuntu host:**

```sh
apt-get install build-essential perl python3-mako mingw-w64 mingw-w64-tools \
                cmake ninja-build make autoconf automake libtool pkg-config \
                libgl-dev libglu1-mesa-dev libxkbcommon-dev curl git unzip xz-utils
./build-scripts/build-all.sh           # everything, in dependency order
```

Individual `build-<lib>.sh` scripts can be run on their own; the only
ordering constraints are zlib/openssl before their consumers, boost before
wt/cpprestsdk, and qt-host → qt → qwt/marble.

Scripts download their own sources (GitHub/GitLab mirrors) and install into
the repo folders. `WINLIBS_WORK` controls the scratch/build directory
(default `~/winlibs-work`). The same scripts run natively on Windows under
an MSYS2 MINGW64 shell if you drop the toolchain file from the cmake calls.
