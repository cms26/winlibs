#!/bin/bash
# Build the smoke test in the winlibs Linux image, deploy it, and run the
# deployed folder on other distributions.
#
#   linux/test/run-on-distros.sh [build image] [distro image...]
#
# On each distribution the usual desktop runtime libraries (GL, fontconfig,
# xkbcommon, xcb, dbus, glib, Kerberos/GSSAPI, PulseAudio client, GCC OpenMP
# runtime) are installed first, as on a
# desktop machine;
# then every library Qt's xcb platform plugin needs must resolve, and the
# app runs headless (offscreen platform). Nothing from /opt/winlibs is
# installed on the distributions: the app must bring all of it along.
#
#   ROCKY_MIRROR=https://dl.rockylinux.org/pub/rocky   use a fixed Rocky mirror
#                                                       (firewalled networks)
#   WINLIBS_SMOKE_MYSQL=host:port:user:password         also test a live MySQL
#                                                       connection (TLS required);
#                                                       containers use the host network
set -euo pipefail
IMAGE="${1:-winlibs-linux:rocky8}"
shift || true
if [ $# -gt 0 ]; then
    DISTROS=("$@")
else
    DISTROS=(rockylinux/rockylinux:8 rockylinux:9 ubuntu:20.04 ubuntu:24.04 debian:11 debian:13)
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
NET=(); [ -n "${https_proxy:-${HTTPS_PROXY:-}}" ] && NET=(--network host -e "https_proxy=${https_proxy:-$HTTPS_PROXY}" -e "http_proxy=${https_proxy:-$HTTPS_PROXY}")
MYSQL=()
if [ -n "${WINLIBS_SMOKE_MYSQL:-}" ]; then
    MYSQL=(-e WINLIBS_SMOKE_MYSQL)
    [ ${#NET[@]} -gt 0 ] || NET=(--network host)
fi

echo "=== build + deploy in $IMAGE"
docker run --rm "${MYSQL[@]}" ${MYSQL:+--network host} -e LANG=C.UTF-8 -v "$HERE":/test:ro -v "$OUT":/out "$IMAGE" bash -c '
    set -eo pipefail
    cmake -S /test -B /tmp/b -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build /tmp/b
    cmake --install /tmp/b --prefix /out/dist >/dev/null
    QT_QPA_PLATFORM=offscreen /out/dist/bin/winlibs-smoke'

echo "--- libraries the deployed app takes from the system:"
find "$OUT/dist" -type f \( -name '*.so*' -o -path '*/bin/*' \) -exec readelf -d {} + 2>/dev/null \
    | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p' | sort -u \
    | while read -r l; do [ -n "$(find "$OUT/dist" -name "$l" -print -quit)" ] || echo "    $l"; done \
    || true   # readelf fails on non-ELF files (qt.conf, ...)

# Runs inside each distribution container.
RUNTIME_SCRIPT='
set -e
if command -v dnf >/dev/null; then
    if [ -n "${ROCKY_MIRROR:-}" ]; then
        sed -i -e "s|^mirrorlist=|#mirrorlist=|" \
               -e "s|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=$ROCKY_MIRROR|" /etc/yum.repos.d/[Rr]ocky*.repo
    fi
    dnf -y -q install libglvnd-glx libglvnd-egl libglvnd-opengl fontconfig freetype \
        libxkbcommon libxkbcommon-x11 dbus-libs glib2 libX11 libX11-xcb libxcb \
        xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm libSM libICE libXrandr krb5-libs pulseaudio-libs libgomp >/dev/null
elif command -v apt-get >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get -qq update >/dev/null
    apt-get -qq install -y --no-install-recommends libgl1 libegl1 libopengl0 libfontconfig1 libfreetype6 \
        libxkbcommon0 libxkbcommon-x11-0 libdbus-1-3 libx11-6 libx11-xcb1 libxcb1 libxcb-icccm4 \
        libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-shape0 libxcb-randr0 libxcb-xfixes0 \
        libxcb-sync1 libxcb-xkb1 libsm6 libice6 libgssapi-krb5-2 libpulse0 libxrandr2 libgomp1 >/dev/null
    apt-get -qq install -y --no-install-recommends libglib2.0-0t64 >/dev/null 2>&1 \
        || apt-get -qq install -y --no-install-recommends libglib2.0-0 >/dev/null
fi
missing=$(ldd /app/plugins/platforms/libqxcb.so /app/plugins/multimedia/*.so /app/bin/winlibs-smoke | grep "not found" | sort -u || true)
if [ -n "$missing" ]; then echo "missing libraries:"; echo "$missing"; exit 1; fi
. /etc/os-release
printf "%s, %s: " "$PRETTY_NAME" "$(ldd --version | head -1 | grep -oE "[0-9.]+$")"
LANG=C.UTF-8 QT_QPA_PLATFORM=offscreen /app/bin/winlibs-smoke > /tmp/out.txt 2>&1 || { cat /tmp/out.txt; exit 1; }
tail -1 /tmp/out.txt
'

rc=0
for d in "${DISTROS[@]}"; do
    printf '=== %-26s ' "$d"
    if docker run --rm "${NET[@]}" "${MYSQL[@]}" -e "ROCKY_MIRROR=${ROCKY_MIRROR:-}" -v "$OUT/dist":/app:ro "$d" \
            bash -c "$RUNTIME_SCRIPT" > "$OUT/run.log" 2>&1; then
        tail -1 "$OUT/run.log"
    else
        echo "FAILED"; sed 's/^/    /' "$OUT/run.log"; rc=1
    fi
done
exit $rc
