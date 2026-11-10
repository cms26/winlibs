# winlibs — prebuilt Windows x64 libraries (mingw-w64)

Prebuilt C/C++ libraries for **64-bit Windows**, compiled with the
**mingw-w64** toolchain (GCC 13, posix threads, SEH exceptions). Other
projects link against these directly: each library folder contains the
usual `include/`, `lib/` (import + static libraries) and `bin/` (DLLs)
layout.

This repo recreates the layout of the old VS2017 codelibrary, updated to
the latest stable / long-term-support release of every library.

**Qt is not included:** applications use the installed Qt (official
MinGW 64-bit build, 6.11 or newer). Qwt and Marble here are built against
Qt 6.11.2 and work with any newer Qt 6 at run time.

**Linux:** the same libraries for Linux x86-64 (built on Rocky Linux 8 so
the results run on RHEL 8+, Ubuntu 20.04+, Debian 10+ and other glibc 2.28+
distributions) are built as a Docker image, see [`linux/`](linux/README.md).

## Contents

| Folder | Library | Version | Notes |
|---|---|---|---|
| `boost/boost-1.92.0` | Boost | 1.92.0 | shared + static, tagged layout; no python/mpi |
| `boost/boost-1.86.0` | Boost | 1.86.0 | legacy: last release with the classic Boost.Asio API (`io_service`, `io_service::work`, `.post()`/`.reset()`, ...) removed in 1.87; same build options and layout as 1.92.0, except `stacktrace_from_exception` (POSIX-only for GCC in 1.86) is not built |
| `cpprestsdk/cpprestsdk-2.10.19` | C++ REST SDK | 2.10.19 | final upstream release (project archived); winhttp client, asio listener, websocketpp websockets, Boost 1.86 statically linked in; `lib/` is self-contained (release+debug DLLs plus the OpenSSL/zlib DLLs) |
| `eigen/eigen-3.4.1` | Eigen | 3.4.1 | header-only, 3.4 LTS branch |
| `fftw/fftw-3.3.10` | FFTW | 3.3.10 | double + single precision, SSE2/AVX/AVX2(+FMA) codelets chosen at run time (runs on any x86-64 CPU; FFTW's CMake build is patched to apply SIMD flags only to the SIMD codelets), threads; CMake packages `FFTW3`/`FFTW3f` (targets `FFTW3::fftw3`/`FFTW3::fftw3f`, static; Release and Debug configurations) |
| `flatbuffer/25.12.19` | FlatBuffers | 25.12.19 | includes Windows `flatc.exe` |
| `gpb/36.0` | Protocol Buffers | 36.0 | legacy layout: `bin/` (protoc.exe + plugins), `c++/` (headers at root: google/, absl/, upb/), `c++/lib/` (static libs, bundled Abseil) |
| `libssh/libssh-0.12.2` | libssh | 0.12.2 | linked against repo OpenSSL + zlib |
| `liquid-dsp/liquid-dsp-1.8.2` | liquid-dsp | 1.8.2 | **runs on any x86-64 CPU**: SSE/AVX dot-product kernels chosen at run time (portable loop below 16 taps); linked with FFTW (static) for spgram/fftfilt/channelizers/OFDM, planner made thread-safe; small Win32 compat shims; CMake package `liquid` (targets `liquid::liquid-static`, `liquid::liquid` DLL; upstream names) |
| `log4cplus/log4cplus-2.2.0.1` | log4cplus | 2.2.0.1 | Unicode (`tchar` = `wchar_t`); target `log4cplus::log4cplusU`, adds `UNICODE`/`_UNICODE` to consumers |
| `log4cplus/log4cplus-2.2.0.1-nonunicode` | log4cplus | 2.2.0.1 | narrow (`tchar` = `char`); target `log4cplus::log4cplus`; mingw runtime (libgcc, libstdc++, winpthread) linked statically into the DLL, so no `runtime/` DLLs needed for it |
| `mariadb-connector-c/mariadb-connector-c-3.4.11` | MariaDB Connector/C | 3.4.11 | MySQL client library for Qt's MySQL driver (`QMYSQL`; build the driver with `windows/build-qt-mysql-driver.ps1`, see below). LGPL 2.1; TLS via Windows Schannel (no OpenSSL DLLs); MySQL 8/9 logins (`caching_sha2_password`) built in; mingw runtime linked statically: `bin/libmariadb.dll` needs only Windows DLLs |
| `marble/marble-26.08.0` | Marble | 26.08.0 (KDE Gear) | Qt6 build, library only |
| `nlohmann/v3.12.0` | nlohmann/json | 3.12.0 | header-only; CMake package (`find_package(nlohmann_json CONFIG)`, target `nlohmann_json::nlohmann_json`) and pkg-config file in `share/` |
| `openssl/openssl-3.5.9` | OpenSSL | 3.5.9 | 3.5 LTS line |
| `portaudio/portaudio-19.7.0` | PortAudio | v19.7.0 | WMME/DirectSound/WASAPI/WDM-KS |
| `qwt/6.3.0` | Qwt | 6.3.0 | built against Qt 6.11.2 (runs with any installed Qt 6.11+); `lib/` holds `qwt.dll`/`qwtd.dll` + import libs + static libs; headers in `include/qwt`; the official release tarball (from Ubuntu's archive, which carries SourceForge's file unmodified; checksum-pinned). Over 6.2.0 it fixes filled curves with a curve fitter drawing nothing and blurry legend icons, spectrograms and rubber bands on high-DPI screens. CMake package `qwt` (targets `qwt::qwt` DLL, `qwt::qwt-static`; needs your installed Qt on the prefix path). Upgrading from 6.2.0: change `qwt/6.2.0` to `qwt/6.3.0` in your prefix paths; the API is the same except `QwtPlotOpenGLCanvas(int numSamples, QwtPlot*)` replacing the `QSurfaceFormat` constructor, and `QwtPointSeriesData`, `QwtPoint3DSeriesData` and `QwtIntervalSeriesData` being typedefs now (a forward declaration `class QwtPointSeriesData;` must become `#include <qwt_series_data.h>`) |
| `shapelib/1.6.3` | Shapelib | 1.6.3 | |
| `soapysdr/soapysdr-0.8.1` | SoapySDR | 0.8.1 | no python bindings; per-config `lib/Release` + `lib/Debug` |
| `vkfft/vkfft-1.3.4` | VkFFT | 1.3.4 | header-only; CMake package `VkFFT` (target `VkFFT::VkFFT`; set `VKFFT_BACKEND` before `find_package`, default 0 = Vulkan) |
| `volk-3.3.0` | VOLK | 3.3.0 | |
| `wt/wt-4.14.2` | Wt | 4.14.2 | HTTP connector, sqlite3 Dbo backend |
| `zlib/zlib-1.4` | zlib | 1.4 | support dependency |
| `runtime/` | mingw-w64 runtime DLLs | GCC 13 | ship next to your .exe |
| `tools/llvm-23.1.4` | clang-format, clang-tidy | LLVM 23.1.4 | developer tools, not libraries: official LLVM Windows binaries, static (no VC runtime); also `clang-apply-replacements`, `git-clang-format`, `run-clang-tidy` and clang's builtin headers for clang-tidy. Work with any compiler, including the MinGW/GCC toolchain |

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

Debug binaries keep their symbols (release binaries are stripped). The
smaller libraries carry full `-g` debug info; the big C++ ones (protobuf,
boost, wt, cpprestsdk, marble) are built `-Og -g1` — assertions on,
line-level stepping, symbolized backtraces — because full DWARF pushes
single files past GitHub's hard 100 MB limit. For the same reason a few
huge static debug archives (`libwtd.a`, `qwt-staticd.a`)
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
  `-DCMAKE_PREFIX_PATH=C:/Qt/6.12.0/mingw_64;<repo>/openssl/openssl-3.5.9;...`
- **Command-line tools**: `protoc.exe` and `flatc.exe` are fully static and
  run standalone; `openssl.exe` and `SoapySDRUtil.exe` ship with the mingw
  runtime DLLs beside them.
- **Runtime**: applications need the DLLs from the library `bin/` folders
  plus `runtime/*.dll` (`libstdc++-6.dll`, `libgcc_s_seh-1.dll`,
  `libwinpthread-1.dll`) on `PATH` or next to the executable.
- **Qt**: not in this repo; use the installed Qt (MinGW 64-bit) on
  `CMAKE_PREFIX_PATH`. Qwt and Marble need it there too.
- **MySQL (Qt's `QMYSQL` driver)**: the Qt installer doesn't include it,
  and a driver only works with the exact Qt version it was built for. Run
  once per Qt version you install (Qt's MinGW, CMake and Ninja from the Qt
  installer are used):

  ```powershell
  powershell -ExecutionPolicy Bypass -File windows\build-qt-mysql-driver.ps1
  ```

  It finds Qt (`-QtDir`, else `QT_DIR`, else the newest
  `C:\Qt\6.*\mingw_64`), builds `qsqlmysql.dll` against this repo's MariaDB
  Connector/C (source from Qt's "Sources" component, or downloaded with git),
  installs it into Qt's `plugins\sqldrivers`, copies `libmariadb.dll` into
  Qt's `bin\`, and runs a check program (`-TestConnection
  host:port:user:password` also connects to a server, TLS required). Then
  `QSqlDatabase::addDatabase("QMYSQL")` works. When deploying, ship
  `libmariadb.dll` yourself (Qt's deployment copies the driver but not its
  DLL), e.g.
  `install(FILES "$<TARGET_FILE_DIR:Qt6::Core>/libmariadb.dll" DESTINATION ${CMAKE_INSTALL_BINDIR})`.
  MariaDB Connector/C rather than MySQL's `libmysqlclient`: LGPL instead of
  GPL v2 / Oracle's commercial license, same Qt code. Tested: the script
  built the driver for Qt 6.12.0, which connected to MySQL Server 9.7.4 over
  TLS with `caching_sha2_password`.
- **cpprestsdk**: built with the portable pplx (`winpplx`) and
  `_TURN_OFF_PLATFORM_STRING`; use `_XPLATSTR()`/`utility::string_t`
  conventions as usual — the `U()` convenience macro still works in consumer
  code that does not define `_TURN_OFF_PLATFORM_STRING`.
- **clang-format / clang-tidy** (`tools/llvm-23.1.4/bin`): run them directly,
  put the folder on `PATH`, or point CMake at them, e.g.
  `find_program(CLANG_FORMAT_EXE clang-format HINTS <repo>/tools/llvm-23.1.4/bin NO_DEFAULT_PATH)`.
  `clang-tidy` finds its builtin headers in `../lib/clang/23/include`; give it
  your build's `compile_commands.json` (`CMAKE_EXPORT_COMPILE_COMMANDS ON`) so
  it sees the MinGW headers. `git-clang-format` / `run-clang-tidy` are Python
  scripts. Note: `BasedOnStyle` must be a built-in style (LLVM, Google,
  Chromium, Mozilla, WebKit, Microsoft, GNU); Qt's own style is WebKit-based.

## Rebuilding

Every library was produced by a script in [`build-scripts/`](build-scripts/),
cross-compiled on Linux with the Ubuntu mingw-w64 package.

**One-step rebuild with Docker.** Both Dockerfiles are run from the
repository root; each has a `.dockerignore` next to it, so only the build
scripts are sent to Docker, not the committed binaries:

| Dockerfile | Builds |
|---|---|
| [`windows/Dockerfile`](windows/Dockerfile) | these Windows libraries (MinGW cross build on Ubuntu; several hours, ~40 GB scratch) |
| [`linux/Dockerfile`](linux/Dockerfile) | the same libraries for Linux, as a Rocky 8 build image (see [`linux/README.md`](linux/README.md)) |

```sh
# Windows: results straight into a folder (or `type=tar,dest=-` for a tarball)
docker build -f windows/Dockerfile --target export --output type=local,dest=winlibs-out .

# Linux: the build image, or just /opt/winlibs as a .tar.gz
docker build -f linux/Dockerfile -t winlibs-linux:rocky8 .
docker build -f linux/Dockerfile --target export --output type=tar,dest=- . | gzip > winlibs-linux-rocky8.tar.gz
```

Behind a TLS-intercepting proxy, put its CA certificate (`*.crt`) into
`windows/extra-ca/` or `linux/extra-ca/` and add `--build-arg https_proxy=...`.

**Directly on a Debian/Ubuntu host:**

```sh
apt-get install build-essential perl python3-mako mingw-w64 mingw-w64-tools \
                cmake ninja-build make autoconf automake libtool pkg-config \
                libgl-dev libglu1-mesa-dev libxkbcommon-dev curl git unzip xz-utils
bash build-scripts/build-all.sh         # everything, in dependency order
```

Individual `build-<lib>.sh` scripts can be run on their own; the only
ordering constraints are zlib/openssl before their consumers, boost before
wt/cpprestsdk, and qt-host → qt → qwt/marble (`build-qt.sh` builds a
Qt only to compile Qwt and Marble against; it goes to the scratch folder,
not the repo — set `WINLIBS_QT` to an existing mingw Qt prefix to skip it).

Scripts download their own sources (GitHub/GitLab mirrors) and install into
the repo folders. `WINLIBS_WORK` controls the scratch/build directory
(default `~/winlibs-work`). The same scripts run natively on Windows under
an MSYS2 MINGW64 shell if you drop the toolchain file from the cmake calls.
