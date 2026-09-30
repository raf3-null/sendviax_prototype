import UIKit

// Network runs only while visible with Full Access. Never read host text or clipboard.
final class KeyboardController:UIInputViewController {
    private let root=UIStackView()
    private let purple=UIColor(red:0.384,green:0.333,blue:0.91,alpha:1)
    private var language="EN"
    private var shift=false
    private var symbols=false
    private var inbox=false
    private var keyboardHeight:NSLayoutConstraint?
    private let feedback=UISelectionFeedbackGenerator()
    private var receiver:SharedReceiver?
    private var receiveTask:Task<Void,Never>?
    private var refreshTask:Task<Void,Never>?
    private var visible=false
    private var hostActive=true
    private var records:[ReceivedRecord]=[]
    private var status="เชื่อมต่อห้องในแอป Sendviax ก่อน"
    private var signature=""
    override func viewDidLoad(){
        super.viewDidLoad()
        view.backgroundColor=UIColor(white:0.955,alpha:1)
        root.axis = .vertical;root.spacing=7;root.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:6),root.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-6),root.topAnchor.constraint(equalTo:view.topAnchor,constant:7),root.bottomAnchor.constraint(lessThanOrEqualTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-5)])
        let height=view.heightAnchor.constraint(equalToConstant:330);height.priority = .defaultHigh;height.isActive=true;keyboardHeight=height
        NotificationCenter.default.addObserver(self,selector:#selector(suspendReceive),name:.NSExtensionHostDidEnterBackground,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(resumeReceive),name:.NSExtensionHostDidBecomeActive,object:nil)
        render()
    }
    override func viewWillAppear(_ animated:Bool){super.viewWillAppear(animated);visible=true;startReceive();refreshInbox()}
    override func viewWillDisappear(_ animated:Bool){super.viewWillDisappear(animated);visible=false;stopReceive()}
    @objc private func suspendReceive(){hostActive=false;stopReceive()}
    @objc private func resumeReceive(){hostActive=true;if visible{startReceive()}}
    private func stopReceive(){receiveTask?.cancel();receiveTask=nil;refreshTask?.cancel();refreshTask=nil;records=[];signature=""}
    private func startReceive(){
        guard visible,hostActive,refreshTask==nil else{return}
        refreshTask=Task{[weak self] in
            while !Task.isCancelled {
                guard let self else{return}
                refreshInbox()
                if hasFullAccess && receiveTask==nil {beginPolling()}
                if !hasFullAccess {receiveTask?.cancel();receiveTask=nil;receiver=nil}
                try? await Task.sleep(nanoseconds:1_000_000_000)
            }
        }
    }
    private func beginPolling(){
        do{
            if receiver==nil {receiver=SharedReceiver(channel:try SharedChannel.live(),relay:Relay(responseLimit:12*1024*1024))}
        }catch{status=error.localizedDescription;return}
        receiveTask=Task{[weak self] in
            while !Task.isCancelled {
                guard let self,visible,hostActive,hasFullAccess,let receiver else{return}
                do{
                    try await receiver.poll{[weak self] in self?.visible==true && self?.hostActive==true && self?.hasFullAccess==true};try Task.checkCancellation()
                    status=(try receiver.channel.snapshot())==nil ? "เชื่อมต่อห้องในแอป Sendviax ก่อน":"เชื่อมต่อแล้ว · รับอัตโนมัติขณะเปิดคีย์บอร์ด"
                }catch{
                    if Task.isCancelled{return}
                    status=(error as? SVError)?.localizedDescription ?? "เชื่อมต่อไม่ได้ กำลังลองใหม่…"
                }
                if !Task.isCancelled && visible && hasFullAccess {refreshInbox()}
                try? await Task.sleep(nanoseconds:2_000_000_000)
            }
        }
    }
    private func refreshInbox(){
        guard visible else{return}
        if !hasFullAccess {records=[];status="เปิด Allow Full Access ใน Settings → Keyboard → Sendviax เพื่อรับรายการ"}
        else if let channel=receiver?.channel {
            do{records=try channel.records();if try channel.snapshot()==nil{status="ห้องหมดอายุหรือยังไม่ได้เชื่อมต่อ เปิดแอปเพื่อเชื่อมต่อ"}}
            catch{records=[];status=(error as? SVError)?.localizedDescription ?? "อ่านรายการร่วมไม่สำเร็จ"}
        }
        let next="\(hasFullAccess)-\(status)-"+records.map{$0.id}.joined()
        if signature != next {signature=next;render()}
    }
    private func use(_ record:ReceivedRecord){
        guard visible,hostActive,hasFullAccess,let channel=receiver?.channel else{return}
        do{
            guard let fresh=try channel.records().first(where:{$0.id==record.id}),
                  let payload=try channel.payload(record.id) else{refreshInbox();return}
            guard fresh.deadline>SessionClock.now,hasFullAccess else{refreshInbox();return}
            if let text=KeyboardContent.text(payload) {
                textDocumentProxy.insertText(text);status="แทรกข้อความแล้ว"
            }else if let type=KeyboardContent.imageType(payload),KeyboardContent.thumbnail(payload) != nil {
                let remaining=fresh.deadline-SessionClock.now
                guard remaining>0,hasFullAccess else{refreshInbox();return}
                UIPasteboard.general.setItems([[type:payload.bytes]],options:[.localOnly:true,.expirationDate:Date().addingTimeInterval(remaining)])
                status="คัดลอกรูปแล้ว · แตะค้างในช่องปลายทางแล้วเลือกวาง"
            }else{status="รายการนี้ใช้ผ่านแอป Sendviax"}
        }catch{status=(error as? SVError)?.localizedDescription ?? "เปิดรายการไม่สำเร็จ"}
        signature="";refreshInbox()
    }
    private func key(_ text:String,accent:Bool=false,action:@escaping()->Void)->UIButton{
        var config=UIButton.Configuration.plain()
        config.title=text;config.baseForegroundColor=accent ? .white:UIColor(white:0.2,alpha:1)
        config.background.backgroundColor=accent ? purple:.white
        config.background.cornerRadius=7
        config.contentInsets=NSDirectionalEdgeInsets(top:0,leading:1,bottom:0,trailing:1)
        let b=UIButton(configuration:config,primaryAction:UIAction{[weak self]_ in self?.feedback.selectionChanged();action()})
        b.titleLabel?.font = .systemFont(ofSize:16)
        b.heightAnchor.constraint(equalToConstant:43).isActive=true
        b.layer.shadowColor=UIColor.black.cgColor;b.layer.shadowOpacity=0.12;b.layer.shadowOffset=CGSize(width:0,height:1);b.layer.shadowRadius=0
        return b
    }
    private func row(_ keys:[UIButton]){
        let row=UIStackView(arrangedSubviews:keys);row.axis = .horizontal;row.spacing=5;row.distribution = .fillEqually;root.addArrangedSubview(row)
    }
    private func render(){
        keyboardHeight?.constant = language=="ไทย" && !inbox && !symbols ? 380:330
        root.arrangedSubviews.forEach{root.removeArrangedSubview($0);$0.removeFromSuperview()}
        let title=UILabel();title.text="ϟ  Sendviax";title.font = .systemFont(ofSize:15,weight:.semibold);title.textColor=purple
        let toggle=key(inbox ? "⌨  แป้นพิมพ์":"▤  รายการ (\(records.count))",action:{[weak self] in guard let self else{return};inbox.toggle();render()})
        toggle.titleLabel?.font = .systemFont(ofSize:12)
        let bar=UIStackView(arrangedSubviews:[title,UIView(),toggle]);bar.spacing=8;bar.layoutMargins=UIEdgeInsets(top:0,left:7,bottom:2,right:4);bar.isLayoutMarginsRelativeArrangement=true;root.addArrangedSubview(bar)
        if inbox{
            let scroll=UIScrollView();scroll.heightAnchor.constraint(equalToConstant:193).isActive=true
            let panel=UIStackView();panel.axis = .vertical;panel.spacing=8;panel.translatesAutoresizingMaskIntoConstraints=false
            scroll.addSubview(panel)
            NSLayoutConstraint.activate([panel.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor),panel.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor),panel.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor),panel.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor),panel.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor)])
            let note=UILabel();note.text=status;note.numberOfLines=0;note.font = .systemFont(ofSize:12);note.textColor = .secondaryLabel;panel.addArrangedSubview(note)
            if records.isEmpty {
                let empty=UILabel();empty.text=hasFullAccess ? "ยังไม่มีรายการ · ส่งจากอีกเครื่องได้เลย":"พิมพ์ได้ตามปกติ แม้ยังไม่เปิด Full Access"
                empty.numberOfLines=0;empty.font = .systemFont(ofSize:14);empty.textColor = .darkGray;panel.addArrangedSubview(empty)
            }
            for record in records {
                let line=UIStackView();line.spacing=8;line.alignment = .center
                var title=record.name
                autoreleasepool { if let p=try? receiver?.channel.payload(record.id) {
                    if let text=KeyboardContent.text(p){title=String(text.prefix(80))}
                    else if record.type=="image",let image=KeyboardContent.thumbnail(p) {
                        let preview=UIImageView(image:UIImage(cgImage:image));preview.contentMode = .scaleAspectFit
                        preview.widthAnchor.constraint(equalToConstant:44).isActive=true;preview.heightAnchor.constraint(equalToConstant:44).isActive=true
                        preview.accessibilityLabel="ตัวอย่างรูปภาพ";line.addArrangedSubview(preview)
                    }
                }}
                let button=key((record.type=="image" ? "คัดลอกรูป · ":"")+title){[weak self] in self?.use(record)}
                button.titleLabel?.font = .systemFont(ofSize:13);button.titleLabel?.lineBreakMode = .byTruncatingTail
                line.addArrangedSubview(button);panel.addArrangedSubview(line)
            }
            root.addArrangedSubview(scroll)
        }else{
            let en=shift ? ["QWERTYUIOP","ASDFGHJKL","ZXCVBNM"]:["qwertyuiop","asdfghjkl","zxcvbnm"]
            let th=shift ? ["+๑๒๓๔ู฿๕๖๗๘๙","๐\"ฎฑธํ๊ณฯญฐ,ฅ","ฤฆฏโฌ็๋ษศซ.","()ฉฮฺ์?ฒฬฦ"]:["ๅ/-ภถุึคตจขช","ๆไำพะัีรนยบลฃ","ฟหกดเ้่าสวง","ผปแอิืทมใฝ"]
            let rows=symbols ? ["1234567890","@#฿%&*()-","!?.,:;/_+"]:language=="ไทย" ? th:en
            for (index,characters) in rows.enumerated(){
                var keys=characters.unicodeScalars.map{ch in key(String(ch)){[weak self] in self?.textDocumentProxy.insertText(String(ch));if self?.shift==true && self?.language=="EN"{self?.shift=false;self?.render()}}}
                if index==rows.count-1 {
                    keys.insert(key(shift ? "⇧":"↑"){[weak self] in self?.shift.toggle();self?.render()},at:0)
                    let delete=key("⌫"){[weak self] in self?.textDocumentProxy.deleteBackward()}
                    delete.accessibilityLabel="ลบ";keys.append(delete)
                }
                row(keys)
            }
        }
        let globe=key("🌐"){}
        globe.addTarget(self,action:#selector(handleInputModeList(from:with:)),for:.allTouchEvents)
        globe.accessibilityLabel="เปลี่ยนคีย์บอร์ด"
        let bottom=UIStackView();bottom.axis = .horizontal;bottom.spacing=5
        let number=key(symbols ? "ABC":"123"){[weak self] in self?.symbols.toggle();self?.inbox=false;self?.render()}
        let lang=key(language){[weak self] in self?.language=self?.language=="EN" ? "ไทย":"EN";self?.symbols=false;self?.render()}
        let space=key("เว้นวรรค"){[weak self] in self?.textDocumentProxy.insertText(" ")}
        let enter=key("↵",accent:true){[weak self] in self?.textDocumentProxy.insertText("\n")};enter.accessibilityLabel="ขึ้นบรรทัดใหม่"
        [number,globe,lang,space,enter].forEach{bottom.addArrangedSubview($0)}
        for b in [number,globe,lang,enter]{b.widthAnchor.constraint(equalToConstant:48).isActive=true}
        root.addArrangedSubview(bottom)
    }
}
