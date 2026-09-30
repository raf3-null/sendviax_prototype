import SwiftUI
import UniformTypeIdentifiers

struct InboxEntry:Identifiable {let id:String;let payload:Payload;let received:Bool}
@MainActor final class AppModel:ObservableObject {
    @Published var origin=Bundle.main.object(forInfoDictionaryKey:"SendviaxRelayURL") as? String ?? ""
    @Published var inviteInput=""
    @Published var room:Room?
    @Published var draft=""
    @Published var linkType=false
    @Published var file:Payload?
    @Published var items:[InboxEntry]=[]
    @Published var busy=false
    @Published var message=""
    @Published var shareURL:URL?
    let relay=Relay()
    private var generation=UUID()
    private var receiver:SharedReceiver?
    private func shared() throws -> SharedReceiver {
        if let receiver{return receiver}
        let value=SharedReceiver(channel:try SharedChannel.live(),relay:relay);receiver=value;return value
    }
    private func refresh() throws {
        let channel=try shared().channel
        let next=try channel.snapshot()?.room
        if next?.sid != room?.sid {generation=UUID();items=[]}
        room=next
        if let next {origin=next.origin.absoluteString}
        let received=try channel.records().compactMap { record -> InboxEntry? in
            guard let payload=try channel.payload(record.id) else{return nil}
            return InboxEntry(id:record.id,payload:payload,received:true)
        }
        items=Array((received+items.filter{!$0.received}).prefix(20))
        if next==nil{items=[]}
    }
    private func install(_ r:Room) throws {
        try shared().channel.install(r,serverNow:relay.now)
        generation=UUID();items=[];shareURL=nil;try refresh()
    }
    func run(_ work:@escaping () async throws -> Void) {
        guard !busy else{return};busy=true
        Task {defer{busy=false};do{try await work()}catch{message=(error as? SVError)?.localizedDescription ?? "ทำรายการไม่สำเร็จ ตรวจ URL และการเชื่อมต่อแล้วลองใหม่"}}
    }
    func create(){run{let r=try await self.relay.create(Relay.origin(self.origin));try self.install(r);self.message="สร้างห้องแล้ว ส่งลิงก์เชิญให้อีกเครื่อง"}}
    func join(){let raw=inviteInput;inviteInput="";run{let r=try await self.relay.join(raw.trimmingCharacters(in:.whitespacesAndNewlines),expected:Relay.inviteOrigin(raw));try self.install(r);self.message="เข้าร่วมห้องแล้ว เปิดคีย์บอร์ดเพื่อรับรายการได้เลย"}}
    func close(){guard let r=room else{return};run{
        try self.shared().channel.clear();self.generation=UUID();self.room=nil;self.items=[];self.shareURL=nil
        self.message="ออกจากห้องบนเครื่องแล้ว"
        try await self.relay.close(r)
    }}
    func clearInbox(){do{try shared().channel.clearInbox();items=[];message="ล้างรายการที่ได้รับแล้ว";try refresh()}catch{message=error.localizedDescription}}
    func expireLocal() {
        guard let receiver else{return}
        do {
            if try receiver.channel.snapshot()==nil {if room != nil{generation=UUID()};room=nil;items=[];return}
            let live=Set(try receiver.channel.records().map{$0.id})
            items.removeAll{$0.received && !live.contains($0.id)}
        }catch{items.removeAll{$0.received}}
    }
    func available(_ item:InboxEntry) -> Payload? {
        guard item.received else{return item.payload}
        guard let payload=try? shared().channel.payload(item.id) else{expireLocal();message="รายการหมดอายุแล้ว";return nil}
        return payload
    }
    func payload()->Payload{file ?? Payload.text(draft,link:linkType)}
    func send(){guard let r=room else{return};let p=payload(),g=generation
        run{
            // Refresh server time before encrypting after an app suspension.
            _=try await self.relay.request(r.origin,"api/test/session",r.token)
            guard try self.shared().channel.snapshot()?.room.sid==r.sid else{throw SVError.message("ห้องหมดอายุ")}
            try await self.relay.send(p,room:r);guard g==self.generation else{return}
            self.items.insert(InboxEntry(id:UUID().uuidString,payload:p,received:false),at:0);self.items=Array(self.items.prefix(20));self.draft="";self.file=nil;self.message="อัปโหลดแล้ว รออีกเครื่องรับข้อมูล"
        }
    }
    func poll() async {
        guard !busy else{return}
        do{
            try refresh()
            try await shared().poll()
            try Task.checkCancellation()
            try refresh()
        }catch is CancellationError{}catch{
            if !Task.isCancelled{message=(error as? SVError)?.localizedDescription ?? "รับข้อมูลไม่สำเร็จ ตรวจการเชื่อมต่อแล้วลองใหม่";try? refresh()}
        }
    }
    func loadFile(_ url:URL){
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        do{
            let meta=try url.resourceValues(forKeys:[.fileSizeKey,.contentTypeKey])
            guard (meta.fileSize ?? Wire.limit+1)<=Wire.limit else{throw SVError.message("ไฟล์ต้องไม่เกิน 5 MiB")}
            let bytes=try Data(contentsOf:url);guard bytes.count<=Wire.limit else{throw SVError.message("ไฟล์ใหญ่เกินกำหนด")}
            file=Payload(type:meta.contentType?.conforms(to:.image)==true ? "image":"file",name:String(url.lastPathComponent.prefix(200)),mime:meta.contentType?.preferredMIMEType ?? "application/octet-stream",data:Wire.encode(bytes))
        }catch{message="เปิดไฟล์ไม่ได้ หรือไฟล์ใหญ่เกิน 5 MiB"}
    }
    func export(_ p:Payload){
        do{
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent("sendviax-export",isDirectory:true)
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
            // Keep at most one user-requested export; no session keys are written.
            for old in (try? FileManager.default.contentsOfDirectory(at:dir,includingPropertiesForKeys:nil)) ?? []{try? FileManager.default.removeItem(at:old)}
            let name=p.name.components(separatedBy:CharacterSet(charactersIn:"/\\").union(.controlCharacters)).joined(separator:"_")
            let u=dir.appendingPathComponent(name.isEmpty ? "sendviax.bin":name)
            try p.bytes.write(to:u,options:[.atomic,.completeFileProtection]);shareURL=u
        }catch{message="เตรียมไฟล์ไม่สำเร็จ"}
    }
    func importShare(){
        guard let u=try? SharedInbox.file("draft.json"),let d=try? Data(contentsOf:u) else{return}
        defer{try? FileManager.default.removeItem(at:u)}
        guard let pending=try? JSONDecoder().decode(ShareDraft.self,from:d),pending.expires>Date(),(try? pending.payload.validate()) != nil else{return}
        file=pending.payload;message="รับจาก Share แล้ว ตรวจสอบก่อนส่ง"
    }
}
enum Palette {
    static let purple=Color(red:0.384,green:0.333,blue:0.91)
    static let ink=Color(red:0.16,green:0.16,blue:0.18)
    static let muted=Color(red:0.48,green:0.48,blue:0.52)
    static let soft=Color(red:0.966,green:0.966,blue:0.975)
}
struct PrimaryButton:ButtonStyle{
    func makeBody(configuration:Configuration)->some View{configuration.label.font(.system(size:15,weight:.medium)).frame(maxWidth:.infinity).padding(.vertical,15).foregroundStyle(.white).background(Palette.purple.opacity(configuration.isPressed ? 0.8:1),in:RoundedRectangle(cornerRadius:12))}
}
struct Panel<Content:View>:View {
    @ViewBuilder let content:Content
    var body:some View{VStack(alignment:.leading,spacing:17){content}.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(Color.black.opacity(0.065)))}
}
@main struct SendviaxApp:App{
    @StateObject private var model=AppModel()
    var body:some Scene{WindowGroup{RootView().environmentObject(model).tint(Palette.purple).preferredColorScheme(.light)}}
}
struct RootView:View {
    @EnvironmentObject var m:AppModel
    @Environment(\.scenePhase) var phase
    @State var tab=0
    @State var picker=false
    @State var confirm=false
    @State var keyboardTest=""
    var body:some View{
        TabView(selection:$tab){
            page("ส่งต่อ แล้วไปต่อ.","เลือกสิ่งที่ต้องการส่งไปอีกเครื่อง"){
                connection
                Panel {
                    HStack{Text("ส่งอะไรดี?").font(.title3.weight(.semibold));Spacer();Image(systemName:"paperplane").foregroundStyle(Palette.purple)}
                    Picker("ชนิดข้อมูล",selection:$m.linkType){Text("ข้อความ").tag(false);Text("ลิงก์").tag(true)}.pickerStyle(.segmented)
                    if let p=m.file{HStack{Image(systemName:"doc");Text(p.name).lineLimit(2);Spacer();Button("นำออก"){m.file=nil}}}
                    else{TextEditor(text:$m.draft).frame(height:120).padding(9).scrollContentBackground(.hidden).background(Palette.soft,in:RoundedRectangle(cornerRadius:10)).overlay(alignment:.topLeading){if m.draft.isEmpty{Text("พิมพ์ข้อความที่นี่…").foregroundStyle(Palette.muted).padding(17).allowsHitTesting(false)}}}
                    Button{picker=true}label:{Label("เลือกไฟล์หรือรูปภาพ",systemImage:"plus")}.font(.subheadline)
                    Divider()
                    Label("เข้ารหัสจากเครื่องนี้ · สูงสุด 5 MiB",systemImage:"lock").font(.caption).foregroundStyle(Palette.muted)
                    Button{confirm=true}label:{Label("ตรวจสอบและส่ง",systemImage:"arrow.up.right")}.buttonStyle(PrimaryButton()).disabled(m.room==nil || m.busy || (m.file==nil && m.draft.isEmpty)).opacity(m.room==nil ? 0.45:1)
                }
            }.tabItem{Label("ส่งข้อมูล",systemImage:"paperplane")}.tag(0)
            page("มาถึงแล้ว.","ข้อความและไฟล์ พร้อมใช้ต่อ"){
                Button("ล้างรายการที่ได้รับ",role:.destructive){m.clearInbox()}.disabled(m.items.isEmpty)
                if m.items.isEmpty{Panel{Image(systemName:"tray").font(.largeTitle).foregroundStyle(Palette.purple);Text("รอรายการจากอีกเครื่อง").font(.title3);Text("รับได้เมื่อเปิดแอป หรือใช้ Sendviax Keyboard ที่เปิด Full Access").foregroundStyle(Palette.muted)}}
                ForEach(m.items){item in Panel{
                    HStack{Image(systemName:item.payload.isText ? "text.alignleft":"doc");Text(item.payload.name).font(.headline);Spacer();Text(item.received ? "ได้รับ":"อัปโหลดแล้ว").font(.caption).foregroundStyle(Palette.muted)}
                    if item.payload.isText{Text(item.payload.text).font(.subheadline).textSelection(.enabled).lineLimit(10)}
                    Text("\(item.payload.bytes.count) bytes").font(.caption).foregroundStyle(Palette.muted)
                    if item.payload.isText{HStack{Button("คัดลอก"){guard let p=m.available(item) else{return};UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic:p.text]],options:[.localOnly:true,.expirationDate:Date().addingTimeInterval(300)]);m.message="คัดลอกแล้ว"}}.font(.subheadline)}
                    Button{if let p=m.available(item){m.export(p)}}label:{Label("บันทึก / แชร์ไฟล์",systemImage:"square.and.arrow.up")}.font(.subheadline)
                    DisclosureGroup("SHA-256"){Text(Wire.hash(item.payload)).font(.caption2.monospaced()).textSelection(.enabled)}.font(.caption)
                }}
            }.tabItem{Label("รายการ",systemImage:"tray")}.tag(1)
            page("คำที่ใช่ อยู่ใกล้มือ.","Sendviax Keyboard"){
                Panel{Image(systemName:"keyboard").font(.largeTitle).foregroundStyle(Palette.purple);Text("รับแล้ว แตะใช้ได้เลย").font(.title3.weight(.semibold));Text("เชื่อมต่อห้องครั้งเดียว แล้วเปิด Sendviax Keyboard ในแอปปลายทาง ข้อความแตะแทรกได้ รูปภาพแตะคัดลอกแล้ววาง").font(.subheadline).foregroundStyle(Palette.muted)
                    Text("1. เปิด Settings → General → Keyboard\n2. Keyboards → Add New Keyboard\n3. เลือก Sendviax Keyboard\n4. เปิด Allow Full Access เพื่อรับข้อมูล").font(.subheadline).lineSpacing(8)
                    Text("ใช้ปุ่ม 🌐 เพื่อกลับไปคีย์บอร์ดระบบ ช่องรหัสผ่านและบางแอปจะไม่อนุญาตคีย์บอร์ดเสริม").font(.caption).foregroundStyle(Palette.muted)
                }
                Panel{Text("ลองพิมพ์ตรงนี้").font(.headline);TextField("แตะแล้วเปลี่ยนคีย์บอร์ด",text:$keyboardTest).textFieldStyle(.roundedBorder);Button("ล้างรายการในคีย์บอร์ด",role:.destructive){m.clearInbox()};Text("รายการที่ได้รับเก็บในเครื่องไม่เกิน 5 นาที ไม่มีการอ่านคลิปบอร์ดเบื้องหลัง").font(.caption).foregroundStyle(Palette.muted)}
            }.tabItem{Label("คีย์บอร์ด",systemImage:"keyboard")}.tag(2)
        }
        .fileImporter(isPresented:$picker,allowedContentTypes:[.item]){result in if case .success(let u)=result{m.loadFile(u)}}
        .alert("ยืนยันการส่งข้อมูล",isPresented:$confirm){Button("ยกเลิก",role:.cancel){};Button("เข้ารหัสและส่ง"){m.send()}}message:{Text(Wire.warning(m.payload()))}
        .sheet(isPresented:Binding(get:{m.shareURL != nil},set:{if !$0{m.shareURL=nil}})){if let u=m.shareURL{ShareSheet(url:u)}}
        .task(id:phase){guard phase == .active else{return};m.importShare();while !Task.isCancelled{await m.poll();do{try await Task.sleep(nanoseconds:2_000_000_000)}catch{break}}}
        .task(id:phase){guard phase == .active else{return};while !Task.isCancelled{m.expireLocal();do{try await Task.sleep(nanoseconds:1_000_000_000)}catch{break}}}
    }
    func page<Content:View>(_ title:String,_ subtitle:String,@ViewBuilder content:()->Content)->some View{
        NavigationStack{ScrollView{VStack(alignment:.leading,spacing:22){
            HStack{Image(systemName:"bolt.fill").padding(9).background(Palette.purple,in:RoundedRectangle(cornerRadius:10)).foregroundStyle(.white);Text("Sendviax").font(.headline);Spacer();Text("รุ่นทดลอง").font(.caption2).foregroundStyle(Palette.muted)}
            VStack(alignment:.leading,spacing:8){Text(title).font(.system(size:32,weight:.semibold));Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted)}.padding(.vertical,10)
            if !m.message.isEmpty{HStack(alignment:.top){Image(systemName:"info.circle");Text(m.message).font(.caption);Spacer();Button{m.message=""}label:{Image(systemName:"xmark")}.accessibilityLabel("ปิดข้อความ")}.padding(14).background(Color.white,in:RoundedRectangle(cornerRadius:12))}
            content()
            Text("test-v0 · ใช้ข้อมูลสังเคราะห์สำหรับทดสอบ\nห้อง 15 นาที · รับเมื่อเปิดแอปหรือคีย์บอร์ด · ไม่มี Push เบื้องหลัง").font(.caption2).foregroundStyle(Palette.muted).frame(maxWidth:.infinity).multilineTextAlignment(.center)
        }.padding(22)}.background(Palette.soft).toolbar(.hidden,for:.navigationBar)}
    }
    @ViewBuilder var connection:some View{
        Panel{
            HStack{Text(m.room == nil ? "เชื่อมต่ออีกเครื่อง":"ห้องพร้อมใช้งาน").font(.headline);Spacer();Image(systemName:"antenna.radiowaves.left.and.right").foregroundStyle(Palette.purple)}
            if let r=m.room {
                Text("ห้อง \(r.sid.prefix(8)) · \(r.role=="owner" ? "ผู้สร้างห้อง":"ผู้เข้าร่วม")").font(.caption).foregroundStyle(Palette.muted)
                if let link=r.invite(){Button{UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic:link]],options:[.localOnly:true,.expirationDate:Date().addingTimeInterval(60)]);m.message="คัดลอกลิงก์แล้ว ให้เฉพาะเครื่องที่ไว้ใจ"}label:{Label("คัดลอกลิงก์เชิญ",systemImage:"link")}.buttonStyle(PrimaryButton())}
                Button("ออกจากห้อง",role:.destructive){m.close()}.disabled(m.busy)
            }else{
                Text("วางลิงก์เชิญเพื่อเชื่อมต่ออัตโนมัติ").font(.caption).foregroundStyle(Palette.muted)
                DisclosureGroup("ตั้งค่าเซิร์ฟเวอร์") {TextField("https://your-relay.example",text:$m.origin).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder)}
                Button{m.create()}label:{Label(m.busy ? "กำลังเชื่อมต่อ…":"สร้างห้อง",systemImage:"plus")}.buttonStyle(PrimaryButton()).disabled(m.busy)
                SecureField("วางลิงก์เชิญจากอีกเครื่อง",text:$m.inviteInput).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                Button("เข้าร่วมด้วยลิงก์"){m.join()}.disabled(m.busy || m.inviteInput.isEmpty)
            }
        }
    }
}
struct ShareSheet:UIViewControllerRepresentable{
    let url:URL
    func makeUIViewController(context:Context)->UIActivityViewController{UIActivityViewController(activityItems:[url],applicationActivities:nil)}
    func updateUIViewController(_ uiViewController:UIActivityViewController,context:Context){}
}
