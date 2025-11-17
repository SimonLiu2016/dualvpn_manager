import Cocoa
import FlutterMacOS
import Foundation
import ServiceManagement

// 日志工具类
class Logger {
    static let shared = Logger()
    private var logFileURL: URL?

    private init() {
        // 设置日志文件路径为应用临时目录
        let fileManager = FileManager.default
        let logDirectory = NSTemporaryDirectory() + "dualvpn_logs"

        // 确保日志目录存在
        do {
            try fileManager.createDirectory(
                atPath: logDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("无法创建日志目录: \(error)")
        }

        // 创建日志文件名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "dualvpn_macos_\(dateString).log"

        logFileURL = URL(fileURLWithPath: logDirectory).appendingPathComponent(fileName)

        // 初始化日志文件
        writeLog("macOS AppDelegate 日志系统初始化")
    }

    func writeLog(_ message: String, level: String = "INFO") {
        guard let logURL = logFileURL else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())

        let logMessage = "[\(timestamp)] [\(level)] \(message)\n"

        // 写入日志文件
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: logURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } catch {
                    NSLog("写入日志文件失败: \(error)")
                }
            } else {
                do {
                    try data.write(to: logURL)
                } catch {
                    NSLog("创建日志文件失败: \(error)")
                }
            }
        }
    }

    // 获取日志文件路径
    func getLogFilePath() -> String? {
        return logFileURL?.path
    }
}

@main
class AppDelegate: FlutterAppDelegate {
    private var channel: FlutterMethodChannel?
    private var xpcConnection: NSXPCConnection?

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        Logger.shared.writeLog("应用即将关闭")
        return false
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.writeLog("应用启动完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupMethodChannel()
        }
    }

    private func setupMethodChannel() {
        Logger.shared.writeLog("设置Flutter方法通道")
        guard let controller = NSApp.windows.first?.contentViewController as? FlutterViewController
        else {
            Logger.shared.writeLog("无法获取FlutterViewController", level: "ERROR")
            return
        }

        channel = FlutterMethodChannel(
            name: "dualvpn_manager/macos",
            binaryMessenger: controller.engine.binaryMessenger)
        channel?.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            Logger.shared.writeLog("收到Flutter方法调用: \(call.method)")
            switch call.method {
            case "hideDockIcon":
                Logger.shared.writeLog("隐藏Dock图标")
                NSApp.setActivationPolicy(.accessory)
                result(true)
            case "showDockIcon":
                Logger.shared.writeLog("显示Dock图标")
                NSApp.setActivationPolicy(.regular)
                result(true)
            default:
                Logger.shared.writeLog("未实现的方法: \(call.method)", level: "WARN")
                result(FlutterMethodNotImplemented)
            }
        })
    }
}
