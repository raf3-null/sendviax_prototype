import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4
from fastapi.testclient import TestClient
from app import app, rooms, rates, cleanup
from test_relay import b64


class WebPairTests(unittest.TestCase):
    def setUp(self):
        rooms.clear(); rates.clear()
        self.client = TestClient(app)
        self.sid = uuid4().hex
        r = self.client.post('/api/web/sessions', json={'session_id': self.sid, 'name': 'เครื่องส่ง', 'platform': 'Web'})
        self.assertEqual(r.status_code, 201)
        self.created = r.json()
        self.owner = {'Authorization': 'Bearer ' + self.created['owner_token']}
        self.claim = {'session_id': self.sid, 'invite_token': self.created['invite_token'], 'claim_id': uuid4().hex,
                      'name': 'เครื่องรับ', 'platform': 'Android'}

    def join(self):
        r = self.client.post('/api/web/join', json=self.claim)
        self.assertEqual(r.status_code, 200)
        self.peer = {'Authorization': 'Bearer ' + r.json()['peer_token']}
        self.code = r.json()['confirmation_code']
        return r.json()

    def confirm(self):
        self.join()
        self.assertEqual(self.client.post('/api/web/confirm', json={'code': self.code}, headers=self.owner).status_code, 200)

    def envelope(self):
        return {'version': 'test-v0', 'id': str(uuid4()), 'session_id': self.sid, 'sender': 'owner',
                'expires_at': int(time.time())+290, 'salt': b64(bytes(32)), 'nonce': b64(bytes(12)), 'ciphertext': b64(bytes(32))}

    def test_one_time_claim_and_retry(self):
        first = self.join()
        self.assertEqual(self.client.post('/api/web/join', json=self.claim).json(), first)
        self.assertEqual(self.client.post('/api/web/join', json={**self.claim, 'claim_id': uuid4().hex}).status_code, 409)
        state = self.client.get('/api/web/state', headers=self.owner).json()
        self.assertNotIn('confirmation_code', state)
        self.assertNotIn('invite_token', state)
        self.assertEqual(state['pairing'], 'pending')
        self.assertEqual(len(self.client.get('/api/web/state', headers=self.peer).json()['devices']), 1)

    def test_concurrent_claim_only_one_winner(self):
        claims = [{**self.claim, 'claim_id': uuid4().hex} for _ in range(2)]
        with ThreadPoolExecutor(max_workers=2) as pool:
            statuses = list(pool.map(lambda c: self.client.post('/api/web/join', json=c).status_code, claims))
        self.assertEqual(sorted(statuses), [200, 409])

    def test_confirmation_required_and_role(self):
        self.join()
        self.assertEqual(self.client.post('/api/test/transfers', json=self.envelope(), headers=self.owner).status_code, 403)
        self.assertEqual(self.client.get('/api/test/transfers', headers=self.peer).status_code, 403)
        self.assertEqual(self.client.post('/api/web/confirm', json={'code': self.code}, headers=self.peer).status_code, 403)
        self.assertEqual(self.client.post('/api/web/confirm', json={'code': self.code}, headers=self.owner).status_code, 200)
        self.assertEqual(self.client.post('/api/web/join', json=self.claim).status_code, 409)

    def test_five_wrong_codes_close_room(self):
        self.join()
        wrong = '000000' if self.code != '000000' else '111111'
        for expected in [400, 400, 400, 400, 401]:
            self.assertEqual(self.client.post('/api/web/confirm', json={'code': wrong}, headers=self.owner).status_code, expected)
        self.assertNotIn(self.sid, rooms)
        self.assertEqual(self.client.get('/api/web/state', headers=self.peer).status_code, 401)

    def test_expired_invite_and_pending(self):
        rooms[self.sid]['invite_expires_at'] = time.time()-1
        self.assertEqual(self.client.post('/api/web/join', json=self.claim).status_code, 401)
        rooms[self.sid]['invite_expires_at'] = time.time()+100
        self.join(); rooms[self.sid]['invite_expires_at'] = time.time()-1
        cleanup(); self.assertNotIn(self.sid, rooms)

    def test_receipts_ack_expiry_and_replay(self):
        self.confirm(); e = self.envelope()
        self.assertEqual(self.client.post('/api/test/transfers', json=e, headers=self.owner).status_code, 201)
        state = lambda h: self.client.get('/api/web/state', headers=h).json()
        self.assertEqual(state(self.owner)['receipts'][0]['status'], 'available')
        self.assertEqual(state(self.peer)['receipts'], [])
        path = '/api/test/transfers/'+e['id']+'/ack'
        self.assertEqual(self.client.post(path, headers=self.owner).status_code, 403)
        self.assertEqual(self.client.post(path, headers=self.peer).status_code, 200)
        self.assertEqual(self.client.post(path, headers=self.peer).status_code, 200)
        self.assertEqual(state(self.owner)['receipts'][0]['status'], 'completed')
        self.assertEqual(rooms[self.sid]['items'], {})
        self.assertEqual(self.client.post('/api/test/transfers', json=e, headers=self.owner).status_code, 409)
        e2 = self.envelope(); self.client.post('/api/test/transfers', json=e2, headers=self.owner)
        rooms[self.sid]['items'][e2['id']]['expires_at'] = time.time()-1
        cleanup()
        self.assertEqual(state(self.owner)['receipts'][1]['status'], 'expired')
        self.assertEqual(self.client.post('/api/test/transfers/'+e2['id']+'/ack', headers=self.peer).status_code, 404)

    def test_presence_rename_and_peer_close(self):
        self.confirm()
        rooms[self.sid]['devices']['peer']['last_seen'] = time.time()-20
        state = self.client.get('/api/web/state', headers=self.owner).json()
        self.assertFalse(next(d for d in state['devices'] if d['role']=='peer')['online'])
        self.client.get('/api/web/state', headers=self.peer)
        self.client.patch('/api/web/device', json={'name':'มือถือทดสอบ'}, headers=self.peer)
        state = self.client.get('/api/web/state', headers=self.owner).json()
        self.assertTrue(state['devices'][1]['online']); self.assertEqual(state['devices'][1]['name'], 'มือถือทดสอบ')
        for name in ['', 'a'*41, 'bad\nname']:
            self.assertEqual(self.client.patch('/api/web/device', json={'name':name}, headers=self.peer).status_code, 400)
        self.assertEqual(self.client.delete('/api/web/session', headers=self.peer).status_code, 200)
        self.assertEqual(self.client.get('/api/web/state', headers=self.owner).status_code, 401)

    def test_unknown_ticket_legacy_isolation_and_no_store(self):
        self.assertEqual(self.client.post('/api/web/join', json={**self.claim, 'invite_token':'wrong'}).status_code, 401)
        legacy = self.client.post('/api/test/sessions', json={'session_id':uuid4().hex}).json()
        headers = {'Authorization':'Bearer '+legacy['owner_token']}
        self.assertEqual(self.client.get('/api/web/state', headers=headers).status_code, 400)
        self.assertEqual(self.client.get('/api/test/transfers', headers=headers).status_code, 200)
        r = self.client.get('/api/web/state', headers=self.owner)
        self.assertEqual(r.headers['cache-control'], 'no-store')


if __name__ == '__main__': unittest.main()
