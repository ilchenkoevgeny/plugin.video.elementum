#!/bin/sh
set -eu

SOURCE_COMMIT="c4466b8271c5c3f3458c6fe6dfcaf93c8530cf4a"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/${SOURCE_COMMIT}"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
PYDIR="$ADDON/resources/site-packages/elementum"
TARGET="$PYDIR/progressive_gui_dispatcher.py"
SERVICE="$PYDIR/service.py"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/storage/elementum-kodi-progressive-modal-backup-${STAMP}"
TMP="$(mktemp -d /tmp/elementum-kodi-progressive-modal.XXXXXX)"
WATCHDOG_WAS_ACTIVE=0
KODI_STOPPED=0

cleanup() {
    if [ "$KODI_STOPPED" -eq 1 ]; then
        systemctl reset-failed kodi.service >/dev/null 2>&1 || true
        systemctl start kodi.service >/dev/null 2>&1 || true
    fi
    if [ "$WATCHDOG_WAS_ACTIVE" -eq 1 ]; then
        systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

if [ ! -f "$SERVICE" ] || ! grep -q '^def run():' "$SERVICE"; then
    echo "ERROR: elementum/service.py is missing def run()" >&2
    exit 1
fi

echo "=== DOWNLOAD ==="
curl -fL --retry 3 --connect-timeout 20 \
  "$RAW_BASE/resources/site-packages/elementum/progressive_gui_dispatcher.py" \
  -o "$TMP/progressive_gui_dispatcher.py"

echo "=== VALIDATE ==="
grep -Fq "Progressive GUI modal dispatcher installed" "$TMP/progressive_gui_dispatcher.py"
grep -Fq "super(DialogSelect, window).doModal()" "$TMP/progressive_gui_dispatcher.py"
if grep -Fq "super(DialogSelect, window).show()" "$TMP/progressive_gui_dispatcher.py"; then
    echo "ERROR: old empty-shell show() call is still present" >&2
    exit 1
fi
python3 -m py_compile "$TMP/progressive_gui_dispatcher.py"

if systemctl is-active --quiet rutracker-stack-watchdog.timer; then
    WATCHDOG_WAS_ACTIVE=1
fi
systemctl stop rutracker-stack-watchdog.timer 2>/dev/null || true
systemctl stop rutracker-stack-watchdog.service 2>/dev/null || true

mkdir -p "$BACKUP" "$PYDIR"
if [ -f "$TARGET" ]; then
    cp -p "$TARGET" "$BACKUP/progressive_gui_dispatcher.py"
fi

echo "=== INSTALL ==="
systemctl stop kodi.service
KODI_STOPPED=1
install -m 0644 "$TMP/progressive_gui_dispatcher.py" "$TARGET"
rm -f "$PYDIR/__pycache__/progressive_gui_dispatcher"*.pyc 2>/dev/null || true
sync

systemctl reset-failed kodi.service >/dev/null 2>&1 || true
systemctl start kodi.service
KODI_STOPPED=0

READY=0
ATTEMPT=0
while [ "$ATTEMPT" -lt 60 ]; do
    ATTEMPT=$((ATTEMPT + 1))
    code="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:65220/ 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
        READY=1
        break
    fi
    sleep 2
done

if [ "$WATCHDOG_WAS_ACTIVE" -eq 1 ]; then
    systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
fi

if [ "$READY" -ne 1 ]; then
    echo "ERROR: Elementum did not start after dispatcher update" >&2
    exit 1
fi

trap - EXIT INT TERM
rm -rf "$TMP"

echo "=== RESULT ==="
echo "Backup: $BACKUP"
echo "Kodi: $(systemctl is-active kodi.service)"
echo "Elementum HTTP: 200"
echo "Watchdog: $(systemctl is-active rutracker-stack-watchdog.timer 2>/dev/null || true)"
echo "Kodi progressive modal dispatcher installed successfully."
