import SwiftUI

@MainActor
struct MeView: View {
    @EnvironmentObject private var store: DemoStore
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "我", background: .demoBackground)
            ScrollView {
                VStack(spacing: 17) {
                    VStack(spacing: 0) {
                        NavigationLink(value: DemoRoute.profile) {
                            VStack(alignment: .leading, spacing: 32) {
                                HStack(alignment: .top, spacing: 5) {
                                    Text(store.value("company")).font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                                    Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                                    Spacer(minLength: 6)
                                    AvatarView(size: 58)
                                }
                                Text(store.value("name")).font(.system(size: 23, weight: .semibold))
                            }.padding(17).padding(.top, 4).frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("openProfile")
                        Divider().padding(.horizontal, 17)
                        NavigationLink(value: DemoRoute.profile) {
                            HStack {
                                Text("对外名片")
                                Spacer()
                                AssetIcon(key: "qr", symbol: "qrcode", size: 20)
                                Image(systemName: "chevron.right").font(.caption)
                            }.foregroundStyle(.secondary).padding(17).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }.background(.white, in: RoundedRectangle(cornerRadius: 11))
                    menuGroup([("收藏", "shippingbox", Color.orange), ("红包", "envelope", .red), ("通勤", "location", .orange)])
                    menuGroup([("帮助", "questionmark.bubble", Color.blue), ("设置", "gearshape", .gray)])
                }.padding(17)
            }
        }.background(Color.demoBackground)
    }

    private func menuGroup(_ entries: [(String, String, Color)]) -> some View {
        VStack(spacing: 0) {
            ForEach(entries.indices, id: \.self) { index in
                let item = entries[index]
                NavigationLink(value: item.0 == "设置" ? DemoRoute.settings : DemoRoute.detail(item.0)) {
                    HStack(spacing: 16) {
                        AssetIcon(key: "me-\(item.0)", symbol: item.1).foregroundStyle(item.2)
                        Text(item.0).font(.system(size: 18))
                        Spacer()
                        if item.0 == "通勤" {
                            AvatarView(key: "commute-avatar", size: 25)
                            Text("在用").foregroundStyle(.secondary)
                        }
                    }.padding(.horizontal, 17).frame(height: 54).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier(item.0 == "设置" ? "openSettings" : "menu.\(item.0)")
                if index < entries.count - 1 { Divider().padding(.leading, 58).padding(.trailing, 17) }
            }
        }.background(.white, in: RoundedRectangle(cornerRadius: 11))
    }
}

@MainActor
struct MessagesView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var showingSearch = false
    @State private var search = ""
    private var filtered: [MessageItem] {
        store.messages.filter { search.trimmed.isEmpty || ($0.title + $0.preview + $0.date).contains(search.trimmed) }
    }
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "消息", search: $showingSearch, action: "发起会话", actionSymbol: "plus.circle")
                .overlay(alignment: .leading) {
                    NavigationLink(value: DemoRoute.detail("消息筛选")) { Image(systemName: "line.3.horizontal.decrease") }
                        .foregroundStyle(.primary).padding(.leading, 17).accessibilityLabel("消息菜单")
                }
            if showingSearch { SearchField(text: $search, prompt: "搜索消息") }
            QuickLinks(items: [("全部⌄", "全部消息", "bubble.left"), ("日程", "日程", "calendar"), ("待办", "待办", "checkmark.circle"), ("会议", "会议", "video")])
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { item in
                        HStack(alignment: .top, spacing: 13) {
                            if let group = item.groupIndex {
                                AvatarPicker(avatarKey: "groupAvatar\(group)", size: 51, group: true)
                            } else {
                                NavigationLink(value: DemoRoute.chat(item.title)) {
                                    messageIcon(item)
                                }.buttonStyle(.plain)
                            }
                            NavigationLink(value: DemoRoute.chat(item.title)) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(item.title).font(.system(size: 18)).lineLimit(1)
                                        Spacer(minLength: 4)
                                        Text(item.date).font(.system(size: 13)).foregroundStyle(.tertiary)
                                    }
                                    Text(item.preview).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(1)
                                    Divider().padding(.top, 10)
                                }.padding(.top, 3).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }.padding(.horizontal, 15).padding(.top, 13)
                    }
                }
            }
        }.background(.white)
    }

    @ViewBuilder
    private func messageIcon(_ item: MessageItem) -> some View {
        if let image = store.asset("msg-\(item.title)") {
            // The source bitmap already includes its notification indicator.
            Image(uiImage: image).resizable().scaledToFit().frame(width: 51, height: 51)
        } else {
            ZStack(alignment: .topTrailing) {
                AssetIcon(key: "msg-\(item.title)", symbol: item.symbol, size: 39)
                    .foregroundStyle(.white).padding(6).background(item.color, in: RoundedRectangle(cornerRadius: 8))
                if !item.badge.isEmpty {
                    Text(item.badge).font(.system(size: 11)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(.red, in: Capsule()).offset(x: 6, y: -6)
                }
            }
        }
    }
}

struct QuickLinks: View {
    let items: [(String, String, String)]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                NavigationLink(value: DemoRoute.detail(item.1)) {
                    HStack(spacing: 5) {
                        Image(systemName: item.2)
                        Text(item.0).lineLimit(1).minimumScaleFactor(0.7)
                    }.font(.system(size: 14)).foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 52)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 15).overlay(alignment: .bottom) { Divider().padding(.horizontal, 15) }
    }
}

@MainActor
struct DocumentsView: View {
    @State private var showingSearch = false
    @State private var search = ""
    private let documents = [("项目资料示例", "用户A提交了结果"), ("欢迎使用本地文档演示", "本地演示文档")]
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "文档", search: $showingSearch, action: "新建文档")
            if showingSearch { SearchField(text: $search, prompt: "搜索文档") }
            QuickLinks(items: [("与我相关⌄", "与我相关", "doc.text"), ("智能文档", "智能文档", "doc.text"), ("智能表格", "智能表格", "tablecells")])
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(documents.indices, id: \.self) { index in
                        let item = documents[index]
                        if search.trimmed.isEmpty || (item.0 + item.1 + "近期").contains(search.trimmed) {
                            NavigationLink(value: DemoRoute.detail(item.0)) {
                                HStack(alignment: .top, spacing: 17) {
                                    Image(systemName: "doc.text.fill").font(.system(size: 28)).foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(item.0).font(.system(size: 17)).lineLimit(1)
                                            Spacer()
                                            Text("近期").font(.system(size: 13)).foregroundStyle(.tertiary)
                                        }
                                        Text(item.1).font(.system(size: 14)).foregroundStyle(.secondary)
                                        Divider().padding(.top, 8)
                                    }
                                }.padding(.horizontal, 15).padding(.top, 14).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }.background(.white)
    }
}

@MainActor
struct ContactsView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var showingSearch = false
    @State private var search = ""
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: store.value("company"), search: $showingSearch)
            if showingSearch { SearchField(text: $search, prompt: "搜索通讯录") }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    contactSection("外部联系人", entries: [("外部联系人", "bubble.left.and.bubble.right", .green), ("添加外部联系人", "person.badge.plus", .green)])
                    contactSection("智能机器人", entries: [("智能机器人", "sparkles", .blue)])
                    contactSection("企业通讯录", entries: [("本科生", "folder.fill", .blue)])
                    Text("共35人").font(.system(size: 15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(17)
                    Spacer(minLength: 160)
                }.background { Watermarks(text: "演示资料 · 隐私示例") }
            }
        }.background(.white)
    }

    private func contactSection(_ title: String, entries: [(String, String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 18).padding(.bottom, 7)
            ForEach(entries.indices, id: \.self) { index in
                let item = entries[index]
                if search.trimmed.isEmpty || item.0.contains(search.trimmed) {
                    NavigationLink(value: DemoRoute.detail(item.0)) {
                        HStack(spacing: 13) {
                            AssetIcon(key: "contact-\(item.0)", symbol: item.1, size: 38).foregroundStyle(item.2)
                            Text(item.0).font(.system(size: 18))
                            Spacer()
                        }.frame(height: 65).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
            }
        }.padding(.horizontal, 17)
    }
}

@MainActor
struct WorkView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var showingSearch = false
    @State private var search = ""
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "工作台", search: $showingSearch, action: "管理工作台", actionSymbol: "line.3.horizontal")
            if showingSearch { SearchField(text: $search, prompt: "搜索应用") }
            ScrollView {
                VStack(spacing: 10) {
                    if let image = store.asset("banner") {
                        Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    ForEach(store.catalog.workSections.indices, id: \.self) { index in
                        workSection(store.catalog.workSections[index], sectionIndex: index)
                    }
                }.padding(.horizontal, 10).padding(.bottom, 10)
            }
        }.background(Color.demoBackground)
    }

    private func workSection(_ section: WorkSection, sectionIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !section.title.isEmpty {
                Text(section.title).font(.system(size: 13)).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            if section.title == "今日安排" {
                Image(systemName: "calendar").foregroundStyle(.blue).frame(height: 42, alignment: .top)
            } else {
                LazyVGrid(columns: columns, spacing: 19) {
                    ForEach(section.items.indices, id: \.self) { index in
                        let item = section.items[index]
                        if search.trimmed.isEmpty || item.title.contains(search.trimmed) {
                            NavigationLink(value: DemoRoute.web(item.title)) {
                                VStack(spacing: 8) {
                                    if item.asset == "work-日程" {
                                        Image(systemName: "calendar").font(.system(size: 28))
                                            .foregroundStyle(.white).frame(width: 44, height: 44)
                                            .background(.yellow, in: RoundedRectangle(cornerRadius: 7))
                                    } else {
                                        AssetIcon(key: item.asset, symbol: "square.grid.2x2", size: 44).foregroundStyle(.blue)
                                    }
                                    Text(item.title).font(.system(size: 12)).multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
                                }.frame(minHeight: 77, alignment: .top).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("work.item.\(sectionIndex).\(index)")
                        }
                    }
                }
            }
        }.padding(.horizontal, 8).padding(.top, 13).padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 9))
    }
}
