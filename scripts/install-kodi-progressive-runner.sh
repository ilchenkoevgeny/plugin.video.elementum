#!/bin/sh

set -eu

SOURCE_COMMIT="042b19fedc1dfe5f215a9fc79ec210d8aaf53481"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/$SOURCE_COMMIT"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
PY_DIR="$ADDON/resources/site-packages/elementum"
DIALOG_TARGET="$PY_DIR/dialog_select.py"
RUNNER_TARGET="$PY_DIR/kodi_progressive_runner.py"
RPC_TARGET="$PY_DIR/rpc.py"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/storage/elementum-kodi-progressive-backup-$STAMP"
TMP="$(mktemp -d /tmp/elementum-kodi-progressive.XXXXXX)"
KODI_STOPPED=0
WATCHDOG_WAS_ACTIVE=0

cleanup() {
    if [ "$KODI_STOPPED" -eq 1 ]; then
        systemctl start kodi.service >/dev/null 2>&1 || true
    fi
    if [ "$WATCHDOG_WAS_ACTIVE" -eq 1 ]; then
        systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

fetch_file() {
    source_path="$1"
    destination="$2"
    curl -fL --retry 3 --connect-timeout 20 \
        "$RAW_BASE/$source_path" \
        -o "$destination"
}

if systemctl is-active --quiet rutracker-stack-watchdog.timer 2>/dev/null; then
    WATCHDOG_WAS_ACTIVE=1
fi

echo "=== DOWNLOAD ==="
fetch_file \
    "resources/site-packages/elementum/dialog_select.py" \
    "$TMP/dialog_select.py"
fetch_file \
    "resources/site-packages/elementum/kodi_progressive_runner.py" \
    "$TMP/kodi_progressive_runner.py"
fetch_file \
    "resources/site-packages/elementum/rpc.py" \
    "$TMP/rpc.py"

echo "=== VALIDATE ==="
python3 -m py_compile \
    "$TMP/dialog_select.py" \
    "$TMP/kodi_progressive_runner.py" \
    "$TMP/rpc.py"

grep -Fq "Progressive Kodi runner requested" "$TMP/dialog_select.py"
grep -Fq "Progressive Kodi dialog opening" "$TMP/kodi_progressive_runner.py"
grep -Fq "window.show()" "$TMP/rpc.py"
if grep -Fq "Progressive dialog modal thread started" "$TMP/rpc.py"; then
    echo "ERROR: rpc.py всё ещё содержит блокирующий modal-thread patch" >&2
    exit 1
fi

for required in "$DIALOG_TARGET" "$RPC_TARGET"; do
    if [ ! -f "$required" ]; then
        echo "ERROR: не найден $required" >&2
        exit 1
    fi
done

mkdir -p "$BACKUP/resources/site-packages/elementum"
cp -p "$DIALOG_TARGET" "$BACKUP/resources/site-packages/elementum/dialog_select.py"
cp -p "$RPC_TARGET" "$BACKUP/resources/site-packages/elementum/rpc.py"
if [ -f "$RUNNER_TARGET" ]; then
    cp -p "$RUNNER_TARGET" "$BACKUP/resources/site-packages/elementum/kodi_progressive_runner.py"
fi

echo "=== STOP SERVICES ==="
systemctl stop rutracker-stack-watchdog.timer 2>/dev/null || true
systemctl stop rutracker-stack-watchdog.service 2>/dev/null || true
systemctl stop kodi.service
KODI_STOPPED=1

echo "=== INSTALL ==="
cp "$TMP/dialog_select.py" "$DIALOG_TARGET"
cp "$TMP/kodi_progressive_runner.py" "$RUNNER_TARGET"
cp "$TMP/rpc.py" "$RPC_TARGET"
chmod 0644 "$DIALOG_TARGET" "$RUNNER_TARGET" "$RPC_TARGET"
sync

systemctl reset-failed kodi.service
systemctl start kodi.service
KODI_STOPPED=0

echo "=== WAIT FOR ELEMENTUM ==="
ELEMENTUM_READY=0
BRIDGE_READY=0
ATTEMPT=0
while [ "$ATTEMPT" -lt 60 ]; do
    ATTEMPT=$((ATTEMPT + 1))

    if curl -sS --max-time 2 -o /dev/null \
        -w '%{http_code}' http://127.0.0.1:65220/ 2>/dev/null \
        | grep -Fq '200'; then
        ELEMENTUM_READY=1
    fi

    if curl -sS --max-time 2 http://127.0.0.1:65222/health 2>/dev/null \
        | grep -Fq '"status": "ok"'; then
        BRIDGE_READY=1
    fi

    if [ "$ELEMENTUM_READY" -eq 1 ] && [ "$BRIDGE_READY" -eq 1 ]; then
        break
    fi

    sleep 2
done

if [ "$WATCHDOG_WAS_ACTIVE" -eq 1 ]; then
    systemctl start rutracker-stack-watchdog.timer
fi

echo "=== RESULT ==="
echo "Backup: $BACKUP"
echo "Kodi: $(systemctl is-active kodi.service 2>/dev/null || true)"
echo "Elementum ready: $ELEMENTUM_READY"
echo "Progressive bridge ready: $BRIDGE_READY"
echo "Watchdog: $(systemctl is-active rutracker-stack-watchdog.timer 2>/dev/null || true)"

if [ "$ELEMENTUM_READY" -ne 1 ] || [ "$BRIDGE_READY" -ne 1 ]; then
    echo "ERROR: Kodi/Elementum progressive stack did not become ready" >&2
    journalctl -u kodi.service -n 100 --no-pager >&2 || true
    exit 1
fi

echo "Kodi progressive runner installed successfully."
