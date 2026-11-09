#!/bin/bash
# Intel oneMKL (prebuilt by Intel) for Eigen with MKL (EIGEN_USE_MKL_ALL) and
# for direct BLAS/LAPACK/FFT use, with a CMake package written for winlibs
# (cmake/MKLConfig.cmake): MKL::MKL and MKL::Eigen. Defaults: ILP64
# (MKL_ILP64, 64-bit MKL_INT), GNU OpenMP threading (libgomp, -fopenmp),
# static linking.
#
#   build-mkl.sh
#
# The binaries are Intel's, taken from the conda-forge channel (which
# repackages Intel's releases) because it is a plain HTTPS download with
# checksums; Intel's own YUM repository works too but needs its repo setup.
# The files and their SHA-256 are pinned below. Behind a firewall, point
# MKL_CONDA_CHANNEL at a mirror of
# https://conda.anaconda.org/conda-forge/linux-64 (e.g. an Artifactory
# conda remote).
#
# Only what C/C++ programs need is kept (about 1.2 GB instead of 1.6 GB):
# headers; the core, ILP64/LP64 interface and GNU-OpenMP/sequential threading
# libraries, static and shared; and the CPU-specific kernels the shared
# libraries load at run time (libmkl_def/mc3/avx2/avx512/avx10, VML). Not
# kept: ScaLAPACK/BLACS/cluster FFT (MPI), the Intel-OpenMP and TBB threading
# layers (they need libiomp5/libtbb), Fortran 95 interfaces.
#
# License: Intel Simplified Software License (redistributable); the license
# files are installed in licenses/.
#
# Needs curl, unzip and zstd.
source "$(dirname "$0")/env.sh"

VER=2026.2.0
PREFIX="$PREFIX_ROOT/mkl/mkl-$VER"
CHANNEL="${MKL_CONDA_CHANNEL:-https://conda.anaconda.org/conda-forge/linux-64}"
PACKAGES=(
    "mkl-$VER-hd2095e1_881.conda          172814c644b9146c9f746bba9b9215ecb4afd003de8b8cb730ad3dc93ae0aad7"
    "mkl-static-$VER-ha770c72_881.conda   f16d373010a39409a0dac12a1587422ff06003a23edda53c125b53b2a5297ea9"
    "mkl-include-$VER-ha770c72_881.conda  0f409aae2580e1f3fa20b0441655a2e72dedd10e286d1e66b954bd0daae4b30a"
)

for tool in curl unzip zstd; do
    command -v "$tool" >/dev/null || { echo "ERROR: $tool is needed (dnf install $tool)" >&2; exit 1; }
done

# Download, verify, unpack (.conda = zip with zstd-compressed tars) into $X
X="$BLD/mkl-$VER"
rm -rf "$X" "$PREFIX"
mkdir -p "$X/root" "$SRC/mkl"
for entry in "${PACKAGES[@]}"; do
    read -r file sha <<<"$entry"
    if [ ! -f "$SRC/mkl/$file" ] || ! echo "$sha  $SRC/mkl/$file" | sha256sum -c --quiet 2>/dev/null; then
        curl -sSfL -o "$SRC/mkl/$file" "$CHANNEL/$file"
    fi
    echo "$sha  $SRC/mkl/$file" | sha256sum -c --quiet \
        || { echo "ERROR: checksum mismatch for $file" >&2; exit 1; }
    rm -rf "$X/pkg" && mkdir -p "$X/pkg"
    unzip -q "$SRC/mkl/$file" -d "$X/pkg"
    for t in "$X"/pkg/pkg-*.tar.zst; do
        zstd -q -dc "$t" | tar -x -C "$X/root"
    done
done

# Install the parts C/C++ programs use
mkdir -p "$PREFIX/lib" "$PREFIX/licenses"
cp -a "$X/root/include" "$PREFIX/"
cd "$X/root/lib"
for l in core intel_ilp64 intel_lp64 gnu_thread sequential; do
    cp -a "libmkl_$l.a" "libmkl_$l.so" libmkl_"$l".so.[0-9]* "$PREFIX/lib/"
done
cp -a libmkl_def.so.* libmkl_mc3.so.* libmkl_avx2.so.* libmkl_avx512.so.* libmkl_avx10.so.* \
      libmkl_vml_*.so.* "$PREFIX/lib/"
cp -a "$X"/root/info/licenses/* "$PREFIX/licenses/"
cd /
rm -rf "$X"

# CMake package
mkdir -p "$PREFIX/lib/cmake/MKL"
cp "$SCRIPT_DIR/cmake/MKLConfig.cmake" "$PREFIX/lib/cmake/MKL/"
cat > "$PREFIX/lib/cmake/MKL/MKLConfigVersion.cmake" <<EOF
# winlibs oneMKL $VER: compatible with requests for $VER or older.
set(PACKAGE_VERSION "$VER")
if(PACKAGE_FIND_VERSION VERSION_GREATER PACKAGE_VERSION)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if(PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)
        set(PACKAGE_VERSION_EXACT TRUE)
    endif()
endif()
EOF

# Check: the version header matches, and a static ILP64 + GNU OpenMP program
# links and runs (64-bit MKL_INT, dgemm result, threads available).
grep -q "__INTEL_MKL__ *${VER%%.*}" "$PREFIX/include/mkl_version.h" \
    || { echo "ERROR: mkl_version.h is not $VER" >&2; exit 1; }
T="$BLD/mkl-check"
rm -rf "$T" && mkdir -p "$T"
cat > "$T/check.c" <<'EOF'
#include <mkl.h>
#include <stdio.h>
int main(void) {
    double a[4] = {1, 2, 3, 4}, b[4] = {5, 6, 7, 8}, c[4] = {0};
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1.0, a, 2, b, 2, 0.0, c, 2);
    char v[200]; mkl_get_version_string(v, sizeof v);
    printf("%s | sizeof(MKL_INT)=%zu | threads=%d | c=%g %g %g %g\n",
           v, sizeof(MKL_INT), mkl_get_max_threads(), c[0], c[1], c[2], c[3]);
    return !(sizeof(MKL_INT) == 8 && c[0] == 19 && c[1] == 22 && c[2] == 43 && c[3] == 50);
}
EOF
gcc -DMKL_ILP64 -fopenmp -I"$PREFIX/include" "$T/check.c" -o "$T/check" \
    -Wl,--start-group "$PREFIX/lib/libmkl_intel_ilp64.a" "$PREFIX/lib/libmkl_gnu_thread.a" \
    "$PREFIX/lib/libmkl_core.a" -Wl,--end-group -lpthread -lm -ldl
"$T/check"
rm -rf "$T"
echo "oneMKL $VER installed to $PREFIX"
