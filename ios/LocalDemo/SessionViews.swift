import SwiftUI

@MainActor
struct DepartmentView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingSearch = false
    @State private var search = ""

    private var breadcrumbs: [String] {
        var parts = store.value("departmentPath").split(separator: "/").dropFirst().map(String.init)
        if parts.last != store.value("departmentCode") { parts.append(store.value("departmentCode")) }
        return parts
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingSearch { SearchField(text: $search, prompt: "搜索成员") }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(breadcrumbs.indices, id: \.self) { index in
                        if index > 0 { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                        Text(breadcrumbs[index]).foregroundStyle(index == breadcrumbs.count - 1 ? Color.blue : Color.gray)
                    }
                }.font(.system(size: 13)).padding(17)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<35, id: \.self) { index in
                        let name = store.memberName(index)
                        if search.trimmed.isEmpty || name.contains(search.trimmed) {
                            HStack(spacing: 13) {
                                AvatarPicker(avatarKey: "memberAvatar\(index)", size: 38)
                                NavigationLink(value: DemoRoute.chat(name)) {
                                    Text(name).font(.system(size: 17)).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("member.\(index)")
                            }.padding(.horizontal, 17)
                            Divider().padding(.horizontal, 17)
                        }
                    }
                    Text("共35人").font(.system(size: 14)).foregroundStyle(.tertiary).padding(16)
                }.background { Watermarks(text: store.value("name") + "@" + store.value("company") + "9391") }
            }
        }.background(.white).navigationTitle(store.value("departmentCode"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingSearch.toggle() } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索成员")
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("关闭部门")
                }
            }
    }
}

@MainActor
struct ChatView: View {
    @EnvironmentObject private var store: DemoStore
    let title: String
    @State private var draft = ""
    @FocusState private var inputFocused: Bool
    private var messages: [String] { store.chats[title] ?? [] }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 10) {
                            Spacer(minLength: 45)
                            Text(messages[index]).font(.system(size: 16)).textSelection(.enabled)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(Color(red: 0.78, green: 0.90, blue: 1), in: RoundedRectangle(cornerRadius: 5))
                            AvatarView(size: 35)
                        }.id(index)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(.horizontal, 15).padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { Watermarks(text: store.value("name") + "@" + store.value("company") + "9391") }
            .background(Color.demoBackground)
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: inputFocused) { _, focused in
                if focused { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .navigationTitle(title)
        .toolbarBackground(Color.demoBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.chatStarred.toggle()
                    store.notice = store.chatStarred ? "已收藏此会话" : "已取消收藏"
                } label: { Image(systemName: store.chatStarred ? "star.fill" : "star") }.accessibilityLabel("会话收藏")
                Button { store.notice = "本地会话演示" } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多")
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Button { store.notice = "暂不支持语音输入" } label: { Image(systemName: "waveform.circle") }.accessibilityLabel("语音输入")
            TextField("发消息或按住…", text: $draft)
                .font(.system(size: 14)).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 3))
                .focused($inputFocused).submitLabel(.send).onSubmit(send)
                .accessibilityLabel("消息内容").accessibilityIdentifier("chat.input")
            Button {
                draft += "😊"
                inputFocused = true
            } label: { Image(systemName: "face.smiling") }.accessibilityLabel("表情")
            if draft.trimmed.isEmpty {
                Button { store.notice = "暂不支持附件" } label: { Image(systemName: "plus.circle") }.accessibilityLabel("添加附件")
            } else {
                Button("发送", action: send).font(.system(size: 13))
                    .foregroundStyle(.white).padding(8).background(.blue, in: RoundedRectangle(cornerRadius: 4))
                    .accessibilityIdentifier("chat.send")
            }
        }.font(.system(size: 23)).foregroundStyle(.primary).padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color(red: 0.97, green: 0.98, blue: 0.99))
    }

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        store.chats[title, default: []].append(text)
        draft = ""
    }
}

@MainActor
struct WebDemoView: View {
    let title: String
    @State private var failed = false
    @State private var attempt = 0
    var body: some View {
        VStack(spacing: 0) {
            if failed {
                Button {
                    retry()
                } label: {
                    VStack(spacing: 12) {
                        AssetIcon(key: "reload", symbol: "doc.badge.ellipsis", size: 62).padding(.bottom, 3)
                        Text("无法打开页面").font(.system(size: 19)).accessibilityIdentifier("web.error")
                        Text("错误信息(-8,net::ERR_TIMED_OUT)").font(.system(size: 12))
                        Text("轻触屏幕重新加载").font(.system(size: 16))
                        Spacer()
                    }.foregroundStyle(.gray).padding(.top, 80).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).background(Color(.systemGray6)).accessibilityIdentifier("web.retry")
            } else {
                ProgressView().progressViewStyle(.linear).tint(.blue).accessibilityLabel("正在加载")
                Spacer()
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.white)
            .navigationTitle(failed ? "无法打开页面" : title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: retry) { Image(systemName: "ellipsis") }.accessibilityLabel("重新加载")
                }
            }
            .task(id: attempt) {
                do { try await Task.sleep(for: .seconds(2)) }
                catch { return }
                failed = true
            }
    }

    private func retry() {
        failed = false
        attempt += 1
    }
}
