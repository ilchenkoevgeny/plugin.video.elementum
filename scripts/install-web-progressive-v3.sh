#!/bin/sh

set -eu

SOURCE_COMMIT="32cb90aca9ee49f24f41fd80f01bf7b8aeacaf49"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/$SOURCE_COMMIT"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
INDEX_TARGET="$ADDON/resources/web/index.html"
SCRIPT_TARGET="$ADDON/resources/web/static/js/web-progressive-v3.js"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/storage/elementum-web-progressive-v3-backup-$STAMP"
TMP="$(mktemp -d /tmp/elementum-web-progressive-v3.XXXXXX)"

cleanup() {
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
fetch_file "resources/web/static/js/web-progressive-v3.js" "$TMP/web-progressive-v3.js"

echo "=== VALIDATE ==="
grep -Fq "/web/static/js/web-progressive-v3.js?v=3" "$TMP/index.html"
grep -Fq "Elementum progressive torrent selector v3 is active" "$TMP/web-progressive-v3.js"
grep -Fq "elementum-progressive-quality" "$TMP/web-progressive-v3.js"
grep -Fq "COLOR(?:\\s+|=)" "$TMP/web-progressive-v3.js"

if [ ! -f "$INDEX_TARGET" ]; then
    echo "ERROR: не найден $INDEX_TARGET" >&2
    exit 1
fi

mkdir -p "$BACKUP/resources/web/static/js" "$(dirname "$SCRIPT_TARGET")"
cp -p "$INDEX_TARGET" "$BACKUP/resources/web/index.html"

for old_script in \
    "$ADDON/resources/web/static/js/web-progressive.js" \
    "$ADDON/resources/web/static/js/web-progressive-style-v2.js" \
    "$SCRIPT_TARGET"; do
    if [ -f "$old_script" ]; then
        cp -p "$old_script" "$BACKUP/resources/web/static/js/$(basename "$old_script")"
    fi
done

echo "=== INSTALL ==="
cp "$TMP/index.html" "$INDEX_TARGET"
cp "$TMP/web-progressive-v3.js" "$SCRIPT_TARGET"
chmod 0644 "$INDEX_TARGET" "$SCRIPT_TARGET"
sync

echo "=== VERIFY SERVED FILES ==="
INDEX_OK=0
SCRIPT_OK=0
ATTEMPT=0
while [ "$ATTEMPT" -lt 20 ]; do
    ATTEMPT=$((ATTEMPT + 1))

    if curl -sS --max-time 3 "http://127.0.0.1:65220/web/" 2>/dev/null \
        | grep -Fq "/web/static/js/web-progressive-v3.js?v=3"; then
        INDEX_OK=1
    fi

    if curl -sS --max-time 3 \
        "http://127.0.0.1:65220/web/static/js/web-progressive-v3.js?v=3" \
        2>/dev/null | grep -Fq "Elementum progressive torrent selector v3 is active"; then
        SCRIPT_OK=1
    fi

    if [ "$INDEX_OK" -eq 1 ] && [ "$SCRIPT_OK" -eq 1 ]; then
        break
    fi

    sleep 1
done

echo "=== RESULT ==="
echo "Backup: $BACKUP"
echo "Index v3 served: $INDEX_OK"
echo "Script v3 served: $SCRIPT_OK"

if [ "$INDEX_OK" -ne 1 ] || [ "$SCRIPT_OK" -ne 1 ]; then
    echo "ERROR: Elementum не отдаёт Web UI v3" >&2
    exit 1
fi

echo "Web progressive v3 installed successfully."
echo "Kodi не перезапускался. В браузере выполните Ctrl+F5."
