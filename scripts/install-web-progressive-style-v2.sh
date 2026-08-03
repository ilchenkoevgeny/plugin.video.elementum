#!/bin/sh

set -eu

SOURCE_COMMIT="bf97f76ae1b8b01d97509e4f5f56b1602ca7ae32"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/$SOURCE_COMMIT"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
INDEX_TARGET="$ADDON/resources/web/index.html"
STYLE_TARGET="$ADDON/resources/web/static/js/web-progressive-style-v2.js"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/storage/elementum-web-style-v2-backup-$STAMP"
TMP="$(mktemp -d /tmp/elementum-web-style-v2.XXXXXX)"
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
fetch_file "resources/web/index.html" "$TMP/index.html"
fetch_file "resources/web/static/js/web-progressive-style-v2.js" "$TMP/web-progressive-style-v2.js"

echo "=== VALIDATE ==="
grep -Fq "/web/static/js/web-progressive-style-v2.js?v=1" "$TMP/index.html"
grep -Fq "Elementum Web progressive style v2 is active" "$TMP/web-progressive-style-v2.js"

if [ ! -f "$INDEX_TARGET" ]; then
    echo "ERROR: не найден $INDEX_TARGET" >&2
    exit 1
fi

mkdir -p "$BACKUP/resources/web/static/js" "$(dirname "$STYLE_TARGET")"
cp -p "$INDEX_TARGET" "$BACKUP/resources/web/index.html"
if [ -f "$STYLE_TARGET" ]; then
    cp -p "$STYLE_TARGET" "$BACKUP/resources/web/static/js/web-progressive-style-v2.js"
fi

echo "=== INSTALL ==="
systemctl stop kodi
KODI_STOPPED=1
cp "$TMP/index.html" "$INDEX_TARGET"
cp "$TMP/web-progressive-style-v2.js" "$STYLE_TARGET"
chmod 0644 "$INDEX_TARGET" "$STYLE_TARGET"
systemctl start kodi
KODI_STOPPED=0

echo "=== WAIT FOR ELEMENTUM ==="
READY=0
ATTEMPT=0
while [ "$ATTEMPT" -lt 60 ]; do
    ATTEMPT=$((ATTEMPT + 1))
    if curl -sS --max-time 3 \
        "http://127.0.0.1:65220/web/static/js/web-progressive-style-v2.js?v=1" \
        2>/dev/null | grep -Fq "Elementum Web progressive style v2 is active"; then
        READY=1
        break
    fi
    sleep 2
done

echo "=== RESULT ==="
echo "Backup: $BACKUP"
echo "Style v2 served: $READY"

if [ "$READY" -ne 1 ]; then
    echo "ERROR: Elementum не отдаёт новый style v2 script" >&2
    exit 1
fi

echo "Web progressive style v2 installed successfully."
echo "В браузере выполните Ctrl+F5."
