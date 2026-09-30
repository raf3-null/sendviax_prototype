import UIKit
import UniformTypeIdentifiers

final class ShareController:UIViewController {
    private let status=UILabel()
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor = .systemBackground
        let stack=UIStackView();stack.axis = .vertical;stack.spacing=24;stack.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:28),stack.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-28),stack.centerYAnchor.constraint(equalTo:view.centerYAnchor)])
        let title=UILabel();title.text="ส่งต่อด้วย Sendviax";title.font = .systemFont(ofSize:26,weight:.semibold)
        status.text="เก็บเป็นร่างในเครื่อง แล้วเปิดแอปเพื่อยืนยันส่ง";status.numberOfLines=0;status.textColor = .secondaryLabel
        let save=UIButton(type:.system);save.setTitle("เก็บร่างแล้วปิด",for:.normal);save.addTarget(self,action:#selector(stage),for:.touchUpInside)
        let cancel=UIButton(type:.system);cancel.setTitle("ยกเลิก",for:.normal);cancel.addTarget(self,action:#selector(done),for:.touchUpInside)
        [title,status,save,cancel].forEach{stack.addArrangedSubview($0)}
    }
    @objc private func done(){extensionContext?.completeRequest(returningItems:nil)}
    @objc private func stage(){
        guard let items=extensionContext?.inputItems as? [NSExtensionItem],let provider=items.first?.attachments?.first else{status.text="ไม่พบรายการ";return}
        let type=provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? UTType.url.identifier : provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) ? UTType.text.identifier : nil
        guard let type else{status.text="Share รุ่นนี้รับข้อความ / ลิงก์ก่อน รูปและไฟล์ให้เลือกจากแอปหลัก";return}
        provider.loadItem(forTypeIdentifier:type,options:nil){[weak self] value,_ in
            let text=(value as? URL)?.absoluteString ?? (value as? String)
            DispatchQueue.main.async{
                guard let self,let text,text.utf8.count<=Wire.limit else{self?.status.text="อ่านรายการไม่ได้ หรือข้อมูลใหญ่เกินกำหนด";return}
                do{
                    var url=try SharedInbox.file("draft.json")
                    let pending=ShareDraft(payload:Payload.text(text,link:type==UTType.url.identifier),expires:Date().addingTimeInterval(300))
                    try JSONEncoder().encode(pending).write(to:url,options:[.atomic,.completeFileProtection])
                    var attr=URLResourceValues();attr.isExcludedFromBackup=true;try url.setResourceValues(attr)
                    self.done()
                }catch{self.status.text="ตั้งค่า App Group ของแอปและ Share Extension ใน Xcode ก่อน"}
            }
        }
    }
}
