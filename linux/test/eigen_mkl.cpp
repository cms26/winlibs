// Built like an application library using Eigen with MKL: MKL::Eigen
// (EIGEN_USE_MKL_ALL, MKL_ILP64, -fopenmp) plus libstdc++'s parallel mode
// (-D_GLIBCXX_PARALLEL).
#include "eigen_mkl.h"

#include <Eigen/Dense>
#include <mkl.h>
#include <omp.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <random>
#include <vector>

#if !defined(EIGEN_USE_MKL_ALL) || !defined(MKL_ILP64) || !defined(_GLIBCXX_PARALLEL) || !defined(_OPENMP)
#error "built without EIGEN_USE_MKL_ALL / MKL_ILP64 / _GLIBCXX_PARALLEL / -fopenmp"
#endif
static_assert(sizeof(MKL_INT) == 8, "MKL_ILP64: MKL_INT must be 64-bit");

bool eigenMklCheck(std::string &info)
{
    const int n = 400;
    Eigen::MatrixXd a = Eigen::MatrixXd::Random(n, n), b = Eigen::MatrixXd::Random(n, n);

    // Matrix product: MKL dgemm (EIGEN_USE_BLAS); compare a few entries
    // with a plain loop.
    Eigen::MatrixXd c = a * b;
    double productError = 0;
    for (int i : {0, 17, n - 1})
        for (int j : {0, 99, n - 1}) {
            double s = 0;
            for (int k = 0; k < n; ++k) s += a(i, k) * b(k, j);
            productError = std::max(productError, std::abs(s - c(i, j)));
        }

    // Linear solve: MKL LAPACKE dgetrf/dgetrs (EIGEN_USE_LAPACKE)
    Eigen::VectorXd x = Eigen::VectorXd::Random(n);
    Eigen::VectorXd rhs = a * x;
    double solveError = (a.partialPivLu().solve(rhs) - x).cwiseAbs().maxCoeff();

    // Vectorized math: MKL VML vdExp (EIGEN_USE_MKL_VML)
    Eigen::ArrayXd v = Eigen::ArrayXd::LinSpaced(10000, -5, 5);
    double expError = (v.exp() - v.unaryExpr([](double t) { return std::exp(t); })).abs().maxCoeff();

    // libstdc++ parallel mode: std::sort runs the OpenMP parallel sort
    std::vector<double> data(2000000);
    std::mt19937_64 rng(1);
    std::uniform_real_distribution<double> uniform;
    for (double &d : data) d = uniform(rng);
    std::sort(data.begin(), data.end());
    bool sorted = std::is_sorted(data.begin(), data.end());

    char version[256];
    mkl_get_version_string(version, sizeof version);
    char buffer[512];
    std::snprintf(buffer, sizeof buffer,
                  "%s; MKL threads %d, OpenMP threads %d; errors: product %.1e, solve %.1e, exp %.1e; parallel sort %s",
                  version, mkl_get_max_threads(), omp_get_max_threads(), productError, solveError, expError,
                  sorted ? "ok" : "FAILED");
    info = buffer;
    return productError < 1e-10 && solveError < 1e-8 && expError < 1e-12 && sorted;
}
