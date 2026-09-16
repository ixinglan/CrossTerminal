import Foundation

/// 读取访达当前所在目录的路径。
enum FinderBridge {
    /// 返回访达「最前方窗口」所在目录；无窗口时返回首个选中项的父目录；再否则返回桌面。
    static func currentPath() -> String {
        let script = #"""
tell application "Finder"
  if (count of windows) > 0 then
    return POSIX path of (target of front window as alias)
  else
    try
      set sel to selection
      if (count of sel) > 0 then
        return POSIX path of (container of (item 1 of sel) as alias)
      end if
    end try
    return POSIX path of (path to desktop)
  end if
end tell
"""#

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? NSHomeDirectory() : out
    }
}
