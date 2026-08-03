#!/bin/sh

set -eu

SOURCE_COMMIT="e19a8aae44b44ad5f562f35b76cc1125f6fb91b2"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/$SOURCE_COMMIT"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
DIALOG_TARGET="$ADDON/resources/site-packages/elementum/dialog_select.py"
INDEX_TARGET="$ADDON/resources/web/index.html"
JS_TARGET="$ADDON/resources/web/static/js/web-progressive.js"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/storage/elementum-web-progressive-backup-$STAMP"
TMP="$(mktemp -d /tmp/elementum-web-progressive.XXXXXX)"
KODI_STOPPED=0

cleanup() {
    if [ "$KODI_STOPPED" -eq 1 ]; then
        systemctl start kodi >/dev/null 2>&1 || true
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
fetch_file \
    "resources/site-packages/elementum/dialog_select.py" \
    "$TMP/dialog_select.py"
fetch_file \
    "resources/web/index.html" \
    "$TMP/index.html"
fetch_file \
    "resources/web/static/js/web-progressive.js" \
    "$TMP/web-progressive.js"

echo "=== VALIDATE ==="
python3 -m py_compile "$TMP/dialog_select.py"
grep -Fq "Elementum Web progressive bridge listening" "$TMP/dialog_select.py"
grep -Fq "Elementum progressive torrent selector for Web UI is active" "$TMP/web-progressive.js"
grep -Fq "/web/static/js/web-progressive.js?v=1" "$TMP/index.html"

for required in "$DIALOG_TARGET" "$INDEX_TARGET"; do
    if [ ! -f "$required" ]; then
        echo "ERROR: не найден $required" >&2
        exit 1
    fi
done

mkdir -p "$BACKUP/resources/site-packages/elementum"
mkdir -p "$BACKUP/resources/web/static/js"
mkdir -p "$(dirname "$JS_TARGET")"

cp -p "$DIALOG_TARGET" "$BACKUP/resources/site-packages/elementum/dialog_select.py"
cp -p "$INDEX_TARGET" "$BACKUP/resources/web/index.html"
if [ -f "$JS_TARGET" ]; then
    cp -p "$JS_TARGET" "$BACKUP/resources/web/static/js/web-progressive.js"
fi

echo "=== INSTALL ==="
systemctl stop kodi
KODI_STOPPED=1

cp "$TMP/dialog_select.py" "$DIALOG_TARGET"
cp "$TMP/index.html" "$INDEX_TARGET"
cp "$TMP/web-progressive.js" "$JS_TARGET"
chmod 0644 "$DIALOG_TARGET" "$INDEX_TARGET" "$JS_TARGET"

systemctl start kodi
KODI_STOPPED=0

echo "=== WAIT FOR SERVICES ==="
BRIDGE_READY=0
ELEMENTUM_READY=0
ATTEMPT=0
while [ "$ATTEMPT" -lt 60 ]; do
    ATTEMPT=$((ATTEMPT + 1))

    if curl -sS --max-time 2 \
        http://127.0.0.1:65222/health \
        2>/dev/null | grep -Fq '"status": "ok"'; then
        BRIDGE_READY=1
    fi

    if curl -sS --max-time 2 \
        http://127.0.0.1:65220/web/static/js/web-progressive.js?v=1 \
        2>/dev/null | grep -Fq 'Elementum progressive torrent selector'; then
        ELEMENTUM_READY=1
    fi

    if [ "$BRIDGE_READY" -eq 1 ] && [ "$ELEMENTUM_READY" -eq 1 ]; then
        break
    fi

    sleep 2
done

echo "=== RESULT ==="
echo "Backup: $BACKUP"
echo "Bridge ready: $BRIDGE_READY"
echo "Web script served: $ELEMENTUM_READY"

if [ "$BRIDGE_READY" -ne 1 ]; then
    echo "ERROR: Web progressive bridge did not start on port 65222" >&2
    grep -E \
        'Web progressive bridge|dialog_select|Traceback' \
        /storage/.kodi/temp/kodi.log | tail -n 100 >&2 || true
    exit 1
fi

if [ "$ELEMENTUM_READY" -ne 1 ]; then
    echo "ERROR: Elementum does not serve web-progressive.js" >&2
    exit 1
fi

echo "Web progressive selector installed successfully."
echo "Open Elementum Web UI and perform a hard refresh (Ctrl+F5)."
