import Foundation
import CryptoKit
import Security
import Darwin
import ImageIO

enum SVError: LocalizedError {
    case message(String)
    case http(Int)
    var errorDescription: String? {
        switch self {
        case .message(let value):return value
        case .http(let code):return code==401 ? "ห้องหมดอายุหรือถูกปิด กรุณาเชื่อมต่อใหม่":"Relay ตอบกลับ \(code) กรุณาลองใหม่"
        }
    }
}
struct Payload: Codable, Equatable {
    let type: String
    let name: String
    let mime: String
    let data: String
    var bytes: Data { (try? Wire.decode(data)) ?? Data() }
    var text: String { String(data: bytes, encoding: .utf8) ?? "" }
    var isText: Bool { type == "text" || type == "url" }
    static func text(_ value: String, link: Bool = false) -> Payload {
        Payload(type: link ? "url" : "text", name: link ? "ลิงก์" : "ข้อความ", mime: "text/plain", data: Wire.encode(Data(value.utf8)))
    }
    func validate() throws {
        guard ["text","url","image","file"].contains(type), name.utf16.count <= 255, mime.utf16.count <= 128,
              data.count <= 6990512, try Wire.decode(data).count <= Wire.limit else { throw SVError.message("ข้อมูลใหญ่เกิน 5 MiB หรือรูปแบบไม่ถูกต้อง") }
    }
}
struct Envelope: Codable {
    var version = "test-v0"
    var id: String
    var session_id: String
    var sender: String
    var expires_at: Int
    var salt: String
    var nonce: String
    var ciphertext: String
}
enum Wire {
    static let limit = 5 * 1024 * 1024
    static func encode(_ data: Data) -> String { data.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"") }
    static func decode(_ text: String) throws -> Data {
        guard text.range(of:"^[A-Za-z0-9_-]*$",options:.regularExpression) != nil,
              let d = Data(base64Encoded: text.replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/") + String(repeating:"=",count:(4-text.count%4)%4)),
              encode(d) == text else { throw SVError.message("รูปแบบ Base64 ไม่ถูกต้อง") }
        return d
    }
    static func random(_ count: Int) -> Data {
        var data = Data(count:count)
        let status = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault,count,$0.baseAddress!) }
        precondition(status == errSecSuccess)
        return data
    }
    static func key(_ secret: Data, _ salt: Data) throws -> SymmetricKey {
        guard secret.count == 32, salt.count == 32 else { throw SVError.message("กุญแจไม่ถูกต้อง") }
        return HKDF<SHA256>.deriveKey(inputKeyMaterial:SymmetricKey(data:secret),salt:salt,info:Data("sendviax-test-v0/content".utf8),outputByteCount:32)
    }
    static func aad(_ e: Envelope) throws -> Data {
        try JSONSerialization.data(withJSONObject:[e.version,e.session_id,e.id,e.sender,e.expires_at],options:[.withoutEscapingSlashes])
    }
    static func encrypt(_ p: Payload, secret: Data, sid: String, role: String, expiry: Int, now: Double) throws -> Envelope {
        try p.validate()
        guard Double(expiry) > now else { throw SVError.message("ห้องหมดอายุ") }
        let salt=random(32), nonce=random(12)
        var e=Envelope(id:UUID().uuidString.lowercased(),session_id:sid,sender:role,expires_at:min(expiry,Int(now)+295),salt:encode(salt),nonce:encode(nonce),ciphertext:"")
        let sealed=try AES.GCM.seal(JSONEncoder().encode(p),using:key(secret,salt),nonce:AES.GCM.Nonce(data:nonce),authenticating:aad(e))
        e.ciphertext=encode(sealed.ciphertext+sealed.tag)
        return e
    }
    static func decrypt(_ e: Envelope, secret: Data, sid: String, role: String, now: Double) throws -> Payload {
        guard e.version == "test-v0", e.session_id == sid, ["owner","peer"].contains(e.sender), e.sender != role,
              UUID(uuidString:e.id) != nil, e.id == e.id.lowercased(), Double(e.expires_at)>now,
              Double(e.expires_at)<=now+300, e.ciphertext.count<=10*1024*1024 else { throw SVError.message("รายการหมดอายุหรือข้อมูลไม่ถูกต้อง") }
        let nonce=try decode(e.nonce), cipher=try decode(e.ciphertext)
        guard nonce.count == 12, cipher.count>=16 else { throw SVError.message("รายการไม่ถูกต้อง") }
        let sealed=try AES.GCM.SealedBox(nonce:AES.GCM.Nonce(data:nonce),ciphertext:cipher.dropLast(16),tag:cipher.suffix(16))
        let plain=try AES.GCM.open(sealed,using:key(secret,decode(e.salt)),authenticating:aad(e))
        let p=try JSONDecoder().decode(Payload.self,from:plain); try p.validate(); return p
    }
    static func hash(_ p: Payload) -> String { SHA256.hash(data:p.bytes).map{String(format:"%02x",$0)}.joined() }
    enum ScanResult {case clear, sensitive, unsupported, invalidText}
    static func scan(_ p:Payload)->ScanResult {
        let ext=(p.name as NSString).pathExtension.lowercased()
        guard p.isText || ["txt","md","csv","json","xml","yaml","yml","swift","kt","js","ts","py","java"].contains(ext) else { return .unsupported }
        guard let text=String(data:p.bytes,encoding:.utf8) else { return .invalidText }
        let rules=["(?i)(password|passwd|token|api.?key|รหัสผ่าน)\\s*[:=]","(?i)bearer\\s+\\S+","sk-[\\w-]{12,}","-----BEGIN .*PRIVATE KEY-----","[\\w.+-]+@[\\w.-]+\\.[a-zA-Z]{2,}","(?:\\+66|0)[2689][\\d -]{7,11}","\\b\\d(?:[ -]?\\d){12}\\b"]
        return rules.contains{ text.range(of:$0,options:.regularExpression) != nil } ? .sensitive:.clear
    }
    static func warning(_ p:Payload)->String {
        switch scan(p){
        case .clear:return "ไม่พบรูปแบบข้อมูลอ่อนไหวที่รู้จัก ไม่ได้รับประกันว่าปลอดภัย"
        case .sensitive:return "อาจมีข้อมูลอ่อนไหว ตรวจสอบก่อนยืนยันส่ง"
        case .unsupported:return "ไม่ได้ตรวจเนื้อหาไฟล์ชนิดนี้ ตรวจสอบด้วยตนเองก่อนส่ง"
        case .invalidText:return "ไฟล์นี้ไม่ใช่ข้อความ UTF-8 จึงไม่ได้ตรวจเนื้อหา"
        }
    }
}

// Bound bytes as URLSession delivers chunks, before buffering an oversized queue.
final class BoundedRequest:NSObject,URLSessionDataDelegate,@unchecked Sendable {
    private let lock=NSLock()
    private let limit:Int
    private var data=Data()
    private var response:URLResponse?
    private var failure:Error?
    private var cancelled=false
    private var task:URLSessionDataTask?
    private var client:URLSession?
    private var continuation:CheckedContinuation<(Data,URLResponse),Error>?
    init(limit:Int){self.limit=limit}
    func load(_ request:URLRequest) async throws -> (Data,URLResponse) {
        try await withTaskCancellationHandler(operation:{
            try await withCheckedThrowingContinuation{continuation in
                lock.lock()
                if cancelled{lock.unlock();continuation.resume(throwing:CancellationError());return}
                self.continuation=continuation
                let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=20;config.urlCache=nil
                let client=URLSession(configuration:config,delegate:self,delegateQueue:nil)
                self.client=client;let task=client.dataTask(with:request);self.task=task
                lock.unlock();task.resume()
            }
        },onCancel:{self.cancel()})
    }
    private func cancel(){lock.lock();cancelled=true;let task=self.task;lock.unlock();task?.cancel()}
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive response:URLResponse,completionHandler:@escaping(URLSession.ResponseDisposition)->Void){
        lock.lock();self.response=response
        let excessive=response.expectedContentLength>Int64(limit)
        if excessive{failure=SVError.message("รายการมีขนาดใหญ่ กรุณาเปิดแอป Sendviax เพื่อรับข้อมูล")}
        lock.unlock();completionHandler(excessive ? .cancel:.allow)
    }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive chunk:Data){
        lock.lock()
        let excessive=chunk.count>limit-data.count
        if excessive{failure=SVError.message("รายการมีขนาดใหญ่ กรุณาเปิดแอป Sendviax เพื่อรับข้อมูล")}
        else if failure==nil{data.append(chunk)}
        lock.unlock();if excessive{dataTask.cancel()}
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,didCompleteWithError error:Error?){
        lock.lock()
        let continuation=self.continuation;self.continuation=nil
        let result:Result<(Data,URLResponse),Error>
        if cancelled{result = .failure(CancellationError())}
        else if let error=failure ?? error{result = .failure(error)}
        else if let response{result = .success((data,response))}
        else{result = .failure(SVError.message("Relay ส่งข้อมูลไม่ถูกต้อง"))}
        data=Data();self.task=nil;client=nil;lock.unlock()
        session.finishTasksAndInvalidate();continuation?.resume(with:result)
    }
}
struct Room: Codable {
    let origin: URL; let sid: String; let secret: Data; let token: String; let role: String; let expiry: Int; let peerToken: String?
    func invite() -> String? {
        guard let peerToken else { return nil }
        return origin.absoluteString + "/try#s=" + sid + "&k=" + Wire.encode(secret) + "&t=" + peerToken
    }
}
@MainActor final class Relay {
    let responseLimit: Int
    init(responseLimit: Int = 40 * 1024 * 1024) { self.responseLimit = responseLimit }
    private var serverTime: Double?
    private var clockSample: Double=0
    var now: Double {
        get throws {
            guard let serverTime else { throw SVError.message("ยังตรวจสอบเวลาเซิร์ฟเวอร์ไม่ได้") }
            return serverTime+ProcessInfo.processInfo.systemUptime-clockSample
        }
    }
    static func inviteOrigin(_ raw:String) throws -> URL {
        guard var u=URLComponents(string:raw.trimmingCharacters(in:.whitespacesAndNewlines)),u.user==nil,u.password==nil,u.query==nil,["","/","/try"].contains(u.path) else {throw SVError.message("ลิงก์เชิญไม่ถูกต้อง")}
        u.path="";u.fragment=nil
        return try origin(u.string ?? "")
    }
    static func origin(_ raw: String) throws -> URL {
        guard let u=URLComponents(string:raw.trimmingCharacters(in:.whitespacesAndNewlines)), u.scheme=="https", let host=u.host,
              !host.isEmpty, u.user==nil,u.password==nil,u.query==nil,u.fragment==nil,
              u.path.isEmpty || u.path=="/",
              let url=URL(string:"https://"+host+(u.port.map{":\($0)"} ?? "")) else { throw SVError.message("ใส่ URL ของ Relay แบบ https:// โดยไม่มี path") }
        return url
    }
    func request(_ origin: URL,_ path: String,_ token: String? = nil,_ method: String = "GET",_ body: Data? = nil) async throws -> Data {
        var req=URLRequest(url:origin.appendingPathComponent(path))
        req.httpMethod=method; req.httpBody=body; req.setValue("no-store",forHTTPHeaderField:"Cache-Control")
        if let token { req.setValue("Bearer "+token,forHTTPHeaderField:"Authorization") }
        if body != nil {req.setValue("application/json",forHTTPHeaderField:"Content-Type")}
        let started=ProcessInfo.processInfo.systemUptime
        let (data,response)=try await BoundedRequest(limit:responseLimit).load(req)
        guard let http=response as? HTTPURLResponse else {throw SVError.message("Relay ส่งข้อมูลไม่ถูกต้อง")}
        if let date=http.value(forHTTPHeaderField:"Date") {
            let f=DateFormatter(); f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(secondsFromGMT:0);f.dateFormat="EEE, dd MMM yyyy HH:mm:ss z"
            if let parsed=f.date(from:date) { serverTime=parsed.timeIntervalSince1970+(ProcessInfo.processInfo.systemUptime-started)/2;clockSample=ProcessInfo.processInfo.systemUptime }
        }
        guard (200...299).contains(http.statusCode) else {
            throw SVError.http(http.statusCode)
        }
        _ = try now
        return data
    }
    func create(_ origin: URL) async throws -> Room {
        let sid=Wire.random(16).map{String(format:"%02x",$0)}.joined()
        let d=try await request(origin,"api/test/sessions",nil,"POST",JSONSerialization.data(withJSONObject:["session_id":sid]))
        struct Reply: Decodable {let owner_token:String;let peer_token:String;let expires_at:Int}
        let r=try JSONDecoder().decode(Reply.self,from:d)
        return Room(origin:origin,sid:sid,secret:Wire.random(32),token:r.owner_token,role:"owner",expiry:r.expires_at,peerToken:r.peer_token)
    }
    func join(_ raw: String, expected: URL) async throws -> Room {
        guard let parts=URLComponents(string:raw),let fragment=parts.fragment,parts.user==nil,parts.password==nil,
              parts.scheme==expected.scheme,parts.host==expected.host,parts.port==expected.port else { throw SVError.message("ลิงก์ต้องมาจาก Relay ที่ตั้งค่าไว้") }
        var fields=URLComponents();fields.query=fragment
        let entries=fields.queryItems ?? []
        guard entries.count==3,Set(entries.map{$0.name})==Set(["s","k","t"]) else {throw SVError.message("ลิงก์ไม่ถูกต้อง")}
        let values=Dictionary(uniqueKeysWithValues:entries.map{($0.name,$0.value ?? "")})
        let sid=values["s"]!,token=values["t"]!,secret=try Wire.decode(values["k"]!)
        guard sid.range(of:"^[0-9a-f]{32}$",options:.regularExpression) != nil,secret.count==32,
              token.range(of:"^[A-Za-z0-9_-]{43}$",options:.regularExpression) != nil else {throw SVError.message("ลิงก์ไม่ถูกต้อง")}
        struct Reply: Decodable {let session_id:String;let role:String;let expires_at:Int}
        let reply=try JSONDecoder().decode(Reply.self,from:await request(expected,"api/test/session",token))
        guard reply.session_id==sid,reply.role=="peer" else {throw SVError.message("ลิงก์ไม่ตรงกับห้อง")}
        return Room(origin:expected,sid:sid,secret:secret,token:token,role:"peer",expiry:reply.expires_at,peerToken:nil)
    }
    func send(_ p: Payload, room: Room) async throws {
        let e=try Wire.encrypt(p,secret:room.secret,sid:room.sid,role:room.role,expiry:room.expiry,now:now)
        _=try await request(room.origin,"api/test/transfers",room.token,"POST",JSONEncoder().encode(e))
    }
    func list(_ r:Room) async throws -> [Envelope] {
        struct List:Decodable {let items:[Envelope]}
        return try JSONDecoder().decode(List.self,from:await request(r.origin,"api/test/transfers",r.token)).items
    }
    func ack(_ e:Envelope, room:Room) async throws {
        do { _=try await request(room.origin,"api/test/transfers/"+e.id+"/ack",room.token,"POST") }
        catch SVError.http(404) {} // The other local process may already have ACKed.
    }
    func close(_ r:Room) async throws {
        if r.role=="owner" {
            do{_=try await request(r.origin,"api/test/session",r.token,"DELETE")}
            catch SVError.http(401){} // Already expired/revoked: local exit still succeeds.
        }
    }
}

// Continuous time includes device sleep; boot identity prevents reuse after reboot.
enum SessionClock {
    static var now: Double {
        var info=mach_timebase_info_data_t();mach_timebase_info(&info)
        return Double(mach_continuous_time()) * Double(info.numer) / Double(info.denom) / 1_000_000_000
    }
    static var boot: String {
        var value=timeval();var size=MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime",&value,&size,nil,0)==0 else {return "unavailable"}
        return "\(value.tv_sec):\(value.tv_usec)"
    }
}
struct SavedRoom: Codable {
    let room:Room;let generation:String;let deadline:Double;let boot:String
}
protocol RoomVault {
    func read() throws -> SavedRoom?
    func write(_ value:SavedRoom) throws
    func clear() throws
}
struct KeychainRoomVault:RoomVault {
    private func query() throws -> [String:Any] {
        guard let group=Bundle.main.object(forInfoDictionaryKey:"SendviaxKeychainGroup") as? String,
              !group.isEmpty,!group.contains("$(") else {
            throw SVError.message("ตั้งค่า Keychain Sharing ของ App และ Keyboard ใน Xcode ก่อนเชื่อมต่อ")
        }
        return [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"dev.sendviax.test-v0.room",
                kSecAttrAccount as String:"current",kSecAttrAccessGroup as String:group,
                kSecAttrSynchronizable as String:false]
    }
    func read() throws -> SavedRoom? {
        var q=try query();q[kSecReturnData as String]=true;q[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?;let status=SecItemCopyMatching(q as CFDictionary,&result)
        if status==errSecItemNotFound{return nil}
        guard status==errSecSuccess,let data=result as? Data else {throw SVError.message("อ่านห้องจาก Keychain ไม่ได้ ตรวจ Signing และปลดล็อกเครื่อง")}
        return try JSONDecoder().decode(SavedRoom.self,from:data)
    }
    func write(_ value:SavedRoom) throws {
        let q=try query(),attributes:[String:Any]=[kSecValueData as String:try JSONEncoder().encode(value),
            kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status=SecItemUpdate(q as CFDictionary,attributes as CFDictionary)
        if status==errSecItemNotFound{status=SecItemAdd(q.merging(attributes){_,new in new} as CFDictionary,nil)}
        guard status==errSecSuccess else {throw SVError.message("บันทึกห้องไม่ได้ ตรวจ Keychain Sharing ของ App และ Keyboard")}
    }
    func clear() throws {
        let status=SecItemDelete(try query() as CFDictionary)
        guard status==errSecSuccess || status==errSecItemNotFound else {throw SVError.message("ล้างห้องจาก Keychain ไม่สำเร็จ")}
    }
}
struct ReceivedRecord:Codable,Identifiable {
    let id:String;let type:String;let name:String;let mime:String;let size:Int;let deadline:Double
    var isText:Bool{type=="text" || type=="url"}
}
private struct InboxIndex:Codable {
    let generation:String
    var records:[ReceivedRecord]=[]
    var seen:[String]=[]
}

// Short file locks coordinate app/extension. No lock is held across a network await.
final class SharedChannel {
    private let directory:URL
    private let vault:any RoomVault
    private let clock:()->Double
    private let boot:()->String
    init(directory:URL,vault:any RoomVault,clock:@escaping()->Double={SessionClock.now},boot:@escaping()->String={SessionClock.boot}) {
        self.directory=directory;self.vault=vault;self.clock=clock;self.boot=boot
    }
    static func live() throws -> SharedChannel {
        SharedChannel(directory:try SharedInbox.file("relay-inbox"),vault:KeychainRoomVault())
    }
    private func locked<T>(_ work:()throws->T) throws -> T {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.complete],ofItemAtPath:directory.path)
        #endif
        var dir=directory;var values=URLResourceValues();values.isExcludedFromBackup=true;try dir.setResourceValues(values)
        let fd=open(directory.appendingPathComponent("lock").path,O_CREAT|O_RDWR,0o600)
        guard fd>=0 else {throw SVError.message("เปิดพื้นที่รับข้อมูลร่วมไม่ได้")}
        defer{Darwin.close(fd)}
        guard flock(fd,LOCK_EX|LOCK_NB)==0 else {throw SVError.message("กำลังอัปเดตรายการร่วม กรุณารอสักครู่")}
        defer{flock(fd,LOCK_UN)}
        return try work()
    }
    private func write(_ data:Data,to url:URL) throws {
        #if os(iOS)
        try data.write(to:url,options:[.atomic,.completeFileProtection])
        #else
        try data.write(to:url,options:.atomic)
        #endif
    }
    private var indexURL:URL{directory.appendingPathComponent("index.json")}
    private func contentURL(_ id:String) throws -> URL {
        guard UUID(uuidString:id) != nil,id==id.lowercased() else {throw SVError.message("รายการไม่ถูกต้อง")}
        return directory.appendingPathComponent("message-"+id)
    }
    private func removeFiles() throws {
        for url in try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)
            where url.lastPathComponent != "lock" {try FileManager.default.removeItem(at:url)}
    }
    private func current() throws -> SavedRoom? {
        guard let saved=try vault.read() else {try removeFiles();return nil}
        guard saved.boot != "unavailable",saved.boot==boot(),saved.deadline>clock(),saved.deadline-clock()<=900 else {
            try vault.clear();try removeFiles();return nil
        }
        guard FileManager.default.fileExists(atPath:indexURL.path),
              let index=try? readIndex(),index.generation==saved.generation else {
            try vault.clear();try removeFiles();return nil
        }
        return saved
    }
    private func readIndex() throws -> InboxIndex {
        let size=try indexURL.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max
        guard size<=200*1024 else {throw SVError.message("รายการร่วมไม่ถูกต้อง")}
        let index=try JSONDecoder().decode(InboxIndex.self,from:Data(contentsOf:indexURL))
        guard index.records.count<=20,index.seen.count<=256 else {throw SVError.message("รายการร่วมไม่ถูกต้อง")}
        return index
    }
    private func saveIndex(_ index:InboxIndex) throws {try write(JSONEncoder().encode(index),to:indexURL)}
    private func prune(_ index:inout InboxIndex) throws {
        let expired=index.records.filter{$0.deadline<=clock()}
        index.records.removeAll{$0.deadline<=clock()}
        // Metadata first: files left by interruption are never offered for insertion.
        if !expired.isEmpty {try saveIndex(index)}
        let live=Set(try index.records.map{try contentURL($0.id).lastPathComponent})
        for url in try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)
            where url.lastPathComponent.hasPrefix("message-") && !live.contains(url.lastPathComponent) {
            try FileManager.default.removeItem(at:url)
        }
    }
    func snapshot() throws -> SavedRoom? {try locked{try current()}}
    @discardableResult func install(_ room:Room,serverNow:Double) throws -> SavedRoom {
        try locked {
            let lifetime=min(900,Double(room.expiry)-serverNow)
            guard lifetime>0,boot() != "unavailable" else {throw SVError.message("ห้องหมดอายุ")}
            try vault.clear();try removeFiles()
            let saved=SavedRoom(room:room,generation:UUID().uuidString,deadline:clock()+lifetime,boot:boot())
            try saveIndex(InboxIndex(generation:saved.generation))
            do{try vault.write(saved)}catch{try? removeFiles();throw error}
            SharedInbox.clear()
            return saved
        }
    }
    func clear(expected:String?=nil) throws {
        try locked {
            if let expected,try vault.read()?.generation != expected{return}
            try vault.clear();try removeFiles();SharedInbox.clear()
        }
    }
    func clearInbox() throws {
        try locked {
            guard try current() != nil else{return}
            var index=try readIndex();index.records=[];try saveIndex(index);try prune(&index)
        }
    }
    func records() throws -> [ReceivedRecord] {
        try locked {
            guard try current() != nil else{return []}
            var index=try readIndex();try prune(&index);return index.records
        }
    }
    func payload(_ id:String) throws -> Payload? {
        try locked {
            guard try current() != nil else{return nil}
            var index=try readIndex();try prune(&index)
            guard let item=index.records.first(where:{$0.id==id}) else{return nil}
            let url=try contentURL(id)
            guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize)==item.size,item.size<=Wire.limit else {throw SVError.message("ข้อมูลร่วมไม่ถูกต้อง")}
            let data=try Data(contentsOf:url)
            return Payload(type:item.type,name:item.name,mime:item.mime,data:Wire.encode(data))
        }
    }
    // Returns false for stale room responses; duplicate IDs still allow an idempotent ACK.
    func receive(_ p:Payload,envelope:Envelope,saved:SavedRoom,serverNow:Double) throws -> Bool {
        try locked {
            guard let active=try current(),active.generation==saved.generation else{return false}
            guard envelope.session_id==active.room.sid,Double(envelope.expires_at)>serverNow else{return false}
            var index=try readIndex();try prune(&index)
            if index.seen.contains(envelope.id){return true}
            guard index.seen.count<256 else{throw SVError.message("รายการในห้องครบขีดจำกัด กรุณาสร้างห้องใหม่")}
            try p.validate();let bytes=p.bytes
            let deadline=min(active.deadline,clock()+min(300,Double(envelope.expires_at)-serverNow))
            let item=ReceivedRecord(id:envelope.id,type:p.type,name:p.name,mime:p.mime,size:bytes.count,deadline:deadline)
            while index.records.count>=20 || index.records.reduce(0,{$0+$1.size})+bytes.count>20*1024*1024 {index.records.removeLast()}
            try write(bytes,to:contentURL(envelope.id))
            index.records.insert(item,at:0);index.seen.append(envelope.id)
            try saveIndex(index);try prune(&index);return true
        }
    }
}

enum KeyboardContent {
    static func text(_ p:Payload) -> String? {
        guard p.isText,p.bytes.count<=64*1024 else{return nil}
        return String(data:p.bytes,encoding:.utf8)
    }
    static func imageType(_ p:Payload) -> String? {
        guard p.type=="image",p.bytes.count<=Wire.limit,
              let source=CGImageSourceCreateWithData(p.bytes as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              let type=CGImageSourceGetType(source) as String?,
              ["public.png","public.jpeg","org.webmproject.webp"].contains(type),
              let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
              let width=properties[kCGImagePropertyPixelWidth] as? Int,let height=properties[kCGImagePropertyPixelHeight] as? Int,
              width>0,height>0,width<=8192,height<=8192,width*height<=32_000_000 else{return nil}
        return type
    }
    static func thumbnail(_ p:Payload) -> CGImage? {
        guard imageType(p) != nil,let source=CGImageSourceCreateWithData(p.bytes as CFData,[kCGImageSourceShouldCache:false] as CFDictionary) else{return nil}
        return CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:160,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary)
    }
}

@MainActor final class SharedReceiver {
    let channel:SharedChannel
    let relay:Relay
    private var polling=false
    init(channel:SharedChannel,relay:Relay) {self.channel=channel;self.relay=relay}
    func poll(allowed:()->Bool={true}) async throws {
        guard allowed(),!polling,let saved=try channel.snapshot() else{return}
        polling=true;defer{polling=false}
        do {
            let entries=try await relay.list(saved.room)
            try Task.checkCancellation()
            guard allowed() else{return}
            if try relay.now>=Double(saved.room.expiry){try channel.clear(expected:saved.generation);return}
            for e in entries {
                try Task.checkCancellation()
                guard allowed() else{return}
                guard try channel.snapshot()?.generation==saved.generation else{return}
                let p=try Wire.decrypt(e,secret:saved.room.secret,sid:saved.room.sid,role:saved.room.role,now:relay.now)
                guard try channel.receive(p,envelope:e,saved:saved,serverNow:relay.now) else{return}
                try Task.checkCancellation()
                try await relay.ack(e,room:saved.room)
            }
        } catch SVError.http(401) {try channel.clear(expected:saved.generation);throw SVError.http(401)}
    }
}

struct ShareDraft:Codable{let payload:Payload;let expires:Date}
enum SharedInbox {
    static let group="group.dev.sendviax.mobile"
    static func file(_ name:String) throws -> URL {
        #if os(iOS)
        guard let dir=FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:group) else { throw SVError.message("ตั้งค่า App Group ใน Xcode ก่อนใช้ร่วมกับคีย์บอร์ด") }
        return dir.appendingPathComponent(name)
        #else
        throw SVError.message("App Group ใช้บน iOS")
        #endif
    }
    static func clear() { if let u=try? file("keyboard.json") {try? FileManager.default.removeItem(at:u)} }
}
