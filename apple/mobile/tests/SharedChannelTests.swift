import Foundation
import ImageIO

final class TestVault:RoomVault {
    var value:SavedRoom?
    func read() throws -> SavedRoom?{value}
    func write(_ value:SavedRoom) throws{self.value=value}
    func clear() throws{value=nil}
}
func expect(_ value:Bool,_ message:String)throws{if !value{throw SVError.message(message)}}
@main struct SharedChannelTests {
    @MainActor static func main() async throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("sendviax-shared-tests-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        let vault=TestVault();var clock=100.0;var boot="test-boot"
        let app=SharedChannel(directory:dir,vault:vault,clock:{clock},boot:{boot})
        let keyboard=SharedChannel(directory:dir,vault:vault,clock:{clock},boot:{boot})
        let room=Room(origin:URL(string:"https://relay.example")!,sid:String(repeating:"a",count:32),secret:Data(repeating:19,count:32),token:String(repeating:"T",count:43),role:"peer",expiry:1900,peerToken:nil)
        func envelope(expiry:Int=1295)->Envelope{Envelope(id:UUID().uuidString.lowercased(),session_id:room.sid,sender:"owner",expires_at:expiry,salt:"",nonce:"",ciphertext:"")}
        let saved=try app.install(room,serverNow:1000),e=envelope(),text=Payload.text("สวัสดีจากเว็บ · synthetic")
        try expect(try app.receive(text,envelope:e,saved:saved,serverNow:1000),"commit")
        try expect(try keyboard.payload(e.id)==text,"app -> keyboard shared bytes")
        try expect(try keyboard.receive(text,envelope:e,saved:saved,serverNow:1000),"duplicate ACK allowed")
        try expect(try app.records().count==1,"duplicate received twice")
        try keyboard.clearInbox()
        try expect(try app.records().isEmpty,"clear shared")
        _=try keyboard.receive(text,envelope:e,saved:saved,serverNow:1000)
        try expect(try app.records().isEmpty,"clear must retain replay IDs")
        let short=envelope(expiry:1010)
        _=try app.receive(text,envelope:short,saved:saved,serverNow:1000)
        clock+=11
        try expect(try keyboard.payload(short.id)==nil,"expired item insert blocked")
        try expect(!FileManager.default.fileExists(atPath:dir.appendingPathComponent("message-"+short.id).path),"expired file cleanup")
        let next=try app.install(room,serverNow:1000)
        try app.clear(expected:saved.generation)
        try expect(try keyboard.snapshot()?.generation==next.generation,"stale 401 cannot clear new room")
        try expect(try !keyboard.receive(text,envelope:envelope(),saved:saved,serverNow:1000),"stale response must not persist")
        for _ in 0..<23{_=try app.receive(text,envelope:envelope(),saved:next,serverNow:1000)}
        try expect(try keyboard.records().count==20,"record quota")
        let large=Payload(type:"file",name:"synthetic.bin",mime:"application/octet-stream",data:Wire.encode(Data(repeating:65,count:Wire.limit)))
        for _ in 0..<5{_=try app.receive(large,envelope:envelope(),saved:next,serverNow:1000)}
        try expect(try keyboard.records().reduce(0,{$0+$1.size})<=20*1024*1024,"byte quota")
        for url in try FileManager.default.contentsOfDirectory(at:dir,includingPropertiesForKeys:nil) where url.lastPathComponent != "lock" {
            let bytes=try Data(contentsOf:url)
            try expect(bytes.range(of:Data(room.token.utf8))==nil,"capability leaked into shared files")
            try expect(bytes.range(of:Data(Wire.encode(room.secret).utf8))==nil,"secret leaked into shared files")
        }
        clock+=901
        try expect(try keyboard.snapshot()==nil && vault.value==nil,"room continuous deadline")
        try expect(try app.records().isEmpty,"expiry clears records")
        _=try app.install(room,serverNow:1000);boot="new-boot"
        try expect(try keyboard.snapshot()==nil,"reboot invalidates credentials")
        _=try app.install(room,serverNow:1000)
        try FileManager.default.removeItem(at:dir.appendingPathComponent("index.json"))
        try expect(try app.snapshot()==nil,"orphan Keychain entry invalidated")
        try expect(KeyboardContent.text(text)==text.text,"text insertion bytes")
        try expect(KeyboardContent.text(Payload.text(String(repeating:"x",count:65537)))==nil,"text limit")
        let png=Data(base64Encoded:"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j9ZkAAAAASUVORK5CYII=")!
        let image=Payload(type:"image",name:"synthetic.png",mime:"image/png",data:Wire.encode(png))
        try expect(KeyboardContent.imageType(image)=="public.png" && KeyboardContent.thumbnail(image) != nil,"PNG validation and bounded thumbnail")
        try expect(KeyboardContent.imageType(Payload(type:"image",name:"fake.png",mime:"image/png",data:text.data))==nil,"reject fake image")
        try expect(KeyboardContent.imageType(Payload(type:"image",name:"x.svg",mime:"image/svg+xml",data:Wire.encode(Data("<svg/>".utf8))))==nil,"reject SVG")
        _=try app.install(room,serverNow:1000)
        let fd=open(dir.appendingPathComponent("lock").path,O_RDWR)
        flock(fd,LOCK_EX)
        do{_=try keyboard.records();throw SVError.message("lock bypassed")}catch SVError.message(let message){try expect(message != "lock bypassed","lock bypassed")}
        flock(fd,LOCK_UN);close(fd)
        try expect(try app.snapshot() != nil,"lock contention must preserve room")
        print("PASS shared inbox: two clients, replay/clear, expiry, stale generation, quotas, secret isolation, reboot/orphan cleanup, text/PNG validation")

        if CommandLine.arguments.count>1 {
            let origin=URL(string:CommandLine.arguments[1])!,sender=Relay(),receiverRelay=Relay(responseLimit:12*1024*1024)
            let owner=try await sender.create(origin)
            let peer=Room(origin:origin,sid:owner.sid,secret:owner.secret,token:owner.peerToken!,role:"peer",expiry:owner.expiry,peerToken:nil)
            _=try app.install(peer,serverNow:sender.now)
            let receiver=SharedReceiver(channel:keyboard,relay:receiverRelay)
            try await sender.send(text,room:owner);try await sender.send(image,room:owner)
            try await receiver.poll(allowed:{false})
            try expect(try app.records().isEmpty,"hidden/no-access keyboard cannot receive")
            try await receiver.poll()
            let entries=try app.records()
            try expect(entries.count==2,"actual HTTP receive into shared keyboard inbox")
            try expect(try app.payload(entries[0].id) != nil,"stored before ACK")
            try expect(try await receiverRelay.list(peer).isEmpty,"ACK removed queue")
            try await sender.send(text,room:owner)
            let tiny=SharedReceiver(channel:keyboard,relay:Relay(responseLimit:32))
            do{try await tiny.poll();throw SVError.message("response cap bypassed")}catch SVError.message(let message){try expect(message != "response cap bypassed","response cap bypassed")}
            try expect(try await sender.list(peer).count==1,"oversize response must not ACK")
            try await sender.close(owner)
            do{try await receiver.poll()}catch SVError.http(401){}
            try expect(try app.snapshot()==nil && app.records().isEmpty,"HTTP revoke clears shared room/inbox")
            print("PASS real HTTP: text/image auto inbox, ACK, response cap without ACK, revoke cleanup")
        }
        if CommandLine.arguments.count>2 {
            let origin=URL(string:CommandLine.arguments[2])!
            do{
                _=try await BoundedRequest(limit:1024).load(URLRequest(url:origin.appendingPathComponent("large")))
                throw SVError.message("chunked cap bypassed")
            }catch SVError.message(let message){try expect(message != "chunked cap bypassed","chunked cap bypassed")}
            let (_,response)=try await BoundedRequest(limit:1024).load(URLRequest(url:origin.appendingPathComponent("redirect")))
            try expect((response as? HTTPURLResponse)?.statusCode==302,"redirect followed")
            let pending=Task{try await BoundedRequest(limit:1024).load(URLRequest(url:origin.appendingPathComponent("slow")))}
            try await Task.sleep(nanoseconds:100_000_000);pending.cancel()
            do{_=try await pending.value;throw SVError.message("cancellation ignored")}catch is CancellationError{}
            print("PASS network boundaries: unknown-length body cap, redirect rejection, request cancellation")
        }
    }
}
