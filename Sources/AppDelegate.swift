import AppKit
import SwiftUI

/// 应用代理：根据是否已有配置文件决定「设置」还是「执行打开动作」。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let config = CrossTerminalConfig.load() {
            performOpen(config: config)
        } else {
            showSetup()
        }
    }

    /// 设置窗口被关闭后（用户点「完成」或红点），应用退出。
    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        true
    }

    // MARK: - 执行打开终端
    private func performOpen(config: CrossTerminalConfig) {
        // 读取访达路径 + 启动终端这两步都可能阻塞（例如首次弹出的 TCC 自动化授权框），
        // 放到后台线程执行，避免阻塞主线程 / Run Loop；
        // 全部完成后回到主线程再 terminate（terminate 必须在主线程调用）。
        DispatchQueue.global().async {
            let path = FinderBridge.currentPath()
            let terminal = TerminalManager.terminal(for: config.terminalId) ?? TerminalManager.fallback
            terminal.open(path: path)
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - 首次设置窗口
    private func showSetup() {
        let detected = TerminalManager.detected
        let view = SettingsView(detected: detected)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "CrossTerminal"
        window.center()
        window.contentViewController = NSHostingController(rootView: view)
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
        settingsWindow = window
        // 辅助应用默认不在最前，主动置顶确保设置窗口可见
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
