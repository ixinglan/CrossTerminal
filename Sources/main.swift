// CrossTerminal 入口：以「无 Dock / 无菜单栏」的辅助应用(agent)方式运行。
// 首次运行（无配置文件）弹出设置窗口让用户选择默认终端；
// 之后从访达工具栏点击时，读取访达当前目录并在所选终端中打开，随后自动退出。
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // 等效于 Info.plist 的 LSUIElement：不显示 Dock / 菜单栏图标
let delegate = AppDelegate()
app.delegate = delegate
app.run()
