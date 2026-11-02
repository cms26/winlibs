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
    "${WINLIBS}/qwt/6.2.0"
    "${WINLIBS}/boost/boost-1.86.0"
    "${WINLIBS}/log4cplus/log4cplus-2.2.0.1-nonunicode"
    "${WINLIBS}/liquid-dsp/liquid-dsp-1.8.2"
    "${WINLIBS}/fftw/fftw-3.3.10"
    "${WINLIBS}/gpb/36.0/c++"
    "${WINLIBS}/nlohmann/v3.12.0"
    "${WINLIBS}/eigen/eigen-3.4.1"
    "${WINLIBS}/vkfft/vkfft-1.3.4")

find_package(Qt6 6.12 REQUIRED COMPONENTS Core Gui Widgets Network WebSockets SerialPort Protobuf Svg)
find_package(qwt CONFIG REQUIRED)
find_package(Boost 1.86 EXACT CONFIG REQUIRED COMPONENTS thread filesystem)
find_package(log4cplus CONFIG REQUIRED)
find_package(liquid CONFIG REQUIRED)
find_package(FFTW3f CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(Eigen3 CONFIG REQUIRED)
find_package(VkFFT CONFIG REQUIRED)

qt_standard_project_setup()

qt_add_executable(winlibs-smoke main.cpp)
qt_add_protobuf(winlibs-smoke PROTO_FILES smoke.proto)
target_link_libraries(winlibs-smoke PRIVATE
    Qt6::Widgets Qt6::Network Qt6::WebSockets Qt6::SerialPort Qt6::Protobuf Qt6::Svg
    qwt::qwt
    Boost::thread Boost::filesystem
    log4cplus::log4cplus
    liquid::liquid
    FFTW3::fftw3f
    nlohmann_json::nlohmann_json
    Eigen3::Eigen)

# Installed layout: bin/winlibs-smoke, lib/ (all non-system .so files),
# plugins/; RPATH $ORIGIN/../lib.
set_target_properties(winlibs-smoke PROPERTIES INSTALL_RPATH "$ORIGIN/../lib")
install(TARGETS winlibs-smoke RUNTIME DESTINATION bin)
qt_generate_deploy_app_script(TARGET winlibs-smoke
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
    DEPLOY_TOOL_OPTIONS "")
install(SCRIPT ${deploy_script})
