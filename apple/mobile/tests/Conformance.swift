import Foundation
import CryptoKit

func check(_ condition:Bool,_ message:String) throws {if !condition{throw SVError.message(message)}}
@main struct Conformance {
    @MainActor static func main() async throws {
        let root=URL(fileURLWithPath:CommandLine.arguments[1])
        let v=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("test-vectors/test-v0.json"))) as! [String:Any]
        func hex(_ s:String)->Data{Data(stride(from:0,to:s.count,by:2).map{ i in let start=s.index(s.startIndex,offsetBy:i);return UInt8(s[start..<s.index(start,offsetBy:2)],radix:16)! })}
        let secret=hex(v["ikm_hex"] as! String),salt=hex(v["salt_hex"] as! String)
        let key=try Wire.key(secret,salt).withUnsafeBytes{Data($0)}
        try check(key==hex(v["key_hex"] as! String),"HKDF vector mismatch")
        let e=Envelope(id:"00000000-0000-4000-8000-000000000000",session_id:"0123456789abcdef0123456789abcdef",sender:"owner",expires_at:2000000000,salt:Wire.encode(salt),nonce:Wire.encode(hex(v["nonce_hex"] as! String)),ciphertext:Wire.encode(hex(v["ciphertext_tag_hex"] as! String)))
        try check(String(data:Wire.aad(e),encoding:.utf8)==v["aad"] as? String,"AAD mismatch")
        let p=try Wire.decrypt(e,secret:secret,sid:e.session_id,role:"peer",now:1999999900)
        try check(p.text=="hello","decrypt vector mismatch")
        func mustFail(_ body:()throws->Void)throws{do{try body()}catch{return};throw SVError.message("invalid data accepted")}
        try mustFail{_=try Wire.decrypt(e,secret:Data(repeating:3,count:32),sid:e.session_id,role:"peer",now:1999999900)}
        try mustFail{_=try Wire.decrypt(e,secret:secret,sid:e.session_id,role:"owner",now:1999999900)}
        try mustFail{_=try Wire.decrypt(e,secret:secret,sid:e.session_id,role:"peer",now:2000000001)}
        var tampered=e;tampered.ciphertext=Wire.encode(Data(repeating:7,count:40))
        try mustFail{_=try Wire.decrypt(tampered,secret:secret,sid:e.session_id,role:"peer",now:1999999900)}
        try mustFail{_=try Wire.decode("aGVsbG8=")}
        try mustFail{try Payload(type:"file",name:"large",mime:"application/octet-stream",data:Wire.encode(Data(count:Wire.limit+1))).validate()}
        try mustFail{_=try Relay.origin("http://example.com")}
        try mustFail{_=try Relay.origin("https://user:pass@example.com")}
        let inferred=try Relay.inviteOrigin(" https://relay.example:8443/try#s=synthetic&k=synthetic&t=synthetic ")
        try check(inferred.absoluteString=="https://relay.example:8443","invite origin mismatch")
        for raw in ["http://relay.example/try#s=x","https://user:pass@relay.example/try#s=x","https://relay.example/other#s=x","https://relay.example/try?redirect=x#s=x"] {try mustFail{_=try Relay.inviteOrigin(raw)}}
        let web=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("outputs/mobile-tests/web-fixtures.json"))) as! [String:Any]
        let incoming=try JSONSerialization.data(withJSONObject:web["envelopes"]!)
        let webEnvelopes=try JSONDecoder().decode([Envelope].self,from:incoming)
        var outgoing:[Envelope]=[]
        for envelope in webEnvelopes {
            let payload=try Wire.decrypt(envelope,secret:secret,sid:e.session_id,role:"peer",now:1999999900)
            let encrypted=try Wire.encrypt(payload,secret:secret,sid:e.session_id,role:"peer",expiry:2000000000,now:1999999900)
            outgoing.append(encrypted)
        }
        try JSONEncoder().encode(outgoing).write(to:root.appendingPathComponent("outputs/mobile-tests/swift-fixtures.json"))
        print("PASS Swift: HKDF / AES-GCM / AAD vector; wrong key, tamper, expiry, role, size, encoding; Web -> Swift four types")
        if CommandLine.arguments.count>2 {
            let relay=Relay(),origin=URL(string:CommandLine.arguments[2])!
            let owner=try await relay.create(origin)
            guard let token=owner.peerToken else{throw SVError.message("missing peer")}
            let peer=Room(origin:origin,sid:owner.sid,secret:owner.secret,token:token,role:"peer",expiry:owner.expiry,peerToken:nil)
            for (sender,receiver) in [(owner,peer),(peer,owner)] {
                for kind in ["text","url","image","file"]{
                    let bytes=kind=="file" ? Data(repeating:0x41,count:Wire.limit):Data("synthetic mobile test สวัสดี".utf8)
                    let payload=Payload(type:kind,name:"synthetic",mime:"application/octet-stream",data:Wire.encode(bytes))
                    try await relay.send(payload,room:sender)
                    let entries=try await relay.list(receiver)
                    guard let last=entries.last else{throw SVError.message("missing transfer")}
                    let read=try Wire.decrypt(last,secret:receiver.secret,sid:receiver.sid,role:receiver.role,now:relay.now)
                    try check(read==payload,"HTTP bytes mismatch")
                    try await relay.ack(last,room:receiver)
                }
            }
            try await relay.close(owner)
            print("PASS Swift real HTTP relay: eight transfers including 5 MiB in both directions; ACK and revoke")
        }
    }
}
