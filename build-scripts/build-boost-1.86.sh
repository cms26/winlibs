#!/bin/bash
# Boost 1.86.0: the last release with the classic Boost.Asio API
# (io_service, io_service::work, io_service::post/dispatch/reset, ...),
# which Boost removed in 1.87. Same build options as the main Boost install,
# into boost/boost-1.86.0.
exec bash "$(dirname "$0")/build-boost.sh" 1.86.0
