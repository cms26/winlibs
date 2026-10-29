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
| `boost/boost-1.86.0` | Boost | 1.86.0 | legacy: last release with the classic Boost.Asio API (`io_service`, `io_service::work`, `.post()`/`.reset()`, ...) removed in 1.87; same build options and layout as 1.92.0, except `stacktrace_from_exception` (POSIX-only for GCC in 1.86) is not built |
| `cpprestsdk/cpprestsdk-2.10.19` | C++ REST SDK | 2.10.19 | final upstream release (project archived); winhttp client, asio listener, websocketpp websockets, Boost 1.86 statically linked in; `lib/` is self-contained (release+debug DLLs plus the OpenSSL/zlib DLLs) |
| `eigen/eigen-3.4.1` | Eigen | 3.4.1 | header-only, 3.4 LTS branch |
| `fftw/fftw-3.3.10` | FFTW | 3.3.10 | double + single precision, SSE2/AVX/AVX2, threads; CMake packages `FFTW3`/`FFTW3f` (targets `FFTW3::fftw3`/`FFTW3::fftw3f`, static) |
| `flatbuffer/25.12.19` | FlatBuffers | 25.12.19 | includes Windows `flatc.exe` |
| `gpb/36.0` | Protocol Buffers | 36.0 | legacy layout: `bin/` (protoc.exe + plugins), `c++/` (headers at root: google/, absl/, upb/), `c++/lib/` (static libs, bundled Abseil) |
| `libssh/libssh-0.12.2` | libssh | 0.12.2 | linked against repo OpenSSL + zlib |
| `liquid-dsp/liquid-dsp-1.8.2` | liquid-dsp | 1.8.2 | small Win32 compat shims (getrusage/timespec_get/strsep); CMake package `liquid` (targets `liquid::liquid-static`, `liquid::liquid` DLL; upstream names) |
| `log4cplus/log4cplus-2.2.0.1` | log4cplus | 2.2.0.1 | Unicode (`tchar` = `wchar_t`); target `log4cplus::log4cplusU`, adds `UNICODE`/`_UNICODE` to consumers |
| `log4cplus/log4cplus-2.2.0.1-nonunicode` | log4cplus | 2.2.0.1 | narrow (`tchar` = `char`); target `log4cplus::log4cplus`; mingw runtime (libgcc, libstdc++, winpthread) linked statically into the DLL, so no `runtime/` DLLs needed for it |
| `marble/marble-26.08.0` | Marble | 26.08.0 (KDE Gear) | Qt6 build, library only |
| `nlohmann/v3.12.0` | nlohmann/json | 3.12.0 | header-only; CMake package (`find_package(nlohmann_json CONFIG)`, target `nlohmann_json::nlohmann_json`) and pkg-config file in `share/` |
| `openssl/openssl-3.5.8` | OpenSSL | 3.5.8 | 3.5 LTS line |
| `portaudio/portaudio-19.7.0` | PortAudio | v19.7.0 | WMME/DirectSound/WASAPI/WDM-KS |
| `qt/6.11.2` | Qt | 6.11.2 | release build: qtbase, qtsvg, qtimageformats, qtserialport, qt5compat, qtshadertools, qtdeclarative (QtQuick/QML); OpenSSL linked |
| `qt/6.11.2-debug` | Qt (debug) | 6.11.2 | same module set, debug configuration (own prefix, Qt convention) |
| `qwt/6.2.0` | Qwt | 6.2.0 | built against Qt 6.11.2; `lib/` holds `qwt.dll`/`qwtd.dll` + import libs + static libs; headers in `include/qwt`; newest release available from an accessible mirror (6.3.0 is SourceForge-only); CMake package `qwt` (targets `qwt::qwt` DLL, `qwt::qwt-static`; needs `qt/6.11.2` on the prefix path) |
| `shapelib/1.6.3` | Shapelib | 1.6.3 | |
| `soapysdr/soapysdr-0.8.1` | SoapySDR | 0.8.1 | no python bindings; per-config `lib/Release` + `lib/Debug` |
| `vkfft/vkfft-1.3.4` | VkFFT | 1.3.4 | header-only; CMake package `VkFFT` (target `VkFFT::VkFFT`; set `VKFFT_BACKEND` before `find_package`, default 0 = Vulkan) |
| `volk-3.3.0` | VOLK | 3.3.0 | |
| `wt/wt-4.14.2` | Wt | 4.14.2 | HTTP connector, sqlite3 Dbo backend |
| `zlib/zlib-1.3.2` | zlib | 1.3.2 | support dependency |
| `runtime/` | mingw-w64 runtime DLLs | GCC 13 | ship next to your .exe |

## Debug builds

Every compiled library ships a debug configuration next to the release one:

- **Default**: side-by-side `d`-suffixed binaries in the same directories
  (`libz.dll`/`libzd.dll`, `libprotobuf.a`/`libprotobufd.a`,
  `qwt.dll`/`qwtd.dll`, ...). The CMake package configs carry both
  configurations, so `find_package` picks the right one per build type.
- **Boost**: native tagged names (`libboost_X-mt-x64` / `libboost_X-mt-d-x64`).
- **SoapySDR**: per-config `lib/Release/` and `lib/Debug/` with same-named files.
- **OpenSSL, liquid-dsp**: a `debug/` subtree (their build systems cannot
  produce correctly-named side-by-side debug DLLs).
- **Qt**: a separate `qt/6.11.2-debug` prefix.

Debug binaries keep their symbols (release binaries are stripped). The
smaller libraries carry full `-g` debug info; the big C++ ones (protobuf,
boost, wt, cpprestsdk, marble, Qt) are built `-Og -g1` — assertions on,
line-level stepping, symbolized backtraces — because full DWARF pushes
single files past GitHub's hard 100 MB limit. For the same reason a few
huge static debug archives (`libwtd.a`, `qwt-staticd.a`, `libQt6QmlDom.a`)
have their DWARF stripped. Rebuilding locally with full `-g` is one flag
away in the corresponding build script.

With mingw/GCC there is no MSVC-style debug/release CRT split: debug and
release binaries are ABI-compatible and can be mixed freely (e.g. a debug
application against release Qt).

## Using the libraries

- **Compiler**: link with a mingw-w64 GCC toolchain (MSYS2 MINGW64, or the
  cross toolchain). The C++ libraries use the GCC ABI — they are **not**
  link-compatible with MSVC. C libraries (openssl, fftw, zlib, portaudio,
  liquid-dsp, shapelib, ...) can be used from MSVC via their DLLs/import libs.
- **CMake**: most libraries install CMake package configs, e.g.
  `-DCMAKE_PREFIX_PATH=<repo>/qt/6.11.2;<repo>/openssl/openssl-3.5.8;...`
- **Command-line tools**: `protoc.exe` and `flatc.exe` are fully static and
  run standalone; `openssl.exe` and `SoapySDRUtil.exe` ship with the mingw
  runtime DLLs beside them.
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
