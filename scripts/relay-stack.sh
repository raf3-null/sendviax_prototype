#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STACK="$ROOT/infra/relay"
ACTION=${1:-help}
if [ "$ACTION" = init ]; then
  python3 - "$STACK/.env" <<'PY'
import os, secrets, sys
path = sys.argv[1]
try:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
except FileExistsError:
    print('Existing .env preserved.')
else:
    with os.fdopen(fd, 'w') as f:
        f.write('RELAY_PORT=8000\nPOSTGRES_PASSWORD=' + secrets.token_hex(32) + '\n')
    print('Created private .env; password is not printed.')
PY
  exit 0
fi
case "$ACTION" in
  up|down|status|logs|check) ;;
  *) echo 'Usage: sh scripts/relay-stack.sh init|check|up|status|logs|down'; exit 0 ;;
esac
[ -f "$STACK/.env" ] || { echo 'Run: sh scripts/relay-stack.sh init' >&2; exit 1; }
command -v docker >/dev/null || { echo 'Docker with Compose v2 is required.' >&2; exit 1; }
set -- --env-file "$STACK/.env" -f "$STACK/compose.yaml"
case "$ACTION" in
  check) docker compose "$@" config --quiet ;;
  up) docker compose "$@" up --build --detach --wait ;;
  down) docker compose "$@" down ;;
  status) docker compose "$@" ps ;;
  logs) docker compose "$@" logs --tail 80 api ;;
esac
