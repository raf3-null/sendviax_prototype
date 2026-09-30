#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)

if [ ! -x "$ROOT/backend/.venv/bin/python" ]; then
  echo 'ยังไม่มี Python environment'
  echo 'รัน: python3 -m venv backend/.venv && backend/.venv/bin/python -m pip install -r backend/requirements.txt'
  exit 1
fi

if [ ! -x "$ROOT/web/node_modules/.bin/next" ]; then
  echo 'ยังไม่มี Node dependencies'
  echo 'รัน: cd web && npm ci'
  exit 1
fi

# Always rebuild when the source is newer, so /download and the Relay UI cannot be stale.
if [ ! -f "$ROOT/web/.next/BUILD_ID" ] || [ -n "$(find "$ROOT/web/app" "$ROOT/web/package.json" "$ROOT/web/package-lock.json" "$ROOT/web/next.config.ts" -type f -newer "$ROOT/web/.next/BUILD_ID" -print -quit)" ]; then
  echo 'กำลัง build เว็บ Sendviax (รวมหน้า /download) ...'
  npm --prefix "$ROOT/web" run build
fi

backend/.venv/bin/python -m uvicorn app:app --app-dir "$ROOT/backend" --host 127.0.0.1 --port "${RELAY_PORT:-8000}" --no-access-log &
relay_pid=$!
BACKEND_ORIGIN="http://127.0.0.1:${RELAY_PORT:-8000}" npm --prefix "$ROOT/web" run start -- --port "${WEB_PORT:-3000}" &
web_pid=$!

cleanup() {
  kill "$web_pid" "$relay_pid" 2>/dev/null || true
  wait "$web_pid" "$relay_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 1
if ! curl -fsS "http://127.0.0.1:${RELAY_PORT:-8000}/healthz" >/dev/null; then
  echo 'Relay เริ่มทำงานไม่สำเร็จ'
  exit 1
fi

echo ''
echo 'Sendviax พร้อมใช้งาน'
echo "เว็บหลัก:       http://127.0.0.1:${WEB_PORT:-3000}/"
echo "หน้าดาวน์โหลด: http://127.0.0.1:${WEB_PORT:-3000}/download"
echo "Relay health:   http://127.0.0.1:${RELAY_PORT:-8000}/healthz"
echo ''
echo 'สำหรับทดสอบจากต่างเครือข่าย เปิดอีก Terminal แล้วรัน:'
echo "cloudflared tunnel --url http://127.0.0.1:${WEB_PORT:-3000} --no-autoupdate"
echo 'กด Ctrl+C เพื่อปิดเว็บและ Relay'

wait "$web_pid"
