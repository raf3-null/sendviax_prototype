"""Single-process, memory-only test-v0 relay. Never run multiple workers."""
import asyncio
import base64
import re
import secrets
import time
import unicodedata
from threading import Lock
from contextlib import asynccontextmanager
from uuid import UUID

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse

MAX_BODY = 10 * 1024 * 1024
MAX_CIPHER = 7 * 1024 * 1024 + 4096
rooms = {}
rates = {}
pair_lock = Lock()


def fail(status, code):
    raise HTTPException(status, code)


def cleanup():
    now = time.time()
    for sid, room in list(rooms.items()):
        if room['expires_at'] <= now or (room.get('pairing') == 'pending' and room['invite_expires_at'] <= now):
            del rooms[sid]
        else:
            for tid, item in list(room['items'].items()):
                if item['expires_at'] <= now:
                    if 'receipts' in room:
                        room['receipts'][tid]['status'] = 'expired'
                    del room['items'][tid]
    for key, entry in list(rates.items()):
        if entry[0] + 60 <= now:
            del rates[key]


def rate(key, limit):
    now = time.time()
    start, count = rates.get(key, (now, 0))
    if start + 60 <= now:
        start, count = now, 0
    if count >= limit:
        fail(429, 'rate_limited')
    rates[key] = (start, count + 1)


async def reaper():
    while True:
        await asyncio.sleep(1)
        cleanup()


@asynccontextmanager
async def lifespan(app):
    task = asyncio.create_task(reaper())
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
    rooms.clear()
    rates.clear()


app = FastAPI(title='Sendviax test-v0', lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None)


class BodyLimit:
    def __init__(self, app):
        self.app = app
        self.active = 0

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope, receive, send)
        if self.active >= 8:
            return await JSONResponse({'error': 'capacity'}, 503)(scope, receive, send)
        self.active += 1
        try:
            chunks, total = [], 0
            while True:
                message = await asyncio.wait_for(receive(), 20)
                if message['type'] == 'http.disconnect':
                    return
                total += len(message.get('body', b''))
                if total > MAX_BODY:
                    return await JSONResponse({'error': 'too_large'}, 413)(scope, receive, send)
                chunks.append(message.get('body', b''))
                if not message.get('more_body'):
                    break
            delivered = False
            async def replay():
                nonlocal delivered
                if not delivered:
                    delivered = True
                    return {'type': 'http.request', 'body': b''.join(chunks), 'more_body': False}
                return await receive()
            await self.app(scope, replay, send)
        except asyncio.TimeoutError:
            await JSONResponse({'error': 'request_timeout'}, 408)(scope, receive, send)
        finally:
            self.active -= 1


app.add_middleware(BodyLimit)


@app.middleware('http')
async def no_store(request, call_next):
    response = await call_next(request)
    response.headers['Cache-Control'] = 'no-store'
    return response


@app.exception_handler(HTTPException)
async def error(request, exc):
    return JSONResponse({'error': exc.detail}, exc.status_code, headers={'Cache-Control': 'no-store'})


async def body(request):
    try:
        value = await request.json()
    except Exception:
        fail(400, 'invalid_request')
    if not isinstance(value, dict):
        fail(400, 'invalid_request')
    return value


def auth(request):
    cleanup()
    token = request.headers.get('authorization', '')
    if not re.fullmatch(r'Bearer [A-Za-z0-9_-]{43}', token):
        fail(401, 'unauthorized')
    for room in rooms.values():
        for role in ('owner', 'peer'):
            if secrets.compare_digest(token[7:], room[role]):
                rate(room['session_id'] + role, 120)
                return room, role
    fail(401, 'unauthorized')


def decode(value, exact=None):
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', value):
        fail(400, 'invalid_request')
    try:
        raw = base64.urlsafe_b64decode(value + '=' * (-len(value) % 4))
    except Exception:
        fail(400, 'invalid_request')
    if base64.urlsafe_b64encode(raw).decode().rstrip('=') != value or (exact and len(raw) != exact):
        fail(400, 'invalid_request')
    return raw


@app.get('/healthz')
async def health():
    return JSONResponse({'status': 'ok', 'protocol': 'test-v0', 'storage': 'memory'}, headers={'Cache-Control': 'no-store'})


@app.post('/api/test/sessions', status_code=201)
async def create(request: Request):
    cleanup()
    rate('create', 10)
    value = await body(request)
    sid = value.get('session_id')
    if set(value) != {'session_id'} or not isinstance(sid, str) or not re.fullmatch('[0-9a-f]{32}', sid):
        fail(400, 'invalid_request')
    if sid in rooms:
        fail(409, 'duplicate')
    if len(rooms) >= 32:
        fail(503, 'capacity')
    room = {'session_id': sid, 'owner': secrets.token_urlsafe(32), 'peer': secrets.token_urlsafe(32),
            'expires_at': int(time.time()) + 900, 'items': {}, 'seen': set()}
    rooms[sid] = room
    return JSONResponse({'owner_token': room['owner'], 'peer_token': room['peer'], 'expires_at': room['expires_at']}, 201, headers={'Cache-Control': 'no-store'})


@app.get('/api/test/session')
async def session(request: Request):
    room, role = auth(request)
    return JSONResponse({'session_id': room['session_id'], 'role': role, 'expires_at': room['expires_at']}, headers={'Cache-Control': 'no-store'})


@app.post('/api/test/transfers', status_code=201)
async def put(request: Request):
    value = await body(request)
    room, role = auth(request)
    require_confirmed(room)
    rate(room['session_id'] + role + 'send', 30)
    fields = {'version', 'id', 'session_id', 'sender', 'expires_at', 'salt', 'nonce', 'ciphertext'}
    if set(value) != fields or value.get('version') != 'test-v0':
        fail(400, 'invalid_request')
    try:
        uid = UUID(value['id'], version=4)
        if str(uid) != value['id']:
            raise ValueError()
    except (ValueError, TypeError, AttributeError):
        fail(400, 'invalid_request')
    if value['session_id'] != room['session_id'] or value['sender'] != role:
        fail(403, 'forbidden')
    expires = value['expires_at']
    if type(expires) is not int or expires <= time.time() or expires > min(room['expires_at'], int(time.time()) + 300):
        fail(400, 'invalid_request')
    if value['id'] in room['seen']:
        fail(409, 'duplicate')
    if len(room['seen']) >= 256:
        fail(429, 'rate_limited')
    decode(value['salt'], 32)
    decode(value['nonce'], 12)
    size = len(decode(value['ciphertext']))
    if size < 16 or size > MAX_CIPHER:
        fail(413, 'too_large')
    # Account actual retained encoded string sizes, not just decoded bytes.
    stored_size = sum(len(x['ciphertext']) for x in room['items'].values())
    global_size = sum(len(x['ciphertext']) for r in rooms.values() for x in r['items'].values())
    if stored_size + len(value['ciphertext']) > 32 * 1024 * 1024 or global_size + len(value['ciphertext']) > 128 * 1024 * 1024:
        fail(503, 'capacity')
    room['seen'].add(value['id'])
    room['items'][value['id']] = value
    if 'receipts' in room:
        room['receipts'][value['id']] = {'id': value['id'], 'sender': role, 'status': 'available',
                                      'expires_at': expires, 'completed_at': None}
    return {'id': value['id'], 'status': 'available'}


@app.get('/api/test/transfers')
async def get(request: Request):
    room, role = auth(request)
    require_confirmed(room)
    return JSONResponse({'items': [x for x in room['items'].values() if x['sender'] != role]}, headers={'Cache-Control': 'no-store'})


@app.post('/api/test/transfers/{tid}/ack')
async def ack(tid: str, request: Request):
    room, role = auth(request)
    require_confirmed(room)
    item = room['items'].get(tid)
    if not item:
        receipt = room.get('receipts', {}).get(tid)
        if receipt and receipt['sender'] != role and receipt['status'] == 'completed':
            return {'status': 'completed'}
        fail(404, 'not_found')
    if item['sender'] == role:
        fail(403, 'forbidden')
    del room['items'][tid]
    if 'receipts' in room:
        room['receipts'][tid].update(status='completed', completed_at=int(time.time()))
    return {'status': 'completed'}


@app.delete('/api/test/session')
async def revoke(request: Request):
    room, role = auth(request)
    if role != 'owner':
        fail(403, 'forbidden')
    del rooms[room['session_id']]
    return {'status': 'revoked'}


def require_confirmed(room):
    if room.get('pairing') and room['pairing'] != 'confirmed':
        fail(403, 'pairing_required')


def web_auth(request):
    room, role = auth(request)
    if 'pairing' not in room:
        fail(400, 'legacy_room')
    return room, role


def device_name(value):
    if not isinstance(value, str):
        fail(400, 'invalid_request')
    value = value.strip()
    if not 1 <= len(value) <= 40 or any(unicodedata.category(c).startswith('C') for c in value):
        fail(400, 'invalid_request')
    return value


def device(value):
    if value.get('platform') not in ('Windows', 'macOS', 'Android', 'iOS/iPadOS', 'Linux', 'Web'):
        fail(400, 'invalid_request')
    return {'name': device_name(value.get('name')), 'platform': value['platform'], 'last_seen': time.time()}


@app.post('/api/web/sessions', status_code=201)
async def web_create(request: Request):
    value = await body(request)
    cleanup()
    rate('create', 10)
    sid = value.get('session_id')
    if set(value) != {'session_id', 'name', 'platform'} or not isinstance(sid, str) or not re.fullmatch('[0-9a-f]{32}', sid):
        fail(400, 'invalid_request')
    owner_device = device(value)
    if sid in rooms:
        fail(409, 'duplicate')
    if len(rooms) >= 32:
        fail(503, 'capacity')
    now = int(time.time())
    room = {'session_id': sid, 'owner': secrets.token_urlsafe(32), 'peer': '', 'expires_at': now + 900,
            'items': {}, 'seen': set(), 'pairing': 'waiting', 'invite_token': secrets.token_urlsafe(32),
            'invite_expires_at': now + 300, 'devices': {'owner': owner_device}, 'receipts': {}, 'attempts': 0}
    rooms[sid] = room
    return JSONResponse({'owner_token': room['owner'], 'invite_token': room['invite_token'],
                         'expires_at': room['expires_at'], 'invite_expires_at': room['invite_expires_at']}, 201)


@app.post('/api/web/join')
async def web_join(request: Request):
    value = await body(request)
    cleanup()
    rate('web_join', 60)
    if set(value) != {'session_id', 'invite_token', 'claim_id', 'name', 'platform'}:
        fail(400, 'invalid_request')
    sid, ticket, claim = value.get('session_id'), value.get('invite_token'), value.get('claim_id')
    if not isinstance(sid, str) or not isinstance(ticket, str) or not isinstance(claim, str) or not re.fullmatch('[0-9a-f]{32}', claim):
        fail(400, 'invalid_request')
    peer_device = device(value)
    if not re.fullmatch('[0-9a-f]{32}', sid) or not re.fullmatch('[A-Za-z0-9_-]{43}', ticket):
        fail(401, 'invalid_invitation')
    with pair_lock:
        room = rooms.get(sid)
        if not room or 'pairing' not in room or not secrets.compare_digest(ticket, room['invite_token']) or room['invite_expires_at'] <= time.time():
            fail(401, 'invalid_invitation')
        if room['pairing'] != 'waiting' and not (room['pairing'] == 'pending' and secrets.compare_digest(claim, room.get('claim_id', ''))):
            fail(409, 'invitation_used')
        if room['pairing'] == 'waiting':
            room.update(pairing='pending', peer=secrets.token_urlsafe(32), claim_id=claim,
                        confirmation_code=f'{secrets.randbelow(1000000):06d}')
            room['devices']['peer'] = peer_device
        return {'peer_token': room['peer'], 'expires_at': room['expires_at'],
                'confirmation_code': room['confirmation_code'], 'invite_expires_at': room['invite_expires_at']}


@app.post('/api/web/confirm')
async def web_confirm(request: Request):
    value = await body(request)
    room, role = web_auth(request)
    if role != 'owner':
        fail(403, 'forbidden')
    code = value.get('code')
    if set(value) != {'code'} or not isinstance(code, str) or not re.fullmatch('[0-9]{6}', code):
        fail(400, 'invalid_request')
    if room['pairing'] == 'confirmed':
        return {'status': 'confirmed'}
    if room['pairing'] != 'pending':
        fail(409, 'no_claimant')
    if not secrets.compare_digest(code, room['confirmation_code']):
        room['attempts'] += 1
        if room['attempts'] >= 5:
            del rooms[room['session_id']]
            fail(401, 'confirmation_locked')
        fail(400, 'incorrect_code')
    room['pairing'] = 'confirmed'
    room.pop('confirmation_code', None)
    room.pop('claim_id', None)
    return {'status': 'confirmed'}


@app.get('/api/web/state')
async def web_state(request: Request):
    room, role = web_auth(request)
    now = time.time()
    room['devices'][role]['last_seen'] = now
    devices = [{'role': r, **d, 'online': now - d['last_seen'] < 12} for r, d in room['devices'].items()
               if role == 'owner' or r == role or room['pairing'] == 'confirmed']
    return {'session_id': room['session_id'], 'role': role, 'expires_at': room['expires_at'],
            'pairing': room['pairing'], 'invite_expires_at': room['invite_expires_at'], 'devices': devices,
            'receipts': [r for r in room['receipts'].values() if r['sender'] == role]}


@app.patch('/api/web/device')
async def web_rename(request: Request):
    value = await body(request)
    room, role = web_auth(request)
    if set(value) != {'name'}:
        fail(400, 'invalid_request')
    room['devices'][role]['name'] = device_name(value['name'])
    return {'status': 'updated'}


@app.delete('/api/web/session')
async def web_close(request: Request):
    room, _ = web_auth(request)
    del rooms[room['session_id']]
    return {'status': 'revoked'}
