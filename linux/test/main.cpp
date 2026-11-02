// Exercises every library once and prints one line per check; exit code 0
// only if all pass. Runs headless with QT_QPA_PLATFORM=offscreen.
#include <complex>
#include <liquid/liquid.h>

#include <QApplication>
#include <QByteArray>
#include <QProtobufSerializer>
#include <QSslSocket>
#include <QWebSocket>
#include <QSerialPortInfo>
#include <QSvgRenderer>

#include <qwt_plot.h>
#include <qwt_plot_curve.h>

#include <boost/asio.hpp>
#include <boost/filesystem.hpp>
#include <boost/thread.hpp>

#include <log4cplus/configurator.h>
#include <log4cplus/logger.h>
#include <log4cplus/loggingmacros.h>
#include <log4cplus/initializer.h>

#include <Eigen/Dense>
#include <fftw3.h>
#include <nlohmann/json.hpp>

#include "smoke.qpb.h"

#include <cmath>
#include <cstdio>
#include <vector>

static int failures = 0;
static void check(const char *what, bool ok)
{
    std::printf("%-10s %s\n", what, ok ? "ok" : "FAILED");
    if (!ok)
        ++failures;
}

int main(int argc, char **argv)
{
    QApplication app(argc, argv);

    // Qt widgets + Qwt
    QwtPlot plot;
    auto *curve = new QwtPlotCurve("c");
    curve->setSamples(QVector<double>{0, 1, 2}, QVector<double>{0, 1, 4});
    curve->attach(&plot);
    plot.replot();
    check("qwt", plot.itemList().size() == 1);

    // Qt Network/OpenSSL, WebSockets, SerialPort, Svg
    check("openssl", QSslSocket::supportsSsl());
    std::printf("           %s\n", qPrintable(QSslSocket::sslLibraryVersionString()));
    QWebSocket ws;
    check("websocket", ws.state() == QAbstractSocket::UnconnectedState);
    (void)QSerialPortInfo::availablePorts();
    QSvgRenderer svg(QByteArray("<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'/>"));
    check("svg", svg.isValid());

    // QtProtobuf (qt_add_protobuf)
    smoke::Sample s;
    s.setName("iq");
    s.setIq({1.0f, -1.0f});
    QProtobufSerializer ser;
    smoke::Sample back;
    back.deserialize(&ser, s.serialize(&ser));
    check("protobuf", back.name() == "iq" && back.iq().size() == 2);

    // Boost (classic Asio API, thread, filesystem)
    boost::asio::io_service io;
    int ran = 0;
    io.post([&] { ++ran; });
    boost::thread t([&] { io.run(); });
    t.join();
    check("boost", ran == 1 && boost::filesystem::path("/a/b.txt").stem() == "b");

    // log4cplus (narrow)
    log4cplus::Initializer init;
    log4cplus::BasicConfigurator::doConfigure();
    LOG4CPLUS_INFO(log4cplus::Logger::getRoot(), "log4cplus works");
    check("log4cplus", true);

    // liquid-dsp (std::complex<float>), with FFTW behind its FFT blocks
    std::vector<std::complex<float>> x(64, {1.0f, 0.0f}), y(64);
    fftplan p = fft_create_plan(64, x.data(), y.data(), LIQUID_FFT_FORWARD, 0);
    fft_execute(p);
    fft_destroy_plan(p);
    firfilt_crcf f = firfilt_crcf_create_kaiser(31, 0.2f, 60.0f, 0.0f);
    std::complex<float> out;
    for (auto v : x) { firfilt_crcf_push(f, v); firfilt_crcf_execute(f, &out); }
    firfilt_crcf_destroy(f);
    check("liquid", std::abs(y[0] - std::complex<float>(64, 0)) < 1e-3f && std::abs(out) > 0.5f);

    // FFTW directly
    fftwf_complex *in = fftwf_alloc_complex(8), *o = fftwf_alloc_complex(8);
    fftwf_plan fp = fftwf_plan_dft_1d(8, in, o, FFTW_FORWARD, FFTW_ESTIMATE);
    for (int i = 0; i < 8; ++i) { in[i][0] = 1; in[i][1] = 0; }
    fftwf_execute(fp);
    check("fftw", std::fabs(o[0][0] - 8) < 1e-4f);
    fftwf_destroy_plan(fp); fftwf_free(in); fftwf_free(o);

    // header-only: nlohmann, Eigen
    check("json", nlohmann::json::parse(R"({"a":[1,2]})")["a"][1] == 2);
    Eigen::Matrix2f m; m << 1, 2, 3, 4;
    check("eigen", std::fabs(m.determinant() + 2) < 1e-5f);

    std::printf("%s\n", failures ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED");
    return failures ? 1 : 0;
}
