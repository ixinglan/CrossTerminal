import SwiftUI

/// 首次运行时的设置窗口：选择默认终端并保存。
struct SettingsView: View {
    let detected: [TerminalApp]
    @State private var selectedId: String
    @State private var saved = false

    init(detected: [TerminalApp]) {
        self.detected = detected
        _selectedId = State(initialValue: detected.first?.id ?? "terminal")
    }

    var body: some View {
        VStack(spacing: 22) {
            header
            if saved { doneSection } else { configSection }
        }
        .padding(28)
        .frame(width: 460)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("CrossTerminal")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("在终端中打开访达当前目录")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择默认终端").font(.headline)
            Picker("终端", selection: $selectedId) {
                ForEach(detected) { t in
                    Text(t.name).tag(t.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Button(action: save) {
                Text("保存并继续").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Divider()

            Text("保存后，将 CrossTerminal.app 拖到访达工具栏（按住 ⌘ 拖拽）即可一键使用。\n之后可在 ~/Library/Application Support/CrossTerminal/config.json 中修改。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var doneSection: some View {
        // 优先用当前下拉里选中的名字（含自定义终端），避免兜底成「系统终端」
        let name = detected.first(where: { $0.id == selectedId })?.name
            ?? TerminalManager.terminalName(for: selectedId)
        return VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("已保存").font(.headline)
            Text("把 CrossTerminal.app 拖进访达工具栏（按住 ⌘），以后点一下就能在「\(name)」中打开当前目录。")
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
            Button("完成") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderedProminent)
        }
    }

    private func save() {
        CrossTerminalConfig.save(CrossTerminalConfig(terminalId: selectedId))
        saved = true
    }
}
