import Foundation

/// 一个可被 CrossTerminal 打开的终端。
struct TerminalApp: Identifiable {
    let id: String
    let name: String
    let appNames: [String]      // 可能的 .app 包名（用于检测是否已安装）
    let bundleIds: [String]
    let strategy: Strategy

    /// 打开策略：AppleScript 模板（{PATH} 占位，内部用 quoted form 处理空格），
    /// 或 shell 命令行模板（{PATH} 占位）。
    enum Strategy {
        case appleScript(String)
        case shell([String])
    }

    /// 是否在系统中已安装（扫描常见应用目录）。
    func isInstalled() -> Bool {
        let dirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/Applications/Utilities",
        ]
        for dir in dirs {
            for name in appNames where FileManager.default.fileExists(atPath: "\(dir)/\(name).app") {
                return true
            }
        }
        return false
    }

    /// 在指定目录中打开该终端。
    func open(path: String) {
        switch strategy {
        case .appleScript(let tmpl):
            // 转义双引号，避免路径中的引号破坏 AppleScript 字符串
            let safe = path.replacingOccurrences(of: "\"", with: "\\\"")
            TerminalManager.runOsascript(tmpl.replacingOccurrences(of: "{PATH}", with: safe))
        case .shell(let args):
            TerminalManager.runShell(args.map { $0.replacingOccurrences(of: "{PATH}", with: path) })
        }
    }
}

enum TerminalManager {
    /// 系统自带终端（兜底默认值）。
    static let terminal_def = TerminalApp(
        id: "terminal",
        name: "系统终端 (Terminal)",
        appNames: ["Terminal"],
        bundleIds: ["com.apple.Terminal"],
        strategy: .appleScript(#"""
tell application "Terminal"
  activate
  do script "cd " & quoted form of "{PATH}"
end tell
"""#)
    )

    /// 所有内置支持的终端。顺序即设置窗口下拉框顺序，系统终端排第一（默认）。
    static var allBuiltIn: [TerminalApp] {
        [
            terminal_def,
            TerminalApp(
                id: "iterm",
                name: "iTerm2",
                appNames: ["iTerm", "iTerm2"],
                bundleIds: ["com.googlecode.iterm2"],
                strategy: .appleScript(#"""
tell application "iTerm"
  activate
  if (exists current window) then
    tell current window to create tab with default profile command "cd " & quoted form of "{PATH}"
  else
    create window with default profile command "cd " & quoted form of "{PATH}"
  end if
end tell
"""#)
            ),
            TerminalApp(
                id: "warp",
                name: "Warp",
                appNames: ["Warp"],
                bundleIds: ["dev.warp.Warp"],
                strategy: .shell(["/usr/bin/open", "-a", "Warp"])
            ),
            TerminalApp(
                id: "kitty",
                name: "Kitty",
                appNames: ["Kitty"],
                bundleIds: ["net.kovidgoyal.kitty"],
                strategy: .shell(["/usr/bin/open", "-a", "Kitty", "--args", "--directory", "{PATH}"])
            ),
            TerminalApp(
                id: "alacritty",
                name: "Alacritty",
                appNames: ["Alacritty"],
                bundleIds: ["org.alacritty"],
                strategy: .shell(["/usr/bin/open", "-a", "Alacritty", "--args", "--working-directory", "{PATH}"])
            ),
            TerminalApp(
                id: "ghostty",
                name: "Ghostty",
                appNames: ["Ghostty"],
                bundleIds: ["com.mitchellh.ghostty"],
                strategy: .shell(["/usr/bin/open", "-a", "Ghostty", "--args", "--working-directory", "{PATH}"])
            ),
            TerminalApp(
                id: "hyper",
                name: "Hyper",
                appNames: ["Hyper"],
                bundleIds: ["co.zeit.hyper"],
                strategy: .shell(["/usr/bin/open", "-a", "Hyper", "--args", "{PATH}"])
            ),
            TerminalApp(
                id: "tabby",
                name: "Tabby",
                appNames: ["Tabby"],
                bundleIds: ["org.tabby"],
                strategy: .shell(["/usr/bin/open", "-a", "Tabby", "--args", "{PATH}"])
            ),
            TerminalApp(
                id: "wezterm",
                name: "WezTerm",
                appNames: ["WezTerm"],
                bundleIds: ["com.github.wez.wezterm"],
                strategy: .shell(["/usr/bin/open", "-a", "WezTerm", "--args", "start", "--cwd", "{PATH}"])
            ),
        ]
    }

    static let fallback = terminal_def

    /// 根据 id 解析终端（先查内置，再查配置中的自定义终端）。
    static func terminal(for id: String) -> TerminalApp? {
        allBuiltIn.first(where: { $0.id == id })
            ?? loadCustom().first(where: { $0.id == id })
    }

    /// 已安装的终端列表（用于设置窗口下拉框）；若都未安装则回退到系统终端。
    static var detected: [TerminalApp] {
        let builtin = allBuiltIn.filter { $0.isInstalled() }
        return builtin.isEmpty ? [terminal_def] : builtin
    }

    static func terminalName(for id: String) -> String {
        terminal(for: id)?.name ?? "终端"
    }

    // MARK: - 自定义终端（来自 config.json）
    static func loadCustom() -> [TerminalApp] {
        guard let cfg = CrossTerminalConfig.load(),
              let customs = cfg.customTerminals else { return [] }
        return customs.map { c in
            TerminalApp(
                id: c.id,
                name: c.name,
                appNames: [c.appName],
                bundleIds: [],
                strategy: .shell(["/usr/bin/open", "-a", c.appName, "--args", c.openCommand])
            )
        }
    }

    // MARK: - 执行辅助
    static func runOsascript(_ script: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        // 关键：run() 失败（如二进制缺失/权限问题）时必须先确认进程已启动，
        // 否则在「未启动」的进程上调用 waitUntilExit() 可能抛异常或卡死。
        guard (try? proc.run()) != nil else { return }
        proc.waitUntilExit()
    }

    static func runShell(_ command: [String]) {
        guard let exe = command.first, !exe.isEmpty else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments = Array(command.dropFirst())
        guard (try? proc.run()) != nil else { return }
        proc.waitUntilExit()
    }
}
