#!/bin/sh
set -eu

SOURCE_COMMIT="1f2b3dfff1e39547d2df0d5d55ba89bf636e6b4d"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/${SOURCE_COMMIT}"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
TARGET="$ADDON/resources/site-packages/elementum/progressive_gui_dispatcher.py"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/storage/elementum-kodi-progressive-proxy-backup-${STAMP}"
TMP="$(mktemp -d /tmp/elementum-kodi-progressive-proxy.XXXXXX)"
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

mkdir -p "$BACKUP" "$(dirname "$TARGET")"

curl -fL --retry 3 --connect-timeout 20 \
  "$RAW_BASE/resources/site-packages/elementum/progressive_gui_dispatcher.py" \
  -o "$TMP/progressive_gui_dispatcher.py"

grep -Fq "class ProgressiveDialogProxy" "$TMP/progressive_gui_dispatcher.py"
grep -Fq "Progressive proxy creating DialogSelect on service thread" "$TMP/progressive_gui_dispatcher.py"
grep -Fq "ElementumRPCServer.Dialog_Select_Large_Progressive_Create" "$TMP/progressive_gui_dispatcher.py"

if grep -Fq "super(DialogSelect, window).doModal()" "$TMP/progressive_gui_dispatcher.py"; then
    echo "ERROR: old cross-thread DialogSelect implementation is still present" >&2
    exit 1
fi

python3 -m py_compile "$TMP/progressive_gui_dispatcher.py"

if systemctl is-active --quiet rutracker-stack-watchdog.timer; then
    WATCHDOG_WAS_ACTIVE=1
fi
systemctl stop rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
systemctl stop rutracker-stack-watchdog.service >/dev/null 2>&1 || true

if [ -f "$TARGET" ]; then
    cp -p "$TARGET" "$BACKUP/progressive_gui_dispatcher.py"
fi

echo "=== STOP KODI ==="
systemctl stop kodi.service
KODI_STOPPED=1

install -m 0644 "$TMP/progressive_gui_dispatcher.py" "$TARGET"
rm -f "$(dirname "$TARGET")"/__pycache__/progressive_gui_dispatcher*.pyc 2>/dev/null || true
sync

echo "=== START KODI ==="
systemctl reset-failed kodi.service >/dev/null 2>&1 || true
systemctl start kodi.service
KODI_STOPPED=0

READY=0
for i in $(seq 1 60); do
    code="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:65220/ 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
        READY=1
        break
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo "ERROR: Elementum did not start; restoring dispatcher backup" >&2
    systemctl stop kodi.service >/dev/null 2>&1 || true
    if [ -f "$BACKUP/progressive_gui_dispatcher.py" ]; then
        install -m 0644 "$BACKUP/progressive_gui_dispatcher.py" "$TARGET"
    fi
    systemctl reset-failed kodi.service >/dev/null 2>&1 || true
    systemctl start kodi.service >/dev/null 2>&1 || true
    exit 1
fi

if [ "$WATCHDOG_WAS_ACTIVE" -eq 1 ]; then
    systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
fi
trap - EXIT INT TERM
rm -rf "$TMP"

echo "=== RESULT ==="
echo "Backup: $BACKUP"
echo "Kodi: $(systemctl is-active kodi.service)"
echo "Elementum HTTP: 200"
echo "Watchdog: $(systemctl is-active rutracker-stack-watchdog.timer 2>/dev/null || true)"
grep -F "Progressive GUI main-thread proxy dispatcher installed" \
  /storage/.kodi/temp/kodi.log 2>/dev/null | tail -n 1 || true
echo "Kodi progressive main-thread proxy installed successfully."
