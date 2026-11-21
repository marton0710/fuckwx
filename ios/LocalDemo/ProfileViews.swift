import SwiftUI

@MainActor
struct ProfileView: View {
    @EnvironmentObject private var store: DemoStore
    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                VStack(spacing: 0) {
                    HStack {
                        Text("头像")
                        Spacer()
                        AvatarPicker(avatarKey: "avatar", size: 64)
                        chevron
                    }.padding(.horizontal, 17).frame(height: 93)
                    Divider().padding(.leading, 17)
                    profileRows(["name", "alias", "gender"])
                }.background(.white)
                profileRows(["external"]).background(.white)
                profileRows(["signature", "company", "invoice"]).background(.white)
                profileRows(["email", "address"]).background(.white)
                NavigationLink(value: DemoRoute.department) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.value("departmentCode")).font(.system(size: 18))
                            Text(store.value("departmentPath")).font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        chevron
                    }.padding(.horizontal, 17).frame(minHeight: 76).contentShape(Rectangle())
                }.buttonStyle(.plain).background(.white).accessibilityIdentifier("profile.department")
            }.padding(.bottom, 16)
        }.background(Color.demoBackground).navigationTitle("个人信息")
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.tertiary)
    }

    private func profileRows(_ keys: [String]) -> some View {
        VStack(spacing: 0) {
            ForEach(keys, id: \.self) { key in
                NavigationLink(value: DemoRoute.editor(key)) {
                    HStack(spacing: 10) {
                        Text(DemoStore.labels[key] ?? key).font(.system(size: 17)).fixedSize()
                        Spacer(minLength: 0)
                        if key == "company" {
                            Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                        }
                        if key == "external" {
                            HStack(spacing: 0) {
                                Text(store.value(key).isEmpty ? store.value("name") : store.value(key)).foregroundStyle(.secondary)
                                if !store.value("company").isEmpty { Text("@" + store.value("company")).foregroundStyle(.orange) }
                            }.font(.system(size: 14)).lineLimit(1)
                        } else {
                            Text(displayValue(key)).font(.system(size: 15)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        chevron
                    }.padding(.horizontal, 17).frame(minHeight: 54).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("profile.\(key)")
                if key != keys.last { Divider().padding(.leading, 17) }
            }
        }
    }

    private func displayValue(_ key: String) -> String {
        if !store.value(key).isEmpty { return store.value(key) }
        return key == "signature" ? "添加工作签名..." : key == "invoice" ? "" : "无"
    }
}

@MainActor
struct ProfileEditorView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    let key: String
    @State private var draft = ""
    @State private var loaded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                if key == "gender" {
                    Picker("性别", selection: $draft) {
                        ForEach(["男", "女", "未设置"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented).padding(17)
                } else {
                    TextField(key == "external" ? "留空时使用姓名" : (DemoStore.labels[key] ?? ""), text: $draft)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(key == "email" ? .emailAddress : .default)
                        .padding(17).accessibilityIdentifier("editor.value")
                        .onChange(of: draft) { _, value in
                            if value.count > 200 { draft = String(value.prefix(200)) }
                        }
                }
            }.background(.white)
            Text("此处仅修改本地演示页面，不会更改企业微信资料。")
                .font(.system(size: 13)).foregroundStyle(.secondary).padding(.horizontal, 17)
            Spacer()
        }.padding(.top, 12).background(Color.demoBackground)
            .navigationTitle(DemoStore.labels[key] ?? "编辑资料")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        if store.save([key: draft.trimmed]) { dismiss() }
                    }.accessibilityIdentifier("editor.save")
                }
            }
            .onAppear {
                if !loaded { draft = store.value(key); loaded = true }
            }
    }
}

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [String: String] = [:]
    @State private var loaded = false
    private let fields = [("groupNames", "群名称（每行一个）"), ("memberNames", "成员显示名（每行一个）"),
                          ("departmentCode", "部门编号"), ("departmentName", "部门"), ("departmentGroup", "小组"), ("departmentYear", "年份")]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(fields.indices, id: \.self) { index in
                    let field = fields[index]
                    Text(field.1).font(.system(size: 15)).foregroundStyle(.secondary).padding(.horizontal, 17).padding(.top, 14)
                    if index < 2 {
                        TextEditor(text: binding(field.0))
                            .frame(height: index == 0 ? 95 : 260).padding(.horizontal, 12).padding(.top, 8)
                            .accessibilityLabel(field.1).accessibilityIdentifier("settings.\(field.0)")
                    } else {
                        TextField(field.1, text: binding(field.0)).padding(17)
                            .accessibilityIdentifier("settings.\(field.0)")
                    }
                    Divider()
                }
                Text("此处仅修改本地演示页面，不会更改企业微信资料。")
                    .font(.system(size: 13)).foregroundStyle(.secondary).padding(17)
            }
        }.background(.white).navigationTitle("设置")
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: save).accessibilityIdentifier("settings.save")
                }
            }
            .onAppear {
                if !loaded {
                    draft = Dictionary(uniqueKeysWithValues: fields.map { ($0.0, store.value($0.0)) })
                    loaded = true
                }
            }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { draft[key] ?? "" }, set: { draft[key] = $0 })
    }

    private func save() {
        var changes = draft.mapValues { $0.trimmed }
        for key in ["groupNames", "memberNames"] {
            changes[key] = (changes[key] ?? "").components(separatedBy: .newlines).map(\.trimmed).filter { !$0.isEmpty }.joined(separator: "\n")
        }
        changes["departmentPath"] = [store.value("company"), changes["departmentName"] ?? "", changes["departmentGroup"] ?? "", changes["departmentYear"] ?? ""]
            .filter { !$0.isEmpty }.joined(separator: "/")
        if store.save(changes) { dismiss() }
    }
}
