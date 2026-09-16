import Foundation

/// 应用配置：首次设置后写入 ~/Library/Application Support/CrossTerminal/config.json。
/// 之后用户可直接编辑该文件来修改默认终端，或追加自定义终端。
struct CrossTerminalConfig: Codable {
    /// 选中的终端 id（对应 TerminalManager 中的内置 id，或 customTerminals 里的 id）
    var terminalId: String

    /// 高级用法：在配置文件中追加自定义终端（见 README）。
    /// openCommand 为 shell 模板，使用 {PATH} 占位当前目录。
    var customTerminals: [CustomTerminal]?

    /// 配置文件的固定路径。
    static let defaultURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("CrossTerminal", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    static func load() -> CrossTerminalConfig? {
        guard let data = try? Data(contentsOf: defaultURL) else { return nil }
        return try? JSONDecoder().decode(CrossTerminalConfig.self, from: data)
    }

    static func save(_ config: CrossTerminalConfig) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: defaultURL, options: .atomic)
    }
}

/// 自定义终端定义（通过 config.json 提供，无需改代码）。
struct CustomTerminal: Codable, Identifiable {
    var id: String
    var name: String
    var appName: String   // .app 包名，如 "Warp"
    var openCommand: String // shell 模板，{PATH} 占位，如 "new_tab --path {PATH}"
}
