# FastAPI backend on DigitalOcean; PostgreSQL/Redis metadata and R2 ciphertext storage

Product scope: [PROJECT_SCOPE.md](../PROJECT_SCOPE.md). This product directory is scaffolding, not a claim that the platform or service is complete.

REST/WSS coordinate access and status; R2 is the temporary ciphertext data path. Read [protocol](../protocol/README.md) before implementing network/security behavior. No production service is claimed here.

Implemented experiment: `app.py` is a single-worker RAM-only FastAPI relay, not the planned PostgreSQL/Redis/R2 stack. Legacy `/api/test` behavior remains available. Approved web phases 1–5 add `/api/web` one-time pairing, confirmation, heartbeat/device names and sender receipts. See [endpoint contract](../protocol/web-pair-v1.md) and [web test results](../docs/web-phases-1-5-validation.md). Run `backend/.venv/bin/python -m uvicorn app:app --app-dir backend --host 127.0.0.1 --port 8000 --no-access-log` from the repository root.

Local infrastructure (step 1): `sh scripts/relay-stack.sh init` then `sh scripts/relay-stack.sh up`. See [Thai setup guide](../docs/relay-local-stack-th.md). Compose starts the existing single-worker API plus PostgreSQL/Redis infrastructure; the API is still RAM-only. Standalone cleanup is deliberately disabled until durable storage is implemented.
