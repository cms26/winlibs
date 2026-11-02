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
  Qt binaries), libudev (Qt Serial Port) and, for the optional CUPS print
  plugin, libcups.

The libraries are delivered as a **Docker image** (not committed like the
Windows binaries: Qt alone is several GB).

## Verified

`linux/test/run-on-distros.sh` builds `linux/test` (one app using every
library: Qt Widgets/Network/WebSockets/SerialPort/Svg/Protobuf, Qwt, Boost
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
| `qt/6.12.0` | Qt 6.12.0 | qtbase (xcb, OpenGL, dbus, sqlite), qtshadertools, qtdeclarative, qtsvg, qtimageformats, qtserialport, qt5compat, qtwebsockets, qtgrpc (QtProtobuf/QtGrpc, `qt_add_protobuf`); OpenSSL linked and copied into `lib/`; ICU, HarfBuzz, PCRE2, libpng, libjpeg bundled |
| `boost/boost-1.86.0` | Boost 1.86.0 | classic Asio API (`io_service`); shared + static, tagged layout |
| `log4cplus/log4cplus-2.2.0.1-nonunicode` | log4cplus 2.2.0.1 | narrow (`tchar` = `char`), target `log4cplus::log4cplus` |
| `liquid-dsp/liquid-dsp-1.8.2` | liquid-dsp 1.8.2 | same tuning as Windows: run-time SSE/AVX dispatch, FFTW enabled and statically linked; targets `liquid::liquid`, `liquid::liquid-static` |
| `fftw/fftw-3.3.10` | FFTW 3.3.10 | double + single, SSE2/AVX/AVX2 codelets chosen at run time, threads; `FFTW3::fftw3`, `FFTW3::fftw3f` |
| `gpb/36.0` | Protocol Buffers 36.0 | same legacy layout as Windows (`bin/protoc`, headers + `lib/` in `c++/`); static, position independent |
| `qwt/6.2.0` | Qwt 6.2.0 | `libqwt.so` + `libqwt-static.a`; targets `qwt::qwt`, `qwt::qwt-static` |
| `openssl/openssl-3.5.8` | OpenSSL 3.5.8 | 3.5 LTS |
| `xcb-util-cursor/0.1.5` | xcb-util-cursor 0.1.5 | needed by Qt's xcb plugin, not in RHEL 8's base repositories; copied into Qt's `lib/` |
| `eigen/eigen-3.4.1`, `nlohmann/v3.12.0`, `vkfft/vkfft-1.3.4` | header-only | CMake packages as on Windows |

Release builds only (stripped). Your own code builds in Debug as usual and
debugs fine against them; `gdb` (gcc-toolset) is in the image.

Not built for Linux (yet): Boost 1.92, cpprestsdk, libssh, Marble,
PortAudio, Shapelib, SoapySDR, VOLK, Wt, FlatBuffers. Adding one is a
`build-<lib>.sh` in `linux/build-scripts/` plus a line in the Dockerfile.

## Building the image

From the repository root (the build context is filtered by
`linux/Dockerfile.dockerignore`, so the Windows binaries aren't sent):

```sh
docker build -f linux/Dockerfile -t winlibs-linux:rocky8 .
```

About 3 hours on 2 cores, almost all of it Qt, and ~20 GB of free disk
during the build (qtdeclarative's build tree is the peak); the final image
is 2.4 GB. Each library is its own
layer, so changing one library only rebuilds from there. Behind a corporate
TLS proxy, put its CA certificate (PEM, `*.crt`) into `linux/extra-ca/` and
pass `--build-arg https_proxy=...`.

Push it to your registry so Jenkins and developers pull it instead of
rebuilding:

```sh
docker tag winlibs-linux:rocky8 registry.example.com/winlibs-linux:rocky8-qt6.12.0
docker push registry.example.com/winlibs-linux:rocky8-qt6.12.0
```

The scripts also run directly on a Rocky/Alma/RHEL 8 machine with the
Dockerfile's packages installed: `linux/build-scripts/build-all.sh`
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
    "CMAKE_PREFIX_PATH": "$env{WINLIBS}/qt/6.12.0;$env{WINLIBS}/qwt/6.2.0;$env{WINLIBS}/boost/boost-1.86.0;$env{WINLIBS}/log4cplus/log4cplus-2.2.0.1-nonunicode;$env{WINLIBS}/liquid-dsp/liquid-dsp-1.8.2;$env{WINLIBS}/fftw/fftw-3.3.10;$env{WINLIBS}/gpb/36.0/c++;$env{WINLIBS}/nlohmann/v3.12.0"
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
