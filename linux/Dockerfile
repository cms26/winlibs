# Linux build environment for the winlibs libraries: Rocky Linux 8 (glibc
# 2.28) with gcc-toolset-13 (GCC 13, same major version as the Windows
# MinGW toolchain), the same library versions and build options as the
# Windows tree, installed under /opt/winlibs.
#
# Applications built in this image run on RHEL/Rocky/Alma 8+, Ubuntu 20.04+,
# Debian 11+ and other distributions with glibc >= 2.28, when deployed with
# their libraries (Qt, OpenSSL, Boost, ... from /opt/winlibs; see
# linux/README.md).
#
# Build (from the repository root):
#
#   docker build -f linux/Dockerfile -t winlibs-linux:rocky8 .
#
# Behind a TLS-intercepting proxy, put its CA certificate(s) (*.crt, PEM)
# into linux/extra-ca/ and pass the proxy (and, if Rocky's mirror list is
# blocked, a fixed mirror) as build args:
#
#   docker build --network host --build-arg https_proxy=$https_proxy \
#       --build-arg ROCKY_MIRROR=https://dl.rockylinux.org/pub/rocky \
#       -f linux/Dockerfile -t winlibs-linux:rocky8 .
#
# Only the libraries, as a .tar.gz for an existing build image (it unpacks
# to winlibs/; in that image's Dockerfile: ADD winlibs-linux-rocky8.tar.gz /opt/):
#
#   docker build -f linux/Dockerfile --target export --output type=tar,dest=- . \
#       | gzip > winlibs-linux-rocky8.tar.gz
#
# Use it to build an application (e.g. from Jenkins):
#
#   docker run --rm -v "$PWD":/src -w /src winlibs-linux:rocky8 \
#       bash -c 'cmake --preset linux-release && cmake --build --preset linux-release'
#
# Full build: ~3 hours on 2 cores, mostly Qt; needs ~20 GB of free disk at
# the peak (qtdeclarative); the final image is 2.4 GB. One layer per
# library, so bumping one library rebuilds only from that layer on.

FROM rockylinux/rockylinux:8 AS toolchain
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG GCC_TOOLSET=13

# Extra CA certificates (corporate proxy); the folder may be empty.
COPY linux/extra-ca/ /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust

# Optional: fixed package mirror instead of Rocky's mirror list (firewalled
# networks), e.g. --build-arg ROCKY_MIRROR=https://dl.rockylinux.org/pub/rocky
ARG ROCKY_MIRROR=
RUN if [ -n "$ROCKY_MIRROR" ]; then \
        sed -i -e 's|^mirrorlist=|#mirrorlist=|' \
               -e "s|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=${ROCKY_MIRROR}|" \
               /etc/yum.repos.d/Rocky-*.repo; \
    fi

RUN dnf -y install dnf-plugins-core \
 && dnf config-manager --set-enabled powertools \
 && dnf -y install \
        gcc-toolset-${GCC_TOOLSET}-gcc gcc-toolset-${GCC_TOOLSET}-gcc-c++ \
        gcc-toolset-${GCC_TOOLSET}-binutils gcc-toolset-${GCC_TOOLSET}-gdb \
        git make patch perl perl-IPC-Cmd perl-Pod-Html perl-Time-Piece gperf pkgconf-pkg-config \
        python3.11 \
        curl xz bzip2 unzip which file findutils diffutils \
        zlib-devel bzip2-devel xz-devel libzstd-devel \
        fontconfig-devel freetype-devel glib2-devel dbus-devel systemd-devel cups-devel \
        libX11-devel libXext-devel libXrender-devel libXi-devel libXfixes-devel \
        libXcursor-devel libXrandr-devel libSM-devel libICE-devel \
        libxcb-devel xcb-util-devel xcb-util-image-devel xcb-util-keysyms-devel \
        xcb-util-renderutil-devel xcb-util-wm-devel \
        libxkbcommon-devel libxkbcommon-x11-devel \
        mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel libdrm-devel \
 && dnf clean all \
 && alternatives --set python3 /usr/bin/python3.11

# Current CMake and Ninja from their official GitHub releases (the RHEL 8
# packages are older than Qt 6.12 likes); both run on glibc 2.17+.
ARG CMAKE_VER=3.31.10
ARG NINJA_VER=1.13.1
RUN curl -sSfL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}-linux-x86_64.tar.gz" \
        | tar -xz -C /usr/local --strip-components=1 \
 && curl -sSfL -o /tmp/ninja.zip "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VER}/ninja-linux.zip" \
 && unzip -q -o /tmp/ninja.zip -d /usr/local/bin && rm /tmp/ninja.zip \
 && cmake --version | head -1 && ninja --version

# gcc-toolset on PATH for every later step and for application builds
# (env.sh checks GCC_TOOLSET_ENABLED and doesn't source the toolset again).
ENV PATH=/opt/rh/gcc-toolset-${GCC_TOOLSET}/root/usr/bin:/usr/local/bin:$PATH \
    GCC_TOOLSET_ENABLED=/opt/rh/gcc-toolset-${GCC_TOOLSET} \
    WINLIBS=/opt/winlibs \
    WINLIBS_PREFIX=/opt/winlibs

FROM toolchain AS build

WORKDIR /winlibs
ENV WINLIBS_WORK=/work
# Each step copies only the files it uses, so editing one build script
# rebuilds from that library on, not everything. Sources and build trees
# are deleted in the same layer to keep it small.
ARG S=linux/build-scripts
COPY $S/env.sh $S/
COPY build-scripts/vkfft-cmake/ build-scripts/vkfft-cmake/
COPY $S/build-header-only.sh $S/
RUN $S/build-header-only.sh && rm -rf /work
COPY $S/build-openssl.sh $S/
RUN $S/build-openssl.sh && rm -rf /work
COPY build-scripts/build-fftw.sh build-scripts/
COPY $S/build-fftw.sh $S/
RUN $S/build-fftw.sh && rm -rf /work
COPY $S/cmake/liquidConfig.cmake $S/cmake/
COPY $S/build-liquid-dsp.sh $S/
RUN $S/build-liquid-dsp.sh && rm -rf /work
COPY $S/build-log4cplus.sh $S/
RUN $S/build-log4cplus.sh && rm -rf /work
COPY $S/build-boost.sh $S/
RUN $S/build-boost.sh && rm -rf /work
COPY $S/build-protobuf.sh $S/
RUN $S/build-protobuf.sh && rm -rf /work
COPY $S/build-xcb-cursor.sh $S/
RUN $S/build-xcb-cursor.sh && rm -rf /work
# Qt in several layers (qtdeclarative alone is about as big as qtbase).
COPY $S/build-qt.sh $S/
RUN $S/build-qt.sh qtbase && rm -rf /work
RUN $S/build-qt.sh qtshadertools qtsvg qtimageformats qtserialport qt5compat qtwebsockets && rm -rf /work
RUN $S/build-qt.sh qtdeclarative && rm -rf /work
RUN $S/build-qt.sh qtgrpc && rm -rf /work
RUN $S/build-qt.sh --check
COPY build-scripts/qwt-CMakeLists.txt build-scripts/
COPY $S/cmake/qwtConfig.cmake $S/cmake/
COPY $S/build-qwt.sh $S/
RUN $S/build-qwt.sh && rm -rf /work
COPY $S/build-all.sh $S/

# Nothing may need a newer glibc than the base system's (2.28).
COPY $S/check-glibc.sh $S/
RUN $S/check-glibc.sh /opt/winlibs 2.28

# Just /opt/winlibs, for --output: a .tar.gz to add to another (RHEL 8
# family) build image, see the header.
FROM scratch AS export
COPY --from=build /opt/winlibs /winlibs

# Default target: the build image (toolchain + /opt/winlibs).
FROM toolchain
COPY --from=build /opt/winlibs /opt/winlibs
ENV CMAKE_PREFIX_PATH=/opt/winlibs/qt/6.12.0
WORKDIR /src
