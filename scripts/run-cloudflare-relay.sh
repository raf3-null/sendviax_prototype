#!/bin/sh
# Start the Docker relay, local Next.js proxy, then expose it through Cloudflare.
# Named mode serves the configured hostname (for example test.sendviax.com).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WEB_PORT=${WEB_PORT:-3000}
TUNNEL_NAME=${TUNNEL_NAME:-sendviax-test}
MODE=${1:-named}
WEB_PID=''

cleanup() {
  if [ -n "$WEB_PID" ]; then
    kill "$WEB_PID" 2>/dev/null || true
    wait "$WEB_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

case "$MODE" in
  named|quick) ;;
  *)
    echo 'Usage: sh scripts/run-cloudflare-relay.sh [named|quick]'
    echo 'named: serves the configured Cloudflare hostname (default)'
    echo 'quick: creates a temporary trycloudflare.com URL'
    exit 2
    ;;
esac

command -v cloudflared >/dev/null || {
  echo 'cloudflared is not installed or not on PATH.' >&2
  exit 1
}

if lsof -nP -iTCP:"$WEB_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port $WEB_PORT is already in use. Stop that web server first, or use WEB_PORT=<port>." >&2
  exit 1
fi

"$ROOT/scripts/relay-stack.sh" up

if [ ! -f "$ROOT/web/.next/BUILD_ID" ]; then
  echo 'Building web app ...'
  npm --prefix "$ROOT/web" run build
fi

BACKEND_ORIGIN=http://127.0.0.1:8000 \
  npm --prefix "$ROOT/web" run start -- --port "$WEB_PORT" &
WEB_PID=$!

for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS "http://127.0.0.1:$WEB_PORT/api/healthz" >/dev/null; then
    break
  fi
  sleep 1
done

curl -fsS "http://127.0.0.1:$WEB_PORT/api/healthz" >/dev/null || {
  echo 'Web proxy did not become ready. See the output above.' >&2
  exit 1
}

echo ''
echo "Local web proxy: http://127.0.0.1:$WEB_PORT"
echo 'Relay API remains bound to localhost; only the web proxy is exposed.'

if [ "$MODE" = quick ]; then
  echo 'Starting temporary Quick Tunnel. Copy its trycloudflare.com URL into test clients.'
  cloudflared tunnel --url "http://127.0.0.1:$WEB_PORT" --no-autoupdate
  exit $?
fi

echo "Starting named tunnel: $TUNNEL_NAME"
echo 'Expected public address: https://test.sendviax.com'
cloudflared tunnel run "$TUNNEL_NAME"
