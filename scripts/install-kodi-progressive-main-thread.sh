#!/bin/sh

set -eu

SOURCE_COMMIT="131ebeeb71d43dd20b4201c36986e713993364b3"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/$SOURCE_COMMIT"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
PYDIR="$ADDON/resources/site-packages/elementum"
SERVICE_TARGET="$PYDIR/service.py"
RPC_TARGET="$PYDIR/rpc.py"
DIALOG_TARGET="$PYDIR/dialog_select.py"
DISPATCHER_TARGET="$PYDIR/progressive_gui_dispatcher.py"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/storage/elementum-kodi-progressive-main-thread-backup-$STAMP"
TMP="$(mktemp -d /tmp/elementum-kodi-progressive-main-thread.XXXXXX)"
WATCHDOG_WAS_ACTIVE=0
KODI_STOPPED=0

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

echo "=== DOWNLOAD ==="
fetch_file "resources/site-packages/elementum/service.py" "$TMP/service.py"
fetch_file "resources/site-packages/elementum/rpc.py" "$TMP/rpc.py"
fetch_file "resources/site-packages/elementum/dialog_select.py" "$TMP/dialog_select.py"
fetch_file "resources/site-packages/elementum/progressive_gui_dispatcher.py" "$TMP/progressive_gui_dispatcher.py"

echo "=== VALIDATE ==="
grep -Fq "install_progressive_gui_dispatcher" "$TMP/service.py"
grep -Fq "process_pending_progressive_gui" "$TMP/service.py"
grep -Fq "Progressive GUI dispatcher installed" "$TMP/progressive_gui_dispatcher.py"
grep -Fq "window.show()" "$TMP/rpc.py"
if grep -Fq "Progressive dialog modal thread started" "$TMP/rpc.py"; then
    echo "ERROR: в rpc.py остался блокирующий doModal patch" >&2
    exit 1
fi
python3 -m py_compile \
    "$TMP/service.py" \
    "$TMP/rpc.py" \
    "$TMP/dialog_select.py" \
    "$TMP/progressive_gui_dispatcher.py"

if systemctl is-active --quiet rutracker-stack-watchdog.timer; then
    WATCHDOG_WAS_ACTIVE=1
fi
systemctl stop rutracker-stack-watchdog.timer 2>/dev/null || true
systemctl stop rutracker-stack-watchdog.service 2>/dev/null || true

mkdir -p "$BACKUP" "$PYDIR"
for file in \
    "$SERVICE_TARGET" \
    "$RPC_TARGET" \
    "$DIALOG_TARGET" \
    "$DISPATCHER_TARGET"; do
    if [ -f "$file" ]; then
        cp -p "$file" "$BACKUP/$(basename "$file")"
    fi
done

echo "=== INSTALL ==="
systemctl stop kodi.service
KODI_STOPPED=1
cp "$TMP/service.py" "$SERVICE_TARGET"
cp "$TMP/rpc.py" "$RPC_TARGET"
cp "$TMP/dialog_select.py" "$DIALOG_TARGET"
cp "$TMP/progressive_gui_dispatcher.py" "$DISPATCHER_TARGET"
chmod 0644 \
    "$SERVICE_TARGET" \
    "$RPC_TARGET" \
    "$DIALOG_TARGET" \
    "$DISPATCHER_TARGET"
sync

systemctl reset-failed kodi.service
systemctl start kodi.service
KODI_STOPPED=0

READY=0
ATTEMPT=0
while [ "$ATTEMPT" -lt 60 ]; do
    ATTEMPT=$((ATTEMPT + 1))
    if curl -sS --max-time 3 -o /dev/null \
        "http://127.0.0.1:65220/" 2>/dev/null; then
        READY=1
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
echo "Elementum ready: $READY"
echo "Watchdog: $(systemctl is-active rutracker-stack-watchdog.timer 2>/dev/null || true)"

grep -F "Progressive GUI dispatcher installed" \
    /storage/.kodi/temp/kodi.log 2>/dev/null | tail -n 1 || true

if [ "$READY" -ne 1 ]; then
    echo "ERROR: Elementum не поднялся после обновления" >&2
    exit 1
fi

echo "Kodi progressive main-thread dispatcher installed successfully."
