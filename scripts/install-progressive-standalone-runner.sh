#!/bin/sh
set -eu

EXPECTED_BINARY_COMMIT="be774920a6b4aea659cc6ab2a81a33eac105c9cc"
PY_SOURCE_COMMIT="9254001fe08ab2536d40b87a1a0d9646734513c4"
ARTIFACT_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/elementum/artifacts/linux_arm64"
PY_BASE="https://raw.githubusercontent.com/ilchenkoevgeny/plugin.video.elementum/${PY_SOURCE_COMMIT}/resources/site-packages/elementum"

ADDON="/storage/.kodi/addons/plugin.video.elementum"
PYDIR="$ADDON/resources/site-packages/elementum"
USER_BIN="/storage/.kodi/userdata/addon_data/plugin.video.elementum/bin/linux_arm64/elementum"
ADDON_BIN="$ADDON/resources/bin/linux_arm64/elementum"
DISPATCHER="$PYDIR/progressive_gui_dispatcher.py"
RUNNER="$PYDIR/kodi_progressive_runner.py"
DIALOG="$PYDIR/dialog_select.py"
RPC="$PYDIR/rpc.py"
SERVICE="$PYDIR/service.py"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="/tmp/elementum-standalone-runner-${STAMP}"
BACKUP="/storage/elementum-standalone-runner-backup-${STAMP}"
WATCHDOG_WAS_ACTIVE=0
KODI_STOPPED=0

mkdir -p "$WORK" "$BACKUP" "$PYDIR" "$(dirname "$USER_BIN")" "$(dirname "$ADDON_BIN")"

restore_backup() {
    echo "=== RESTORE BACKUP ==="
    systemctl stop kodi.service >/dev/null 2>&1 || true

    [ ! -f "$BACKUP/elementum.userdata" ] || install -m 0755 "$BACKUP/elementum.userdata" "$USER_BIN"
    [ ! -f "$BACKUP/elementum.addon" ] || install -m 0755 "$BACKUP/elementum.addon" "$ADDON_BIN"
    [ ! -f "$BACKUP/progressive_gui_dispatcher.py" ] || install -m 0644 "$BACKUP/progressive_gui_dispatcher.py" "$DISPATCHER"
    [ ! -f "$BACKUP/kodi_progressive_runner.py" ] || install -m 0644 "$BACKUP/kodi_progressive_runner.py" "$RUNNER"

    rm -rf "$PYDIR/__pycache__" 2>/dev/null || true
    sync
    systemctl reset-failed kodi.service >/dev/null 2>&1 || true
    systemctl start kodi.service >/dev/null 2>&1 || true
}

cleanup() {
    if [ "$KODI_STOPPED" -eq 1 ]; then
        systemctl start kodi.service >/dev/null 2>&1 || true
    fi
    if [ "$WATCHDOG_WAS_ACTIVE" -eq 1 ]; then
        systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

echo "=== VALIDATE CURRENT PYTHON BASE ==="
for required in "$DIALOG" "$RPC" "$SERVICE"; do
    if [ ! -f "$required" ]; then
        echo "ERROR: missing $required" >&2
        exit 1
    fi
done

grep -Fq "Progressive Kodi runner requested" "$DIALOG"
grep -Fq "Dialog_Select_Large_Progressive_Create" "$RPC"
grep -Fq "install_progressive_gui_dispatcher" "$SERVICE"
grep -Fq '^def run():' "$SERVICE"

echo "=== CHECK PUBLISHED BINARY ==="
source_commit="$(curl -fsSL --retry 3 --connect-timeout 20 "${ARTIFACT_BASE}/source-commit.txt?ts=$(date +%s)" | tr -d '\r\n')"
if [ "$source_commit" != "$EXPECTED_BINARY_COMMIT" ]; then
    echo "ERROR: wrong ARM64 artifact" >&2
    echo "Expected:  $EXPECTED_BINARY_COMMIT" >&2
    echo "Published: $source_commit" >&2
    exit 1
fi

echo "=== DOWNLOAD ==="
curl -fL --retry 3 --connect-timeout 20 \
  "${ARTIFACT_BASE}/elementum?ts=$(date +%s)" \
  -o "$WORK/elementum"
curl -fL --retry 3 --connect-timeout 20 \
  "${ARTIFACT_BASE}/elementum.sha256?ts=$(date +%s)" \
  -o "$WORK/elementum.sha256"
curl -fL --retry 3 --connect-timeout 20 \
  "$PY_BASE/progressive_gui_dispatcher.py" \
  -o "$WORK/progressive_gui_dispatcher.py"
curl -fL --retry 3 --connect-timeout 20 \
  "$PY_BASE/kodi_progressive_runner.py" \
  -o "$WORK/kodi_progressive_runner.py"

chmod 0755 "$WORK/elementum"
grep -Fq "standalone-runner mode installed" "$WORK/progressive_gui_dispatcher.py"
grep -Fq "Progressive Kodi dialog opening" "$WORK/kodi_progressive_runner.py"
python3 -m py_compile "$WORK/progressive_gui_dispatcher.py" "$WORK/kodi_progressive_runner.py"
(
    cd "$WORK"
    sha256sum -c elementum.sha256
)

echo "=== BACKUP ==="
[ ! -f "$USER_BIN" ] || cp -p "$USER_BIN" "$BACKUP/elementum.userdata"
[ ! -f "$ADDON_BIN" ] || cp -p "$ADDON_BIN" "$BACKUP/elementum.addon"
[ ! -f "$DISPATCHER" ] || cp -p "$DISPATCHER" "$BACKUP/progressive_gui_dispatcher.py"
[ ! -f "$RUNNER" ] || cp -p "$RUNNER" "$BACKUP/kodi_progressive_runner.py"

if systemctl is-active --quiet rutracker-stack-watchdog.timer; then
    WATCHDOG_WAS_ACTIVE=1
fi

systemctl stop rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
systemctl stop rutracker-stack-watchdog.service >/dev/null 2>&1 || true

echo "=== STOP KODI ==="
systemctl stop kodi.service || true
KODI_STOPPED=1
sleep 2

echo "=== INSTALL ==="
install -m 0755 "$WORK/elementum" "$USER_BIN"
install -m 0755 "$WORK/elementum" "$ADDON_BIN"
install -m 0644 "$WORK/progressive_gui_dispatcher.py" "$DISPATCHER"
install -m 0644 "$WORK/kodi_progressive_runner.py" "$RUNNER"
rm -rf "$PYDIR/__pycache__" 2>/dev/null || true
sync

echo "=== START KODI ==="
systemctl reset-failed kodi.service >/dev/null 2>&1 || true
systemctl start kodi.service
KODI_STOPPED=0

ready=0
for i in $(seq 1 60); do
    code="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:65220/ 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
        ready=1
        break
    fi
    sleep 1
done

bridge=0
if [ "$ready" -eq 1 ]; then
    for i in $(seq 1 20); do
        code="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:65222/health 2>/dev/null || true)"
        if [ "$code" = "200" ]; then
            bridge=1
            break
        fi
        sleep 1
    done
fi

if [ "$ready" -ne 1 ] || [ "$bridge" -ne 1 ]; then
    echo "ERROR: post-install health check failed" >&2
    echo "Elementum HTTP: $([ "$ready" -eq 1 ] && echo 200 || echo 000)" >&2
    echo "Bridge HTTP: $([ "$bridge" -eq 1 ] && echo 200 || echo 000)" >&2
    restore_backup
    exit 1
fi

if [ "$WATCHDOG_WAS_ACTIVE" -eq 1 ]; then
    systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
fi

trap - EXIT INT TERM
rm -rf "$WORK"

echo "=== RESULT ==="
echo "Binary source: $source_commit"
echo "Backup: $BACKUP"
echo "Kodi: $(systemctl is-active kodi.service 2>/dev/null || true)"
echo "Elementum HTTP: 200"
echo "Progressive bridge HTTP: 200"
echo "Standalone Kodi progressive runner installed successfully."
