#!/bin/bash
# Build the smoke test in the winlibs Linux image, then run the deployed
# result on other distributions' stock images (nothing installed there
# except what a desktop would have; offscreen platform for headless runs).
#
#   linux/test/run-on-distros.sh [image] [distro images...]
set -euo pipefail
IMAGE="${1:-winlibs-linux:rocky8}"
shift || true
DISTROS=("${@:-rockylinux/rockylinux:8 rockylinux/rockylinux:9 ubuntu:20.04 ubuntu:24.04 debian:11 debian:13}")
read -r -a DISTROS <<< "${DISTROS[*]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

docker run --rm -v "$HERE":/test:ro -v "$OUT":/out "$IMAGE" bash -c '
    set -e
    cmake -S /test -B /tmp/b -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build /tmp/b
    cmake --install /tmp/b --prefix /out/dist >/dev/null
    QT_QPA_PLATFORM=offscreen /out/dist/bin/winlibs-smoke'

# Libraries the deployed app still takes from the system (expected: glibc,
# libstdc++, X11/xcb, GL, fontconfig/freetype, glib, dbus, zlib).
echo "--- system libraries needed:"
find "$OUT/dist" -type f \( -name '*.so*' -o -path '*/bin/*' \) -exec readelf -d {} + 2>/dev/null \
    | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p' | sort -u \
    | while read -r l; do [ -e "$OUT/dist/lib/$l" ] || echo "    $l"; done

rc=0
for d in "${DISTROS[@]}"; do
    printf '=== %-28s ' "$d"
    if docker run --rm -v "$OUT/dist":/app:ro -e QT_QPA_PLATFORM=offscreen "$d" \
            /app/bin/winlibs-smoke > "$OUT/$$.log" 2>&1; then
        echo "ok"
    else
        echo "FAILED"; sed 's/^/    /' "$OUT/$$.log"; rc=1
    fi
done
exit $rc
