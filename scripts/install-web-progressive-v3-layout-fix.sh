#!/bin/sh

set -eu

SOURCE_COMMIT="67b1e8febb281f12bb81541033c30e3b1864b2ae"
RAW_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/$SOURCE_COMMIT"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
TARGET="$ADDON/resources/web/static/js/web-progressive-v3.js"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/storage/elementum-web-progressive-v3-layout-backup-$STAMP"
TMP="$(mktemp -d /tmp/elementum-web-v3-layout.XXXXXX)"

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
fetch_file \
    "resources/web/static/js/web-progressive-v3.js" \
    "$TMP/web-progressive-v3.js"
fetch_file \
    "resources/web/static/js/web-progressive-v3-layout-fix.js" \
    "$TMP/web-progressive-v3-layout-fix.js"

echo "=== VALIDATE ==="
grep -Fq "Elementum progressive torrent selector v3 is active" \
    "$TMP/web-progressive-v3.js"
grep -Fq "Elementum progressive v3 layout fix is active" \
    "$TMP/web-progressive-v3-layout-fix.js"
grep -Fq "flex:0 0 auto!important" \
    "$TMP/web-progressive-v3-layout-fix.js"

if [ ! -f "$TARGET" ]; then
    echo "ERROR: не найден $TARGET" >&2
    exit 1
fi

mkdir -p "$BACKUP/resources/web/static/js"
cp -p "$TARGET" "$BACKUP/resources/web/static/js/web-progressive-v3.js"

cat \
    "$TMP/web-progressive-v3.js" \
    "$TMP/web-progressive-v3-layout-fix.js" \
    > "$TMP/web-progressive-v3-combined.js"

echo "=== INSTALL ==="
cp "$TMP/web-progressive-v3-combined.js" "$TARGET"
chmod 0644 "$TARGET"
sync

echo "=== VERIFY ==="
READY=0
ATTEMPT=0
while [ "$ATTEMPT" -lt 20 ]; do
    ATTEMPT=$((ATTEMPT + 1))

    if curl -sS --max-time 3 \
        "http://127.0.0.1:65220/web/static/js/web-progressive-v3.js?v=3" \
        2>/dev/null | grep -Fq \
        "Elementum progressive v3 layout fix is active"; then
        READY=1
        break
    fi

    sleep 1
done

echo "=== RESULT ==="
echo "Backup: $BACKUP"
echo "Layout fix served: $READY"

if [ "$READY" -ne 1 ]; then
    echo "ERROR: Elementum не отдаёт исправленный v3 script" >&2
    exit 1
fi

echo "Web progressive v3 layout fix installed successfully."
echo "Kodi не перезапускался. В браузере выполните Ctrl+F5."
