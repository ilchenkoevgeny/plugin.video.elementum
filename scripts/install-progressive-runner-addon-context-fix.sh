#!/bin/sh
set -eu

SOURCE_COMMIT="823af8200df2862b20c1f0d1acda9114ac70e8f1"
SOURCE_URL="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/${SOURCE_COMMIT}/resources/site-packages/elementum/kodi_progressive_runner.py"
TARGET="/storage/.kodi/addons/plugin.video.elementum/resources/site-packages/elementum/kodi_progressive_runner.py"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${TARGET}.backup-${STAMP}"
TEMP="/tmp/kodi_progressive_runner.py.${STAMP}"

if [ ! -f "$TARGET" ]; then
    echo "ERROR: runner target does not exist: $TARGET" >&2
    exit 1
fi

curl -fL --retry 3 --connect-timeout 20 "$SOURCE_URL" -o "$TEMP"

grep -Fq "xbmcaddon.Addon(ADDON_ID)" "$TEMP"
grep -Fq "class ProgressiveKodiDialog" "$TEMP"
if grep -Fq "from elementum." "$TEMP"; then
    echo "ERROR: fixed runner still imports Elementum package modules" >&2
    exit 1
fi
python3 -m py_compile "$TEMP"

cp -p "$TARGET" "$BACKUP"
install -m 0644 "$TEMP" "$TARGET"
rm -f "$TEMP"
rm -rf "$(dirname "$TARGET")/__pycache__" 2>/dev/null || true
sync

echo "Runner source: $SOURCE_COMMIT"
echo "Backup: $BACKUP"
echo "Standalone Kodi runner addon-context fix installed successfully."
