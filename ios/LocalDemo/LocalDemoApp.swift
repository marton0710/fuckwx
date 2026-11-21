import SwiftUI
import PhotosUI

@main
struct LocalDemoApp: App {
    @StateObject private var store = DemoStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .tint(.blue)
        }
    }
}

@MainActor
struct RootView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var tab: DemoTab = .me
    @State private var path: [DemoRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case .me: MeView()
                    case .messages: MessagesView()
                    case .docs: DocumentsView()
                    case .contacts: ContactsView()
                    case .work: WorkView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DemoRoute.self) { route in
                destination(route)
                    .toolbar(.visible, for: .navigationBar)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert("提示", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
            Button("知道了", role: .cancel) { store.notice = nil }
        } message: { Text(store.notice ?? "") }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DemoTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 4) {
                        AssetIcon(key: "nav-\(item.rawValue)-\(tab == item ? "on" : "off")", symbol: item.symbol, size: 27)
                        Text(item.title).font(.system(size: 12))
                    }
                    .foregroundStyle(tab == item ? Color.blue : Color.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 57)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
                .accessibilityIdentifier("tab.\(item.rawValue)")
            }
        }
        .background(Color(red: 0.98, green: 0.985, blue: 1))
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private func destination(_ route: DemoRoute) -> some View {
        switch route {
        case .profile: ProfileView()
        case .settings: SettingsView()
        case .department: DepartmentView()
        case .editor(let key): ProfileEditorView(key: key)
        case .chat(let title): ChatView(title: title)
        case .web(let title): WebDemoView(title: title)
        case .detail(let title): DetailView(title: title)
        }
    }
}

@MainActor
struct AssetIcon: View {
    @EnvironmentObject private var store: DemoStore
    let key: String
    let symbol: String
    var size: CGFloat = 28
    var body: some View {
        Group {
            if let image = store.asset(key) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: symbol).resizable().scaledToFit().padding(3)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
struct AvatarView: View {
    @EnvironmentObject private var store: DemoStore
    var key = "avatar"
    var size: CGFloat = 52
    var group = false
    var body: some View {
        Group {
            if let image = store.avatar(key) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(red: 0.88, green: 0.90, blue: 0.93)
                    Image(systemName: group ? "person.3.fill" : "person.fill")
                        .resizable().scaledToFit().padding(group ? 9 : 5)
                        .foregroundStyle(Color(red: 0.68, green: 0.73, blue: 0.79))
                }
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

@MainActor
struct AvatarPicker: View {
    @EnvironmentObject private var store: DemoStore
    let avatarKey: String
    var size: CGFloat = 52
    var group = false
    @State private var selection: PhotosPickerItem?
    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            AvatarView(key: avatarKey, size: size, group: group)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group ? "更换群头像" : "更换头像")
        .task(id: selection) {
            guard let item = selection else { return }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    store.notice = "图片读取失败"
                    selection = nil
                    return
                }
                guard !Task.isCancelled else { return }
                store.saveAvatar(data: data, key: avatarKey)
            } catch {
                if !Task.isCancelled { store.notice = "图片读取失败，请重试。" }
            }
            selection = nil
        }
    }
}

@MainActor
struct PageHeader: View {
    let title: String
    var search: Binding<Bool>?
    var action: String?
    var actionSymbol = "plus"
    var background: Color = .demoHeader
    var body: some View {
        ZStack {
            Text(title).font(.system(size: 19, weight: .semibold)).lineLimit(1).padding(.horizontal, 85)
            HStack(spacing: 20) {
                Spacer()
                if let search {
                    Button { search.wrappedValue.toggle() } label: { Image(systemName: "magnifyingglass") }
                        .accessibilityLabel("搜索\(title)")
                }
                if let action {
                    NavigationLink(value: DemoRoute.detail(action)) { Image(systemName: actionSymbol) }
                        .accessibilityLabel(action)
                }
            }.font(.system(size: 21)).padding(.horizontal, 17)
        }
        .foregroundStyle(.primary)
        .frame(height: 52)
        .background(background)
    }
}

struct SearchField: View {
    @Binding var text: String
    let prompt: String
    var body: some View {
        TextField(prompt, text: $text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(10)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 15).padding(.vertical, 10)
    }
}

struct Watermarks: View {
    let text: String
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 100) {
                ForEach(0..<12, id: \.self) { _ in
                    HStack(spacing: 28) {
                        Text(text)
                        Text(text).offset(y: 50)
                    }
                }
            }
            .font(.system(size: 12)).foregroundStyle(Color.gray.opacity(0.12))
            .rotationEffect(.degrees(-22)).frame(width: geometry.size.width)
        }
        .clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct DetailView: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 15) {
                Text(title).font(.title2)
                Text("这是本地界面演示，此入口尚未接入实际服务。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 10))
            Spacer()
        }.padding(17).background(Color.demoBackground).navigationTitle(title)
    }
}
