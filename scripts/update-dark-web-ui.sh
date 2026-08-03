#!/bin/sh
set -eu

REPOSITORY="ilchenkoevgeny/plugin.video.elementum"
BRANCH="feature/progressive-results"
ADDON="/storage/.kodi/addons/plugin.video.elementum"
STAMP="$(date +%Y%m%d-%H%M%S)"
UPDATE_DIR="/storage/elementum-web-update-$STAMP"
ARCHIVE="$UPDATE_DIR/plugin.zip"
EXTRACT_DIR="$UPDATE_DIR/plugin"
WEB_SRC="$EXTRACT_DIR/plugin.video.elementum-feature-progressive-results/resources/web"

mkdir -p "$UPDATE_DIR" "$EXTRACT_DIR"

echo "=== DOWNLOAD WEB UI ==="
curl -fL --retry 3 --connect-timeout 20 \
  "https://github.com/$REPOSITORY/archive/refs/heads/$BRANCH.zip" \
  -o "$ARCHIVE"

unzip -oq "$ARCHIVE" -d "$EXTRACT_DIR"

if [ ! -d "$WEB_SRC" ]; then
    echo "ERROR: в архиве не найден resources/web"
    exit 1
fi

if [ ! -d "$ADDON/resources/web" ]; then
    echo "ERROR: не найден установленный Web UI: $ADDON/resources/web"
    exit 1
fi

if [ ! -f "$WEB_SRC/dark-search-fix.css" ]; then
    echo "ERROR: в сборке отсутствует dark-search-fix.css"
    exit 1
fi

if ! grep -q 'dark-search-fix.css' "$WEB_SRC/index.html"; then
    echo "ERROR: index.html не подключает dark-search-fix.css"
    exit 1
fi

echo "=== STOP KODI ==="
systemctl stop kodi
trap 'systemctl start kodi >/dev/null 2>&1 || true' EXIT
sleep 3

echo "=== BACKUP ==="
cp -a "$ADDON/resources/web" "$UPDATE_DIR/web.bak"

echo "=== INSTALL ==="
rm -rf "$ADDON/resources/web"
mkdir -p "$ADDON/resources/web"
cp -a "$WEB_SRC/." "$ADDON/resources/web/"

echo "=== START KODI ==="
systemctl start kodi
trap - EXIT
sleep 8

echo "=== RESULT ==="
ls -l \
  "$ADDON/resources/web/dark-search-fix.css" \
  "$ADDON/resources/web/index.html"

grep -o 'dark-search-fix.css' "$ADDON/resources/web/index.html" | head -n 1
sha256sum "$ADDON/resources/web/dark-search-fix.css"

echo "Backup: $UPDATE_DIR/web.bak"
echo "Готово. Обновите Web UI с принудительной очисткой кэша: Ctrl+F5."
