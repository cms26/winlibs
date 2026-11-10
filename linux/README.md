# winlibs for Linux (Rocky Linux 8 build image)

The same libraries, versions and build options as the Windows tree, built
for Linux x86-64 on **Rocky Linux 8 (glibc 2.28)** with **gcc-toolset-13**
(GCC 13). Build an application once in this image, and it runs on every
distribution with glibc 2.28 or newer, so there are no separate Ubuntu and
Rocky builds:

| Runs on | |
|---|---|
| RHEL / Rocky / Alma | 8, 9, 10 |
| Ubuntu | 20.04 and newer |
| Debian | 10 and newer |
| anything else | glibc 2.28 or newer (`ldd --version` shows it) |

Two things make that work:

- **Old glibc, new compiler.** Programs built against glibc 2.28 run on any
  newer glibc. gcc-toolset links the parts of libstdc++ newer than RHEL 8's
  into the binary itself, so C++17/20 code still only needs the system
  `libstdc++.so.6`.
- **Everything else ships with the app.** Qt (built here from source; the
  official Qt 6.12 binaries need glibc 2.34+), OpenSSL 3.5, Boost and the rest are
  deployed next to the executable. Only libraries that are part of every
  Linux desktop come from the system: glibc, libstdc++, X11/xcb,
  OpenGL/EGL (libglvnd), fontconfig/freetype, glib, dbus, zlib/zstd,
  Kerberos GSSAPI (`libgssapi_krb5`, used by Qt Network, as in the official
  Qt binaries), libudev (Qt Serial Port), libpulse (Qt Multimedia's
  audio; PulseAudio's client library, also on PipeWire desktops), libgomp
  (GCC's OpenMP runtime, for code built with `-fopenmp`, e.g. Eigen with
  MKL) and, for the optional CUPS print plugin, libcups.

The libraries are delivered as a **Docker image** (not committed like the
Windows binaries: Qt alone is several GB).

## Verified

`linux/test/run-on-distros.sh` builds `linux/test` (one app using every
library: Qt Widgets/Network/WebSockets/SerialPort/Svg/Protobuf,
Concurrent/PrintSupport/Sql/Xml/Test, Quick Widgets (QML), Positioning,
Location and Multimedia (decoding audio through FFmpeg), MySQL (driver
loads; with `WINLIBS_SMOKE_MYSQL=host:port:user:password` also a TLS
connection and queries), Eigen with MKL (in a library built with
`MKL::Eigen` and `_GLIBCXX_PARALLEL`), Qwt, Boost
Asio `io_service`/thread/filesystem, log4cplus, liquid-dsp, FFTW, OpenSSL,
nlohmann, Eigen) in the image, deploys it, and runs the deployed folder on
stock distributions with only their desktop libraries installed. All checks
pass on:

| Distribution | glibc |
|---|---|
| Rocky Linux 8.10 | 2.28 |
| Rocky Linux 9.8 | 2.34 |
| Ubuntu 20.04 | 2.31 |
| Ubuntu 24.04 | 2.39 |
| Debian 11 | 2.31 |
| Debian 13 | 2.41 |

The image build also fails if any file under `/opt/winlibs` needs a glibc
newer than 2.28 (`linux/build-scripts/check-glibc.sh`).

## Contents (`/opt/winlibs` in the image)

Same folder names as the Windows tree, so CMake paths match:

| Folder | Library | Notes |
|---|---|---|
| `qt/6.12.0` | Qt 6.12.0 | qtbase (xcb, OpenGL, dbus, sqlite), qtshadertools, qtdeclarative, qtsvg, qtimageformats, qtserialport, qt5compat, qtwebsockets, qtgrpc (QtProtobuf/QtGrpc, `qt_add_protobuf`), qtmultimedia (FFmpeg backend, PulseAudio/PipeWire audio), qtpositioning, qtlocation; OpenSSL and FFmpeg copied into `lib/`; ICU, HarfBuzz, PCRE2, libpng, libjpeg bundled |
| `boost/boost-1.92.0` | Boost 1.92.0 | same version as Windows; shared + static, tagged layout. Boost 1.86.0 (classic Asio API, `io_service`) can be added next to it with `build-boost.sh 1.86.0` |
| `log4cplus/log4cplus-2.2.0.1-nonunicode` | log4cplus 2.2.0.1 | narrow (`tchar` = `char`), target `log4cplus::log4cplus` |
| `liquid-dsp/liquid-dsp-1.8.3` | liquid-dsp 1.8.3 | same tuning as Windows: run-time SSE/AVX dispatch, FFTW enabled and statically linked; targets `liquid::liquid`, `liquid::liquid-static` |
| `fftw/fftw-3.3.10` | FFTW 3.3.10 | double + single, SSE2/AVX/AVX2 codelets chosen at run time, threads; `FFTW3::fftw3`, `FFTW3::fftw3f` |
| `gpb/36.2` | Protocol Buffers 36.2 | same legacy layout as Windows (`bin/protoc`, headers + `lib/` in `c++/`); static, position independent |
| `qwt/6.3.0` | Qwt 6.3.0 | `libqwt.so` + `libqwt-static.a`; targets `qwt::qwt`, `qwt::qwt-static` |
| `openssl/openssl-3.5.9` | OpenSSL 3.5.9 | 3.5 LTS |
| `ffmpeg/ffmpeg-9.0.1` | FFmpeg 9.0.1 | for Qt Multimedia (the version Qt 6.12 documents); shared, LGPL 2.1+ (no GPL/nonfree parts), no hardware video decoding (no libva dependency); also usable directly (headers + `lib/pkgconfig`) |
| `xcb-util-cursor/0.1.5` | xcb-util-cursor 0.1.5 | needed by Qt's xcb plugin, not in RHEL 8's base repositories; copied into Qt's `lib/` |
| `eigen/eigen-3.4.1`, `nlohmann/v3.12.0`, `vkfft/vkfft-1.3.4` | header-only | CMake packages as on Windows |
| `mariadb-connector-c/mariadb-connector-c-3.4.11` | MariaDB Connector/C 3.4.11 | MySQL client library for Qt's MySQL driver (`QMYSQL`, in `qt/6.12.0/plugins/sqldrivers`; `libmariadb` copied into Qt's `lib/`). LGPL 2.1; TLS via the winlibs OpenSSL; MySQL 8/9 logins (`caching_sha2_password`) built in. See "MySQL" below |
| `mkl/mkl-2026.2.0` | Intel oneMKL 2026.2 | Intel's binaries (from conda-forge, checksums pinned); headers, static + shared libraries (ILP64/LP64, GNU OpenMP/sequential). CMake package `MKL` written for winlibs: `MKL::MKL` and `MKL::Eigen` (Eigen with `EIGEN_USE_MKL_ALL`); see "Eigen with MKL" below. Intel Simplified Software License (redistributable), in `licenses/` |

Release builds only (stripped). Your own code builds in Debug as usual and
debugs fine against them; `gdb` (gcc-toolset) is in the image.

Not built for Linux (yet): cpprestsdk, libssh, Marble,
PortAudio, Shapelib, SoapySDR, VOLK, Wt, FlatBuffers. Adding one is a
`build-<lib>.sh` in `linux/build-scripts/` plus a line in the Dockerfile.

## Building the image

From the repository root (the build context is filtered by
`linux/Dockerfile.dockerignore`, so the Windows binaries aren't sent):

```sh
docker build -f linux/Dockerfile -t winlibs-linux:rocky8 .
```

About 3 hours on 2 cores, almost all of it Qt (FFmpeg plus Multimedia,
Positioning and Location add about 20 minutes), and ~20 GB of free disk
during the build (qtdeclarative's build tree is the peak); the final image
is about 4.5 GB (1.3 GB of it oneMKL). Each library is its own
layer, so changing one library only rebuilds from there. Behind a corporate
TLS proxy, put its CA certificate (PEM, `*.crt`) into `linux/extra-ca/` and
pass `--build-arg https_proxy=...`.

Push it to your registry so Jenkins and developers pull it instead of
rebuilding:

```sh
docker tag winlibs-linux:rocky8 registry.example.com/winlibs-linux:rocky8-qt6.12.0
docker push registry.example.com/winlibs-linux:rocky8-qt6.12.0
```

### Just the libraries, as a `.tar.gz`

To add the libraries to an existing build image instead of using this one:

```sh
docker build -f linux/Dockerfile --target export --output type=tar,dest=- . \
    | gzip > winlibs-linux-rocky8.tar.gz
```

The archive unpacks to `winlibs/`; in the other image's Dockerfile:

```dockerfile
ADD winlibs-linux-rocky8.tar.gz /opt/
ENV WINLIBS=/opt/winlibs
```

That image must be **RHEL/Rocky/Alma 8** (glibc 2.28; anything newer
makes your app need that newer glibc), with **gcc-toolset-13** (or newer)
and the X11/xcb/GL/fontconfig/dbus `-devel` packages from this
Dockerfile's `dnf install` line, plus `pulseaudio-libs` for Qt Multimedia. Tested: the archive added to a separate
Rocky 8 image builds and runs `linux/test`. About 520 MB compressed, 370 MB of
it oneMKL.

### Without Docker

The scripts also run directly on a Rocky/Alma/RHEL 8 machine with the
Dockerfile's packages installed (the main `dnf install` list plus `nasm
pulseaudio-libs-devel pipewire-devel` from the later step):
`bash linux/build-scripts/build-all.sh`
(`WINLIBS_PREFIX` sets the install root, default `/opt/winlibs`).

## Building your application in the image

The image sets `WINLIBS=/opt/winlibs`, puts GCC 13, CMake and Ninja on
`PATH`, and `CMAKE_PREFIX_PATH` to the Qt prefix. A Linux preset next to
the Windows ones:

```json
{
  "name": "linux-release",
  "generator": "Ninja",
  "binaryDir": "${sourceDir}/build/linux-release",
  "condition": { "type": "equals", "lhs": "${hostSystemName}", "rhs": "Linux" },
  "cacheVariables": {
    "CMAKE_BUILD_TYPE": "Release",
    "CMAKE_PREFIX_PATH": "$env{WINLIBS}/qt/6.12.0;$env{WINLIBS}/qwt/6.3.0;$env{WINLIBS}/boost/boost-1.92.0;$env{WINLIBS}/log4cplus/log4cplus-2.2.0.1-nonunicode;$env{WINLIBS}/liquid-dsp/liquid-dsp-1.8.3;$env{WINLIBS}/fftw/fftw-3.3.10;$env{WINLIBS}/gpb/36.2/c++;$env{WINLIBS}/nlohmann/v3.12.0;$env{WINLIBS}/eigen/eigen-3.4.1;$env{WINLIBS}/mkl/mkl-2026.2.0"
  }
}
```

```sh
docker run --rm -v "$PWD":/src -w /src winlibs-linux:rocky8 \
    bash -c 'cmake --preset linux-release && cmake --build --preset linux-release'
```

Jenkins (declarative pipeline):

```groovy
stage('Linux') {
  agent { docker { image 'registry.example.com/winlibs-linux:rocky8-qt6.12.0' } }
  steps {
    sh 'cmake --preset linux-release && cmake --build --preset linux-release'
    sh 'cmake --install build/linux-release --prefix dist'
  }
}
```

## MySQL

Qt's MySQL driver is included: `QSqlDatabase::addDatabase("QMYSQL")` with
`Qt6::Sql`, no extra CMake. It uses **MariaDB Connector/C** as the client
library rather than MySQL's own `libmysqlclient`: the connector is LGPL
(MySQL's library is GPL v2 or a commercial Oracle license), so it can ship
with a closed-source application, and it talks to current MySQL servers
(8.4 LTS, 9.x), including their default `caching_sha2_password` login.
Qt's deployment ships the driver plugin and `libmariadb` with the app.

Use TLS (the connector has the winlibs OpenSSL), e.g.
`db.setConnectOptions("SSL_MODE=SSL_MODE_REQUIRED")`; over an unencrypted
connection `caching_sha2_password` only works after a server-side cache hit
or with the server's RSA key. Tested against MySQL Server 9.7.4.

## Qt Location: your own tile server (ArcGIS, ...)

The `osm` plugin (the only map plugin Qt 6 builds; Qt switched off its
ESRI/ArcGIS, Mapbox and HERE plugins) loads tiles from any URL, `http` or
`https`, with `%x`, `%y`, `%z` in any order. ArcGIS uses `{z}/{y}/{x}`:

```qml
Plugin {
    name: "osm"
    PluginParameter {
        name: "osm.mapping.custom.host"
        value: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/%z/%y/%x"
    }
    PluginParameter { name: "osm.mapping.custom.mapcopyright"; value: "Esri" }
    // Don't look up the built-in styles on maps-redirect.qt.io: no tiles at
    // all are fetched until that lookup finishes, which never happens on a
    // network that can't reach it.
    PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: true }
}
```

and select the map type whose `style` is `MapType.CustomMap` ("Custom URL
Map"). HTTPS uses the bundled OpenSSL and the system's CA certificates;
tested with a TLS 1.3 tile server in ArcGIS's URL layout. Check the tile
provider's terms (ArcGIS Online needs an Esri account/API key for most use).

## Eigen with MKL

Eigen is header-only, so it uses MKL when *your* code is compiled with
`EIGEN_USE_MKL_ALL` and linked with MKL. The `MKL` package does both:

```cmake
find_package(Eigen3 CONFIG REQUIRED)
find_package(MKL CONFIG REQUIRED)            # $WINLIBS/mkl/mkl-2026.2.0 on CMAKE_PREFIX_PATH
target_link_libraries(mylib PUBLIC MKL::Eigen)
target_compile_definitions(mylib PRIVATE _GLIBCXX_PARALLEL)   # if you also want libstdc++'s parallel mode
```

`MKL::Eigen` gives `EIGEN_USE_MKL_ALL` (Eigen's products and decompositions
go through MKL's BLAS/LAPACKE, its math functions through VML), `MKL_ILP64`
(64-bit `MKL_INT`), `-fopenmp` with GNU OpenMP threading, and links MKL
**statically**, so nothing from MKL has to be deployed (the application grows
by the MKL code it uses, typically tens of MB). Use `MKL::MKL` for MKL alone.

Link it `PUBLIC` (or to every target that includes Eigen): all code that
includes Eigen headers must agree on `EIGEN_USE_MKL_ALL`. Settings, before
`find_package(MKL)`: `MKL_INTERFACE` (`ilp64`/`lp64`), `MKL_THREADING`
(`gnu_thread`/`sequential`), `MKL_LINK` (`static`/`dynamic`; dynamic needs
`install(FILES ${MKL_RUNTIME_LIBRARIES} ...)` because MKL loads its
CPU-specific libraries itself). At run time the machine needs `libgomp`
(GCC's OpenMP runtime, `libgomp1` on Debian/Ubuntu); `MKL_NUM_THREADS` /
`OMP_NUM_THREADS` limit the threads.

## Deploying

Give the executable an `$ORIGIN`-relative RPATH and let Qt's deployment
script copy Qt, its plugins and every other non-system library into the
install tree:

```cmake
include(GNUInstallDirs)
set_target_properties(myapp PROPERTIES INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
install(TARGETS myapp RUNTIME DESTINATION bin)
qt_generate_deploy_app_script(TARGET myapp OUTPUT_SCRIPT deploy
    NO_UNSUPPORTED_PLATFORM_ERROR
    INCLUDE_PLUGINS qoffscreen)   # optional: headless runs (CI, tests)
install(SCRIPT ${deploy})
```

For an app with QML or Qt Quick Widgets, use `qt_generate_deploy_qml_app_script`
instead (same options): it also ships the QML modules the app imports
(`QtQuick`, ...), which the plain script doesn't. Qt Multimedia, Positioning
and Location plugins are deployed automatically when the app links those
modules.

`cmake --install build/linux-release --prefix dist` then gives a
self-contained `dist/` (`bin/`, `lib64/`, `plugins/`) to tar up or turn into
an AppImage. Use `${CMAKE_INSTALL_LIBDIR}` in the RPATH as above: on a
RHEL-family build host it is `lib64`, and Qt's deployment copies the
libraries there (a hard-coded `$ORIGIN/../lib` leaves the app unable to
find them). Translations aren't deployed (Qt Linguist tools are not in the
image); add `qttools` to `build-qt.sh` if the app ships `.qm` files. `linux/test/` is a complete example that uses every library;
`linux/test/run-on-distros.sh` builds it in the image and runs the deployed
result on several distributions.

On the target machines, the X11 platform plugin needs the usual desktop
libraries (any desktop install has them; `xcb-util-cursor`, which Qt 6.5+
needs and many machines lack, is deployed with the app). On a minimal
server install that may mean e.g.
`dnf install libxkbcommon-x11 xcb-util-wm xcb-util-image xcb-util-keysyms xcb-util-renderutil`
or `apt install libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-shape0`.
Apps using Qt Multimedia also need `pulseaudio-libs` and `libXrandr`
(`libpulse0` and `libxrandr2` on Debian/Ubuntu); FFmpeg itself is deployed
with Qt. Building such apps in another image likewise needs `pulseaudio-libs`
there (`libQt6Multimedia` links `libpulse.so.0`).
