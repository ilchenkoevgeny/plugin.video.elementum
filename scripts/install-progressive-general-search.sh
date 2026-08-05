#!/bin/sh
set -eu

EXPECTED_SOURCE_COMMIT="be774920a6b4aea659cc6ab2a81a33eac105c9cc"
ARTIFACT_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/elementum/artifacts/linux_arm64"
TARGET="/storage/.kodi/userdata/addon_data/plugin.video.elementum/bin/linux_arm64/elementum"
ADDON_TARGET="/storage/.kodi/addons/plugin.video.elementum/resources/bin/linux_arm64/elementum"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="/storage/.update/elementum-progressive-general-search-${STAMP}"
BACKUP_DIR="/storage/elementum-progressive-general-search-backup-${STAMP}"

mkdir -p "$WORK_DIR" "$BACKUP_DIR" "$(dirname "$TARGET")"

restart_services() {
    systemctl reset-failed kodi.service >/dev/null 2>&1 || true
    systemctl start kodi.service >/dev/null 2>&1 || true
    systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
}

trap restart_services EXIT INT TERM

echo "=== WAIT FOR CORRECT ARM64 BUILD ==="
source_commit=""
attempt=0
while [ "$attempt" -lt 80 ]; do
    attempt=$((attempt + 1))
    source_commit="$(
        curl -fsSL --retry 2 --connect-timeout 10 --max-time 20 \
          "${ARTIFACT_BASE}/source-commit.txt?ts=$(date +%s)" 2>/dev/null \
          | tr -d '\r\n' || true
    )"

    if [ "$source_commit" = "$EXPECTED_SOURCE_COMMIT" ]; then
        echo "Correct build found: $source_commit"
        break
    fi

    echo "Build is not ready yet ($attempt/80). Published: ${source_commit:-none}"
    sleep 15
done

if [ "$source_commit" != "$EXPECTED_SOURCE_COMMIT" ]; then
    echo "ERROR: correct ARM64 build was not published within 20 minutes"
    echo "Expected:  $EXPECTED_SOURCE_COMMIT"
    echo "Published: ${source_commit:-none}"
    exit 1
fi

echo "=== DOWNLOAD ==="
curl -fL --retry 3 --connect-timeout 20 \
  "${ARTIFACT_BASE}/elementum?ts=$(date +%s)" \
  -o "$WORK_DIR/elementum"

curl -fL --retry 3 --connect-timeout 20 \
  "${ARTIFACT_BASE}/elementum.sha256?ts=$(date +%s)" \
  -o "$WORK_DIR/elementum.sha256"

chmod 0755 "$WORK_DIR/elementum"

if ! grep -Eq '^[0-9a-fA-F]{64}[[:space:]]+\*?elementum$' "$WORK_DIR/elementum.sha256"; then
    echo "ERROR: invalid checksum file"
    cat "$WORK_DIR/elementum.sha256"
    exit 1
fi

(
    cd "$WORK_DIR"
    sha256sum -c elementum.sha256
)

if [ -f "$TARGET" ]; then
    cp -p "$TARGET" "$BACKUP_DIR/elementum.userdata"
fi
if [ -f "$ADDON_TARGET" ]; then
    cp -p "$ADDON_TARGET" "$BACKUP_DIR/elementum.addon"
fi

echo "=== STOP KODI ==="
systemctl stop rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
systemctl stop rutracker-stack-watchdog.service >/dev/null 2>&1 || true
systemctl stop kodi.service

install -m 0755 "$WORK_DIR/elementum" "$TARGET"
if [ -f "$ADDON_TARGET" ]; then
    install -m 0755 "$WORK_DIR/elementum" "$ADDON_TARGET"
fi
sync

echo "=== START KODI ==="
systemctl reset-failed kodi.service >/dev/null 2>&1 || true
systemctl start kodi.service

ready=0
for i in $(seq 1 30); do
    code="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:65220/ || true)"
    if [ "$code" = "200" ]; then
        ready=1
        break
    fi
    sleep 1
done

if [ "$ready" -ne 1 ]; then
    echo "ERROR: Elementum did not start, restoring backup"
    systemctl stop kodi.service >/dev/null 2>&1 || true

    if [ -f "$BACKUP_DIR/elementum.userdata" ]; then
        install -m 0755 "$BACKUP_DIR/elementum.userdata" "$TARGET"
    fi
    if [ -f "$BACKUP_DIR/elementum.addon" ]; then
        install -m 0755 "$BACKUP_DIR/elementum.addon" "$ADDON_TARGET"
    fi

    systemctl start kodi.service >/dev/null 2>&1 || true
    exit 1
fi

systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
trap - EXIT INT TERM

echo "=== RESULT ==="
echo "Source commit: $source_commit"
echo "Backup: $BACKUP_DIR"
echo "Kodi: $(systemctl is-active kodi.service)"
echo "Elementum HTTP: 200"
echo "Watchdog: $(systemctl is-active rutracker-stack-watchdog.timer 2>/dev/null || true)"
echo "Progressive general-search binary installed successfully."
