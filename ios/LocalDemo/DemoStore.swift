import SwiftUI
import UIKit

enum DemoTab: String, CaseIterable, Identifiable {
    case messages, docs, contacts, work, me
    var id: String { rawValue }
    var title: String {
        switch self {
        case .messages: return "消息"
        case .docs: return "文档"
        case .contacts: return "通讯录"
        case .work: return "工作台"
        case .me: return "我"
        }
    }
    var symbol: String {
        switch self {
        case .messages: return "bubble.left.and.bubble.right"
        case .docs: return "doc.text"
        case .contacts: return "person.3"
        case .work: return "square.grid.2x2"
        case .me: return "person"
        }
    }
}

enum DemoRoute: Hashable {
    case profile, settings, department
    case editor(String), chat(String), web(String), detail(String)
}

struct WorkItem: Decodable, Hashable {
    let title: String
    let asset: String
}

struct WorkSection: Decodable {
    let title: String
    let items: [WorkItem]
}

struct DemoCatalog: Decodable {
    let workSections: [WorkSection]
    let assets: [String: String]
}

struct MessageItem: Identifiable {
    let id: Int
    let title: String
    let preview: String
    let date: String
    let symbol: String
    let color: Color
    let badge: String
    var groupIndex: Int? { (6...7).contains(id) ? id - 6 : nil }
}

@MainActor
final class DemoStore: ObservableObject {
    static let defaults: [String: String] = [
        "name": "用户A", "alias": "", "gender": "未设置", "external": "",
        "signature": "", "company": "重庆邮电大学", "invoice": "", "email": "", "address": "",
        "departmentCode": "部门001", "departmentPath": "重庆邮电大学/示例部门/示例小组/2023",
        "departmentName": "示例部门", "departmentGroup": "示例小组", "departmentYear": "2023",
        "groupNames": "讨论群 A\n项目群 B",
        "memberNames": (1...35).map { String(format: "成员%02d", $0) }.joined(separator: "\n")
    ]
    static let labels = ["name": "姓名", "alias": "别名", "gender": "性别", "external": "对外信息显示",
                         "signature": "工作签名", "company": "所在企业", "invoice": "发票抬头", "email": "邮箱", "address": "地址"]
    @Published private(set) var values: [String: String]
    // The original app keeps chat messages only until the process is restarted.
    @Published var chats: [String: [String]] = [:]
    @Published var chatStarred = false
    @Published var notice: String?
    let catalog: DemoCatalog
    private let stateURL: URL
    private var images: [String: UIImage] = [:]

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(testing ? "LocalDemoUITests" : "LocalDemo", isDirectory: true)
        stateURL = directory.appendingPathComponent("profile.json")
        if testing && ProcessInfo.processInfo.arguments.contains("--reset-demo") {
            try? FileManager.default.removeItem(at: stateURL)
        }
        var initial = Self.defaults
        var startupNotice: String?
        if FileManager.default.fileExists(atPath: stateURL.path) {
            do {
                let saved = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: stateURL))
                initial.merge(saved) { _, new in new }
            } catch {
                startupNotice = "本地资料读取失败，已显示默认资料。"
            }
        }
        values = initial
        do {
            guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "DemoResources")
                    ?? Bundle.main.url(forResource: "catalog", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            catalog = try JSONDecoder().decode(DemoCatalog.self, from: Data(contentsOf: url))
        } catch {
            catalog = DemoCatalog(workSections: [], assets: [:])
            startupNotice = "应用资源读取失败，请重新安装完整构建。"
        }
        notice = startupNotice
    }

    func value(_ key: String) -> String { values[key] ?? "" }

    @discardableResult
    func save(_ changes: [String: String]) -> Bool {
        var next = values
        next.merge(changes) { _, new in new }
        guard !(next["name"] ?? "").isEmpty else {
            notice = "请输入姓名"
            return false
        }
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: stateURL, options: .atomic)
            values = next
            return true
        } catch {
            notice = "无法保存本地资料，请检查设备可用空间后重试。"
            return false
        }
    }

    func names(_ key: String) -> [String] {
        value(key).components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    func groupName(_ index: Int) -> String {
        let list = names("groupNames")
        return index < list.count ? list[index] : (index == 0 ? "讨论群 A" : "项目群 B")
    }

    func memberName(_ index: Int) -> String {
        let list = names("memberNames")
        return index < list.count ? list[index] : String(format: "成员%02d", index + 1)
    }

    func avatar(_ key: String) -> UIImage? {
        guard let data = Data(base64Encoded: value(key)) else { return nil }
        return UIImage(data: data)
    }

    func saveAvatar(data: Data, key: String) {
        guard let source = UIImage(data: data), source.size.width > 0, source.size.height > 0 else {
            notice = "无法读取该图片，请选择 JPG 或 PNG。"
            return
        }
        let edge: CGFloat = key == "avatar" ? 256 : 192
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: edge, height: edge), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: edge, height: edge))
            let scale = edge / min(source.size.width, source.size.height)
            let width = source.size.width * scale
            let height = source.size.height * scale
            source.draw(in: CGRect(x: (edge - width) / 2, y: (edge - height) / 2, width: width, height: height))
        }
        guard let jpeg = image.jpegData(compressionQuality: key == "avatar" ? 0.9 : 0.86) else {
            notice = "图片处理失败"
            return
        }
        save([key: jpeg.base64EncodedString()])
    }

    func asset(_ key: String) -> UIImage? {
        if let image = images[key] { return image }
        guard let path = catalog.assets[key], let root = Bundle.main.resourceURL else { return nil }
        for candidate in [root.appendingPathComponent("DemoResources").appendingPathComponent(path), root.appendingPathComponent(path)] {
            if let image = UIImage(contentsOfFile: candidate.path) {
                images[key] = image
                return image
            }
        }
        return nil
    }

    var messages: [MessageItem] {
        [
            MessageItem(id: 0, title: "通知中心", preview: "有新的应用通知", date: "昨天", symbol: "doc.text", color: .orange, badge: ""),
            MessageItem(id: 1, title: "周报提醒", preview: "查看本周工作摘要", date: "星期五", symbol: "list.clipboard", color: .cyan, badge: "16"),
            MessageItem(id: 2, title: "校园服务", preview: "服务动态", date: "星期五", symbol: "pencil.tip", color: .blue, badge: "16"),
            MessageItem(id: 3, title: "行业资讯", preview: "最新资讯与服务通知", date: "星期五", symbol: "newspaper", color: .yellow, badge: "·"),
            MessageItem(id: 4, title: "待办提醒", preview: "你有新的待办事项", date: "星期四", symbol: "bell", color: .blue, badge: "5"),
            MessageItem(id: 5, title: "文件空间", preview: "空间使用情况提醒", date: "星期一", symbol: "shippingbox", color: .blue, badge: "2"),
            MessageItem(id: 6, title: groupName(0), preview: "群成员：收到，谢谢", date: "11/3", symbol: "person.3", color: .blue, badge: ""),
            MessageItem(id: 7, title: groupName(1), preview: "群成员：项目资料已更新", date: "10/18", symbol: "person.3", color: .blue, badge: ""),
            MessageItem(id: 8, title: "团队通知", preview: "应用版本与服务更新", date: "10/14", symbol: "bubble.left.and.bubble.right", color: .blue, badge: "1")
        ]
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Color {
    static let demoBackground = Color(red: 237 / 255, green: 239 / 255, blue: 246 / 255)
    static let demoHeader = Color(red: 229 / 255, green: 241 / 255, blue: 255 / 255)
}
