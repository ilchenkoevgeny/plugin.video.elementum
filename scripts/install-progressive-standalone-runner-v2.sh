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
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="/tmp/elementum-standalone-runner-v2-${STAMP}"
BACKUP="/storage/elementum-standalone-runner-v2-backup-${STAMP}"
WATCHDOG_WAS_ACTIVE=0
INSTALLED=0

mkdir -p "$WORK" "$BACKUP" "$PYDIR" "$(dirname "$USER_BIN")" "$(dirname "$ADDON_BIN")"

check_contains() {
    file="$1"
    text="$2"
    label="$3"
    if ! grep -Fq "$text" "$file"; then
        echo "ERROR: validation failed: $label" >&2
        echo "File: $file" >&2
        exit 1
    fi
    echo "OK: $label"
}

restore_backup() {
    echo "=== RESTORE BACKUP ==="
    systemctl stop kodi.service >/dev/null 2>&1 || true

    [ ! -f "$BACKUP/elementum.userdata" ] || install -m 0755 "$BACKUP/elementum.userdata" "$USER_BIN"
    [ ! -f "$BACKUP/elementum.addon" ] || install -m 0755 "$BACKUP/elementum.addon" "$ADDON_BIN"

    for file in service.py rpc.py dialog_select.py progressive_gui_dispatcher.py kodi_progressive_runner.py; do
        [ ! -f "$BACKUP/$file" ] || install -m 0644 "$BACKUP/$file" "$PYDIR/$file"
    done

    rm -rf "$PYDIR/__pycache__" 2>/dev/null || true
    sync
    systemctl reset-failed kodi.service >/dev/null 2>&1 || true
    systemctl start kodi.service >/dev/null 2>&1 || true
}

cleanup() {
    if [ "$WATCHDOG_WAS_ACTIVE" -eq 1 ]; then
        systemctl start rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

echo "=== CHECK PUBLISHED BINARY ==="
source_commit="$(curl -fsSL --retry 3 --connect-timeout 20 "${ARTIFACT_BASE}/source-commit.txt?ts=$(date +%s)" | tr -d '\r\n')"
if [ "$source_commit" != "$EXPECTED_BINARY_COMMIT" ]; then
    echo "ERROR: wrong ARM64 artifact" >&2
    echo "Expected:  $EXPECTED_BINARY_COMMIT" >&2
    echo "Published: $source_commit" >&2
    exit 1
fi
echo "OK: binary source $source_commit"

echo "=== DOWNLOAD COMPLETE PYTHON SET ==="
for file in service.py rpc.py dialog_select.py progressive_gui_dispatcher.py kodi_progressive_runner.py; do
    echo "Downloading $file"
    curl -fL --retry 3 --connect-timeout 20 \
      "$PY_BASE/$file" \
      -o "$WORK/$file"
done

curl -fL --retry 3 --connect-timeout 20 \
  "${ARTIFACT_BASE}/elementum?ts=$(date +%s)" \
  -o "$WORK/elementum"
curl -fL --retry 3 --connect-timeout 20 \
  "${ARTIFACT_BASE}/elementum.sha256?ts=$(date +%s)" \
  -o "$WORK/elementum.sha256"
chmod 0755 "$WORK/elementum"

echo "=== VALIDATE DOWNLOADS ==="
check_contains "$WORK/service.py" "def run():" "service.run exists"
check_contains "$WORK/service.py" "install_progressive_gui_dispatcher" "service installs dispatcher"
check_contains "$WORK/rpc.py" "Dialog_Select_Large_Progressive_Create" "progressive RPC methods exist"
check_contains "$WORK/dialog_select.py" "Progressive Kodi runner requested" "DialogSelect launches RunScript"
check_contains "$WORK/dialog_select.py" "_bridge_attach(self)" "DialogSelect publishes bridge state"
check_contains "$WORK/progressive_gui_dispatcher.py" "standalone-runner mode installed" "dispatcher does not intercept show"
check_contains "$WORK/kodi_progressive_runner.py" "Progressive Kodi dialog opening" "standalone runner exists"

python3 -m py_compile \
  "$WORK/service.py" \
  "$WORK/rpc.py" \
  "$WORK/dialog_select.py" \
  "$WORK/progressive_gui_dispatcher.py" \
  "$WORK/kodi_progressive_runner.py"

(
    cd "$WORK"
    sha256sum -c elementum.sha256
)

echo "=== BACKUP CURRENT STATE ==="
[ ! -f "$USER_BIN" ] || cp -p "$USER_BIN" "$BACKUP/elementum.userdata"
[ ! -f "$ADDON_BIN" ] || cp -p "$ADDON_BIN" "$BACKUP/elementum.addon"
for file in service.py rpc.py dialog_select.py progressive_gui_dispatcher.py kodi_progressive_runner.py; do
    [ ! -f "$PYDIR/$file" ] || cp -p "$PYDIR/$file" "$BACKUP/$file"
done

echo "Backup: $BACKUP"

if systemctl is-active --quiet rutracker-stack-watchdog.timer; then
    WATCHDOG_WAS_ACTIVE=1
fi
systemctl stop rutracker-stack-watchdog.timer >/dev/null 2>&1 || true
systemctl stop rutracker-stack-watchdog.service >/dev/null 2>&1 || true

echo "=== STOP KODI ==="
systemctl stop kodi.service || true
sleep 2

echo "=== INSTALL ==="
install -m 0755 "$WORK/elementum" "$USER_BIN"
install -m 0755 "$WORK/elementum" "$ADDON_BIN"
for file in service.py rpc.py dialog_select.py progressive_gui_dispatcher.py kodi_progressive_runner.py; do
    install -m 0644 "$WORK/$file" "$PYDIR/$file"
done
rm -rf "$PYDIR/__pycache__" 2>/dev/null || true
sync
INSTALLED=1

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

bridge=0
if [ "$ready" -eq 1 ]; then
    for i in $(seq 1 30); do
        code="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:65222/health 2>/dev/null || true)"
        if [ "$code" = "200" ]; then
            bridge=1
            break
        fi
        sleep 1
    done
fi

if [ "$ready" -ne 1 ] || [ "$bridge" -ne 1 ]; then
    echo "ERROR: health check failed" >&2
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
echo "Python source: $PY_SOURCE_COMMIT"
echo "Backup: $BACKUP"
echo "Kodi: $(systemctl is-active kodi.service 2>/dev/null || true)"
echo "Elementum HTTP: 200"
echo "Progressive bridge HTTP: 200"
echo "Standalone Kodi progressive runner v2 installed successfully."
