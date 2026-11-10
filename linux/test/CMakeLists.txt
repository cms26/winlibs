# Smoke test for the winlibs Linux image: links every library, deploys the
# app with Qt's deployment API, and runs on any distribution with glibc 2.28+.
#
#   cmake -S linux/test -B /tmp/smoke -G Ninja -DCMAKE_BUILD_TYPE=Release
#   cmake --build /tmp/smoke && cmake --install /tmp/smoke --prefix /tmp/smoke-dist
#   QT_QPA_PLATFORM=offscreen /tmp/smoke-dist/bin/winlibs-smoke
cmake_minimum_required(VERSION 3.22)
project(winlibs_smoke LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(WINLIBS "$ENV{WINLIBS}" CACHE PATH "winlibs Linux root")
list(APPEND CMAKE_PREFIX_PATH
    "${WINLIBS}/qt/6.12.0"
    "${WINLIBS}/qwt/6.3.0"
    "${WINLIBS}/boost/boost-1.92.0"
    "${WINLIBS}/log4cplus/log4cplus-2.2.0.1-nonunicode"
    "${WINLIBS}/liquid-dsp/liquid-dsp-1.8.2"
    "${WINLIBS}/fftw/fftw-3.3.10"
    "${WINLIBS}/gpb/36.2/c++"
    "${WINLIBS}/nlohmann/v3.12.0"
    "${WINLIBS}/eigen/eigen-3.4.1"
    "${WINLIBS}/vkfft/vkfft-1.3.4"
    "${WINLIBS}/mkl/mkl-2026.2.0")

find_package(Qt6 6.12 REQUIRED COMPONENTS
    Core Gui Widgets Network WebSockets SerialPort Protobuf Svg
    Concurrent PrintSupport Sql Xml Test Qml Quick QuickWidgets
    Positioning Location Multimedia)
find_package(qwt CONFIG REQUIRED)
find_package(Boost 1.92.0 EXACT CONFIG REQUIRED COMPONENTS thread filesystem)
find_package(log4cplus CONFIG REQUIRED)
find_package(liquid CONFIG REQUIRED)
find_package(FFTW3f CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(Eigen3 CONFIG REQUIRED)
find_package(VkFFT CONFIG REQUIRED)

# REQUIRES 6.5: current Qt policies, e.g. QML modules under qrc:/qt/qml/ (QTP0001)
qt_standard_project_setup(REQUIRES 6.5)

# Eigen with MKL, built like an application library: MKL::Eigen
# (EIGEN_USE_MKL_ALL, MKL_ILP64, -fopenmp; MKL linked statically) plus
# libstdc++'s parallel mode. PUBLIC: every file that includes Eigen must see
# the same EIGEN_USE_MKL_ALL setting.
find_package(MKL 2026.2 CONFIG REQUIRED)
add_library(winlibs-eigen-mkl STATIC eigen_mkl.cpp)
target_link_libraries(winlibs-eigen-mkl PUBLIC MKL::Eigen)
target_compile_definitions(winlibs-eigen-mkl PRIVATE _GLIBCXX_PARALLEL)

qt_add_executable(winlibs-smoke main.cpp)
qt_add_protobuf(winlibs-smoke PROTO_FILES smoke.proto)
# QML shown in a QQuickWidget. As a QML module, Qt's QML deployment finds its
# imports (QtQuick) and ships them.
qt_add_qml_module(winlibs-smoke URI Smoke VERSION 1.0 QML_FILES Smoke.qml)
target_link_libraries(winlibs-smoke PRIVATE
    Qt6::Widgets Qt6::Network Qt6::WebSockets Qt6::SerialPort Qt6::Protobuf Qt6::Svg
    Qt6::Concurrent Qt6::PrintSupport Qt6::Sql Qt6::Xml Qt6::Test Qt6::QuickWidgets
    Qt6::Positioning Qt6::Location Qt6::Multimedia
    qwt::qwt
    Boost::thread Boost::filesystem
    log4cplus::log4cplus
    liquid::liquid
    FFTW3::fftw3f
    nlohmann_json::nlohmann_json
    Eigen3::Eigen
    winlibs-eigen-mkl)

# Installed layout: bin/winlibs-smoke, lib64/ (CMAKE_INSTALL_LIBDIR: lib64
# on RHEL-family build hosts; all non-system .so files), plugins/. Qt's
# deployment puts libraries in CMAKE_INSTALL_LIBDIR and points the plugins
# there, so the executable's RPATH must use the same directory.
include(GNUInstallDirs)
set_target_properties(winlibs-smoke PROPERTIES INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
install(TARGETS winlibs-smoke RUNTIME DESTINATION bin)
# The QML variant: also deploys the QML modules the app imports (needed for
# Qt Quick / QQuickWidget); otherwise the same as qt_generate_deploy_app_script.
qt_generate_deploy_qml_app_script(TARGET winlibs-smoke
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
    # offscreen as well as the default xcb platform plugin, so the test can
    # run headless on machines without an X server
    INCLUDE_PLUGINS qoffscreen)
install(SCRIPT ${deploy_script})
