# Rebuilds the entire winlibs codelibrary (Windows x64 binaries, mingw-w64)
# in one step:
#
#   docker build -t winlibs .
#
# then extract the results:
#
#   id=$(docker create winlibs)
#   docker cp "$id":/winlibs/out ./winlibs-out
#   docker rm "$id"
#
# Or skip the image-layer output entirely and build straight into a checkout
# of this repo:
#
#   docker build --target toolchain -t winlibs-toolchain .
#   docker run --rm -v "$PWD":/winlibs -w /winlibs winlibs-toolchain \
#       build-scripts/build-all.sh
#
# Full build takes several hours and ~40 GB of scratch space; almost all of
# it is Qt. Each library is its own layer, so bumping one library's version
# only rebuilds from that layer onward.

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

FROM toolchain AS build

# The scripts install into the parent of build-scripts/, i.e. /winlibs/out.
WORKDIR /winlibs/out
COPY build-scripts/ build-scripts/
ENV WINLIBS_WORK=/work

# Support deps, then everything that only needs the toolchain.
RUN build-scripts/build-zlib.sh
RUN build-scripts/build-openssl.sh
RUN build-scripts/build-eigen.sh
RUN build-scripts/build-nlohmann.sh
RUN build-scripts/build-vkfft.sh
RUN build-scripts/build-fftw.sh
RUN build-scripts/build-shapelib.sh
RUN build-scripts/build-log4cplus.sh
RUN build-scripts/build-portaudio.sh
RUN build-scripts/build-soapysdr.sh
RUN build-scripts/build-volk.sh
RUN build-scripts/build-libssh.sh
RUN build-scripts/build-flatbuffers.sh
RUN build-scripts/build-liquid-dsp.sh
RUN build-scripts/build-protobuf.sh

# Boost and its consumers.
RUN build-scripts/build-boost.sh
RUN build-scripts/build-wt.sh
RUN build-scripts/build-cpprestsdk.sh

# Qt host tools (Linux, not shipped), Qt for Windows, Qt consumers.
RUN build-scripts/build-qt-host.sh
RUN build-scripts/build-qt.sh
RUN build-scripts/build-qwt.sh
RUN build-scripts/build-marble.sh

# mingw runtime DLLs to ship next to application executables.
RUN build-scripts/build-runtime-dlls.sh

# Drop the scratch space so the final image holds only the results.
FROM toolchain
COPY --from=build /winlibs/out /winlibs/out
