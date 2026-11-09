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
#include <QAudioDecoder>
#include <QDataStream>
#include <QEventLoop>
#include <QFile>
#include <QGeoCoordinate>
#include <QGeoPositionInfoSource>
#include <QGeoServiceProvider>
#include <QMediaFormat>
#include <QPainter>
#include <QPrinter>
#include <QQuickWidget>
#include <QQuickWindow>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTimer>
#include <QXmlStreamReader>
#include <QtConcurrent>
#include <QtTest>

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
#include "eigen_mkl.h"
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

// A short 16-bit mono WAV file, for the Qt Multimedia (FFmpeg) decode check
static void writeWav(const QString &path)
{
    const int rate = 8000, frames = 800;
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return;
    QDataStream d(&f);
    d.setByteOrder(QDataStream::LittleEndian);
    f.write("RIFF"); d << quint32(36 + frames * 2);
    f.write("WAVEfmt "); d << quint32(16) << quint16(1) << quint16(1) << quint32(rate)
                         << quint32(rate * 2) << quint16(2) << quint16(16);
    f.write("data"); d << quint32(frames * 2);
    for (int i = 0; i < frames; ++i)
        d << qint16(10000 * std::sin(2 * M_PI * 440 * i / rate));
}

int main(int argc, char **argv)
{
    // Qt Quick's software renderer: works headless (offscreen) too
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
    QApplication app(argc, argv);
    QTemporaryDir tmp;

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

    // Boost (Asio, thread, filesystem). io_context / asio::post: the API since
    // Boost 1.66; io_service and io_service::post() were removed in 1.87.
    boost::asio::io_context io;
    int ran = 0;
    boost::asio::post(io, [&] { ++ran; });
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
    {
        std::string info;
        check("eigen-mkl", eigenMklCheck(info));
        std::printf("           %s\n", info.c_str());
    }

    // Qt Concurrent, Xml, Test, Sql (SQLite), PrintSupport (PDF)
    check("concurrent", QtConcurrent::run([] { return 42; }).result() == 42);
    QXmlStreamReader xml("<a><b>1</b></a>");
    int elements = 0;
    while (!xml.atEnd()) if (xml.readNext() == QXmlStreamReader::StartElement) ++elements;
    check("xml", !xml.hasError() && elements == 2);
    check("qtest", QTest::qWaitFor([] { return true; }, 10));
    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", "smoke");
        db.setDatabaseName(":memory:");
        QSqlQuery q(db);
        bool ok = db.open() && q.exec("create table t(v int)") && q.exec("insert into t values (7)")
                  && q.exec("select v from t") && q.next() && q.value(0).toInt() == 7;
        check("sql", ok);
    }
    QSqlDatabase::removeDatabase("smoke");

    // Qt's MySQL driver (QMYSQL, MariaDB Connector/C). With
    // WINLIBS_SMOKE_MYSQL=host:port:user:password also connect (TLS
    // required) and run queries against that server.
    check("mysql", QSqlDatabase::isDriverAvailable("QMYSQL")
                   && QSqlDatabase::addDatabase("QMYSQL", "mysql-driver").isValid());
    QSqlDatabase::removeDatabase("mysql-driver");
    const QStringList server = qEnvironmentVariable("WINLIBS_SMOKE_MYSQL").split(':');
    if (server.size() == 4) {
        QSqlDatabase db = QSqlDatabase::addDatabase("QMYSQL", "mysql-live");
        db.setHostName(server[0]);
        db.setPort(server[1].toInt());
        db.setUserName(server[2]);
        db.setPassword(server[3]);
        db.setConnectOptions("SSL_MODE=SSL_MODE_REQUIRED");   // QMYSQL option: fail without TLS
        bool ok = db.open();
        QString version, cipher, auth, error;
        if (ok) {
            QSqlQuery q(db);
            ok = q.exec("select version(), "
                        "(select variable_value from performance_schema.session_status where variable_name = 'Ssl_cipher'), "
                        "(select plugin from mysql.user where user = substring_index(current_user(), '@', 1) limit 1)")
                 && q.next();
            if (ok) {
                version = q.value(0).toString();
                cipher = q.value(1).toString();
                auth = q.value(2).toString();
            }
            ok = ok && q.exec("create database if not exists winlibs_smoke") && q.exec("use winlibs_smoke")
                 && q.exec("create temporary table t (id bigint primary key, name varchar(20))")
                 && q.prepare("insert into t values (?, ?)");
            q.addBindValue(QVariant::fromValue<qint64>(5000000000LL));
            q.addBindValue(QString::fromUtf8("caf\u00e9"));
            ok = ok && q.exec() && q.exec("select id, name from t") && q.next()
                 && q.value(0).toLongLong() == 5000000000LL && q.value(1).toString() == QString::fromUtf8("caf\u00e9")
                 && !cipher.isEmpty();
            if (q.lastError().isValid())
                error = q.lastError().text();
        }
        if (db.lastError().isValid())
            error = db.lastError().text();
        check("mysql-live", ok);
        std::printf("           server %s, TLS cipher %s, login %s%s%s\n", qPrintable(version),
                    cipher.isEmpty() ? "(none)" : qPrintable(cipher), qPrintable(auth),
                    error.isEmpty() ? "" : ", error: ", qPrintable(error));
        db.close();
    }
    QSqlDatabase::removeDatabase("mysql-live");
    {
        QPrinter printer(QPrinter::HighResolution);
        printer.setOutputFormat(QPrinter::PdfFormat);
        printer.setOutputFileName(tmp.filePath("smoke.pdf"));
        QPainter painter(&printer);
        painter.drawText(100, 100, "winlibs");
        painter.end();
        check("printpdf", QFileInfo(tmp.filePath("smoke.pdf")).size() > 0);
    }

    // Qt Quick Widgets (QML in a widget)
    {
        QQuickWidget quick;
        quick.loadFromModule("Smoke", "Smoke");   // QML module "Smoke", file Smoke.qml
        check("quickwidget", quick.status() == QQuickWidget::Ready && quick.rootObject());
        for (const auto &e : quick.errors())
            std::printf("           %s\n", qPrintable(e.toString()));
    }

    // Qt Positioning, Qt Location (their plugins must be deployed)
    QGeoCoordinate ny(40.7128, -74.0060), bos(42.3601, -71.0589);
    const QStringList sources = QGeoPositionInfoSource::availableSources();
    check("positioning", qAbs(ny.distanceTo(bos) / 1000 - 306) < 5 && sources.contains("nmea"));
    std::printf("           position sources: %s\n", qPrintable(sources.join(", ")));
    const QStringList geo = QGeoServiceProvider::availableServiceProviders();
    check("location", geo.contains("osm"));
    std::printf("           geo services: %s\n", qPrintable(geo.join(", ")));

    // Qt Multimedia, FFmpeg backend: decode a WAV file
    {
        writeWav(tmp.filePath("tone.wav"));
        QAudioDecoder decoder;
        qint64 frames = 0;
        QEventLoop loop;
        QObject::connect(&decoder, &QAudioDecoder::bufferReady, [&] { frames += decoder.read().frameCount(); });
        QObject::connect(&decoder, &QAudioDecoder::finished, &loop, &QEventLoop::quit);
        QObject::connect(&decoder, qOverload<QAudioDecoder::Error>(&QAudioDecoder::error), &loop, &QEventLoop::quit);
        QTimer::singleShot(10000, &loop, &QEventLoop::quit);
        decoder.setSource(QUrl::fromLocalFile(tmp.filePath("tone.wav")));
        decoder.start();
        loop.exec();
        const int codecs = QMediaFormat().supportedAudioCodecs(QMediaFormat::Decode).size();
        check("multimedia", decoder.isSupported() && frames >= 700 && codecs > 5);
        std::printf("           decoded %lld frames, %d audio codecs%s%s\n", (long long)frames, codecs,
                    decoder.error() ? ", error: " : "", qPrintable(decoder.errorString()));
    }

    std::printf("%s\n", failures ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED");
    return failures ? 1 : 0;
}
