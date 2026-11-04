# Rebuilds the Windows x64 libraries (mingw-w64 cross build on Ubuntu) in
# one step. Run from the repository root (the build context is filtered by
# windows/Dockerfile.dockerignore, so the committed binaries aren't sent):
#
#   docker build -f windows/Dockerfile -t winlibs-windows .
#
# Write the results straight to a folder (or a .tar.gz) instead of an image:
#
#   docker build -f windows/Dockerfile --target export --output type=local,dest=winlibs-out .
#   docker build -f windows/Dockerfile --target export --output type=tar,dest=- . \
#       | gzip > winlibs-windows.tar.gz
#
# Or skip the image-layer output entirely and build straight into a checkout
# of this repo:
#
#   docker build -f windows/Dockerfile --target toolchain -t winlibs-toolchain .
#   docker run --rm -v "$PWD":/winlibs -w /winlibs winlibs-toolchain \
#       bash build-scripts/build-all.sh
#
# Full build takes several hours and ~40 GB of scratch space; almost all of
# it is Qt (built only to compile Qwt and Marble against; it is not part of
# the output). Each library is its own layer, so bumping one library's version
# only rebuilds from that layer onward.
#
# The Linux build is linux/Dockerfile.

FROM ubuntu:24.04 AS toolchain

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential perl python3 python3-mako \
        mingw-w64 mingw-w64-tools \
        cmake ninja-build make autoconf automake libtool pkg-config \
        libgl-dev libglu1-mesa-dev libxkbcommon-dev \
        curl git unzip xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    # Qt (std::thread) needs the posix-threads mingw variant
    && update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix \
    && update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

# Extra CA certificates (corporate TLS proxy; *.crt, PEM); the folder may be
# empty. Pass the proxy itself with --build-arg https_proxy=...
COPY windows/extra-ca/ /usr/local/share/ca-certificates/
RUN update-ca-certificates

FROM toolchain AS build

# The scripts install into the parent of build-scripts/, i.e. /winlibs/out.
WORKDIR /winlibs/out
COPY build-scripts/ build-scripts/
ENV WINLIBS_WORK=/work

# Support deps, then everything that only needs the toolchain.
RUN bash build-scripts/build-zlib.sh
RUN bash build-scripts/build-openssl.sh
RUN bash build-scripts/build-eigen.sh
RUN bash build-scripts/build-nlohmann.sh
RUN bash build-scripts/build-vkfft.sh
RUN bash build-scripts/build-fftw.sh
RUN bash build-scripts/build-shapelib.sh
RUN bash build-scripts/build-log4cplus.sh
RUN bash build-scripts/build-portaudio.sh
RUN bash build-scripts/build-soapysdr.sh
RUN bash build-scripts/build-volk.sh
RUN bash build-scripts/build-libssh.sh
RUN bash build-scripts/build-flatbuffers.sh
RUN bash build-scripts/build-liquid-dsp.sh
RUN bash build-scripts/build-protobuf.sh

# Boost and its consumers.
RUN bash build-scripts/build-boost.sh
RUN bash build-scripts/build-boost-1.86.sh
RUN bash build-scripts/build-wt.sh
RUN bash build-scripts/build-cpprestsdk.sh

# Qt host tools and Qt for Windows (both build-only, in /work, not
# shipped), then the Qt consumers.
RUN bash build-scripts/build-qt-host.sh
RUN bash build-scripts/build-qt.sh
RUN bash build-scripts/build-qwt.sh
RUN bash build-scripts/build-marble.sh

# mingw runtime DLLs to ship next to application executables.
RUN bash build-scripts/build-runtime-dlls.sh

# Developer tools: clang-format / clang-tidy from the official LLVM release.
RUN bash build-scripts/build-llvm-tools.sh

# Just the results, for --output (see the header).
FROM scratch AS export
COPY --from=build /winlibs/out /

# Default target: the toolchain plus the results, without the scratch space.
FROM toolchain
COPY --from=build /winlibs/out /winlibs/out
