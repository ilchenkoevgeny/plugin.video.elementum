#!/bin/sh
set -eu

PY_SOURCE_COMMIT="131ebeeb71d43dd20b4201c36986e713993364b3"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/${PY_SOURCE_COMMIT}"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
PYDIR="$ADDON/resources/site-packages/elementum"
USER_BIN="/storage/.kodi/userdata/addon_data/plugin.video.elementum/bin/linux_arm64/elementum"
ADDON_BIN="$ADDON/resources/bin/linux_arm64/elementum"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="/tmp/elementum-stable-rollback-${STAMP}"
CURRENT_BACKUP="/storage/elementum-before-stable-rollback-${STAMP}"

mkdir -p "$WORK" "$CURRENT_BACKUP" "$PYDIR" "$(dirname "$USER_BIN")"

BIN_BACKUP=""
for candidate in $(ls -dt /storage/elementum-progressive-general-search-backup-* 2>/dev/null || true); do
    if [ -f "$candidate/elementum.userdata" ]; then
        BIN_BACKUP="$candidate"
        break
    fi
done

if [ -z "$BIN_BACKUP" ]; then
    echo "ERROR: pre-upgrade Elementum backup was not found" >&2
    echo "Expected: /storage/elementum-progressive-general-search-backup-*/elementum.userdata" >&2
    exit 1
fi

echo "=== SOURCE BACKUP ==="
echo "$BIN_BACKUP"

echo "=== DOWNLOAD STABLE PYTHON FILES ==="
for file in service.py rpc.py dialog_select.py progressive_gui_dispatcher.py; do
    curl -fL --retry 3 --connect-timeout 20 \
      "$RAW_BASE/resources/site-packages/elementum/$file" \
      -o "$WORK/$file"
done

grep -q '^def run():' "$WORK/service.py"
grep -q 'Progressive GUI dispatcher installed' "$WORK/progressive_gui_dispatcher.py"
python3 -m py_compile \
  "$WORK/service.py" \
  "$WORK/rpc.py" \
  "$WORK/dialog_select.py" \
  "$WORK/progressive_gui_dispatcher.py"

for file in service.py rpc.py dialog_select.py progressive_gui_dispatcher.py; do
    if [ -f "$PYDIR/$file" ]; then
        cp -p "$PYDIR/$file" "$CURRENT_BACKUP/$file"
    fi
done
if [ -f "$USER_BIN" ]; then
    cp -p "$USER_BIN" "$CURRENT_BACKUP/elementum.userdata"
fi
if [ -f "$ADDON_BIN" ]; then
    cp -p "$ADDON_BIN" "$CURRENT_BACKUP/elementum.addon"
fi

echo "=== STOP KODI ==="
systemctl stop rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
systemctl stop rutracker-stack-watchdog.service >/dev/null 2>&1 || true
systemctl stop kodi.service || true
sleep 2

echo "=== RESTORE PRE-UPGRADE BINARY ==="
install -m 0755 "$BIN_BACKUP/elementum.userdata" "$USER_BIN"
if [ -f "$BIN_BACKUP/elementum.addon" ]; then
    install -m 0755 "$BIN_BACKUP/elementum.addon" "$ADDON_BIN"
else
    install -m 0755 "$BIN_BACKUP/elementum.userdata" "$ADDON_BIN"
fi

echo "=== RESTORE STABLE PYTHON ==="
for file in service.py rpc.py dialog_select.py progressive_gui_dispatcher.py; do
    install -m 0644 "$WORK/$file" "$PYDIR/$file"
done
rm -rf "$PYDIR/__pycache__" 2>/dev/null || true
sync

echo "=== START KODI ==="
systemctl reset-failed kodi.service >/dev/null 2>&1 || true
systemctl start kodi.service

ready=0
for i in $(seq 1 60); do
    code="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:65220/ 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
        ready=1
        break
    fi
    sleep 1
done

systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true

echo "=== RESULT ==="
echo "Current-state backup: $CURRENT_BACKUP"
echo "Restored binary backup: $BIN_BACKUP"
echo "Kodi: $(systemctl is-active kodi.service 2>/dev/null || true)"
echo "Elementum HTTP: $([ "$ready" -eq 1 ] && echo 200 || echo 000)"
echo "Watchdog: $(systemctl is-active rutracker-stack-watchdog.timer 2>/dev/null || true)"

if [ "$ready" -ne 1 ]; then
    echo "ERROR: Elementum did not start after rollback" >&2
    tail -n 120 /storage/.kodi/temp/kodi.log >&2 || true
    exit 1
fi

echo "Stable Elementum state restored successfully."
