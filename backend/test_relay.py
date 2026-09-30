import base64
import time
import unittest
from uuid import uuid4
from fastapi.testclient import TestClient
from app import app, rooms, rates, cleanup, MAX_BODY

def b64(raw):
    return base64.urlsafe_b64encode(raw).decode().rstrip('=')

class RelayTests(unittest.TestCase):
    def setUp(self):
        rooms.clear()
        rates.clear()
        self.client = TestClient(app)
        self.sid = uuid4().hex
        data = self.client.post('/api/test/sessions', json={'session_id':self.sid}).json()
        self.owner = {'Authorization':'Bearer ' + data['owner_token']}
        self.peer = {'Authorization':'Bearer ' + data['peer_token']}

    def envelope(self):
        return {'version':'test-v0', 'id':str(uuid4()), 'session_id':self.sid, 'sender':'owner',
                'expires_at':int(time.time())+290, 'salt':b64(bytes(32)), 'nonce':b64(bytes(12)), 'ciphertext':b64(bytes(32))}

    def put(self, e):
        return self.client.post('/api/test/transfers', json=e, headers=self.owner)

    def test_delivery_ack_replay_and_roles(self):
        e = self.envelope()
        self.assertEqual(self.put(e).status_code,201)
        self.assertEqual(self.client.get('/api/test/transfers',headers=self.owner).json()['items'],[])
        self.assertEqual(self.client.get('/api/test/transfers',headers=self.peer).json()['items'],[e])
        path='/api/test/transfers/'+e['id']+'/ack'
        self.assertEqual(self.client.post(path,headers=self.owner).status_code,403)
        self.assertEqual(self.client.post(path,headers=self.peer).status_code,200)
        self.assertEqual(rooms[self.sid]['items'],{})
        self.assertEqual(self.put(e).status_code,409)

    def test_unauthorized_and_cross_room(self):
        self.assertEqual(self.client.get('/api/test/transfers').status_code,401)
        e=self.envelope();e['sender']='peer'
        self.assertEqual(self.put(e).status_code,403)
        e=self.envelope();e['session_id']=uuid4().hex
        self.assertEqual(self.put(e).status_code,403)

    def test_revoke_and_expiry(self):
        self.assertEqual(self.client.delete('/api/test/session',headers=self.peer).status_code,403)
        self.put(self.envelope())
        self.assertEqual(self.client.delete('/api/test/session',headers=self.owner).status_code,200)
        self.assertEqual(rooms,{})
        self.assertEqual(self.client.get('/api/test/transfers',headers=self.peer).status_code,401)

    def test_cleanup_and_no_replay_after_expiry(self):
        e=self.envelope();self.put(e)
        rooms[self.sid]['items'][e['id']]['expires_at']=int(time.time())-1
        cleanup();self.assertEqual(rooms[self.sid]['items'],{})
        self.assertIn(e['id'],rooms[self.sid]['seen'])
        rooms[self.sid]['expires_at']=int(time.time())-1
        cleanup();self.assertEqual(rooms,{})

    def test_validation_limits(self):
        e=self.envelope();e['plaintext']='must reject'
        self.assertEqual(self.put(e).status_code,400)
        e=self.envelope();e['expires_at']=int(time.time())+901
        self.assertEqual(self.put(e).status_code,400)
        e=self.envelope();e['salt']='not-base64!'
        self.assertEqual(self.put(e).status_code,400)
        e=self.envelope();e['nonce']=b64(bytes(11))
        self.assertEqual(self.put(e).status_code,400)
        r=self.client.post('/api/test/transfers',content=b'x'*(MAX_BODY+1),headers=self.owner)
        self.assertEqual(r.status_code,413)

    def test_limits_and_bad_json(self):
        self.assertEqual(self.client.post('/api/test/sessions',content='bad').status_code,400)
        for _ in range(8):
            self.client.post('/api/test/sessions',json={'session_id':uuid4().hex})
        self.assertEqual(self.client.post('/api/test/sessions',json={'session_id':uuid4().hex}).status_code,429)

if __name__=='__main__': unittest.main()
