import Cocoa
import FlutterMacOS
import Foundation
import ServiceManagement

@objc protocol PrivilegedHelperProtocol {
    func runGoProxyCore(
        executablePath: String, executableDir: String, arguments: [String],
        completion: @escaping (Bool, String?) -> Void)
    func stopGoProxyCore(completion: @escaping (Bool, String?) -> Void)
    func copyOpenVPNConfigFiles(
        configContent: String, certFiles: [String: String],
        completion: @escaping (Bool, String?, String?) -> Void)
    func cleanupLogs(
        fileSizeLimit: Int, retentionDays: Int,
        completion: @escaping (Bool, String?) -> Void)
}

// 日志工具类
class Logger {
    static let shared = Logger()
    private var logFileURL: URL?

    private init() {
        // 设置日志文件路径
        let fileManager = FileManager.default
        let logDirectory = "/private/var/tmp"

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
            // 延迟检查和安装助手工具，确保窗口已经显示
            self.deferHelperInstallation()
        }
    }

    // 延迟特权助手工具的安装，确保主窗口已经显示
    private func deferHelperInstallation() {
        Logger.shared.writeLog("延迟安装助手工具，等待窗口显示")
        // 使用多个延迟检查确保窗口确实已经显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let window = NSApp.windows.first else {
                Logger.shared.writeLog("窗口尚未初始化，继续等待", level: "WARN")
                self.deferHelperInstallation()
                return
            }

            if !window.isVisible {
                Logger.shared.writeLog("窗口不可见，继续等待", level: "WARN")
                self.deferHelperInstallation()
                return
            }

            Logger.shared.writeLog("窗口已显示，开始安装助手工具")
            DispatchQueue.global(qos: .background).async {
                self.checkAndInstallHelperTool()
            }
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
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
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
            case "runGoProxyCore":
                Logger.shared.writeLog("运行Go代理核心")
                guard let args = call.arguments as? [String: Any],
                    let executablePath = args["executablePath"] as? String,
                    let executableDir = args["executableDir"] as? String,
                    let arguments = args["arguments"] as? [String]
                else {
                    Logger.shared.writeLog("参数缺失或无效", level: "ERROR")
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENTS", message: "Missing or invalid parameters",
                            details: nil))
                    return
                }
                self?.runGoProxyCore(
                    executablePath: executablePath, executableDir: executableDir,
                    arguments: arguments,
                    completion: { success, error in
                        if success {
                            Logger.shared.writeLog("Go代理核心运行成功")
                            result(true)
                        } else {
                            Logger.shared.writeLog("Go代理核心运行失败: \(error ?? "未知错误")", level: "ERROR")
                            result(
                                FlutterError(
                                    code: "HELPER_ERROR", message: error ?? "Unknown error",
                                    details: nil))
                        }
                    })
            case "stopGoProxyCore":
                Logger.shared.writeLog("停止Go代理核心")
                self?.stopGoProxyCore { success, error in
                    if success {
                        Logger.shared.writeLog("Go代理核心停止成功")
                        result(true)
                    } else {
                        Logger.shared.writeLog("Go代理核心停止失败: \(error ?? "未知错误")", level: "ERROR")
                        result(
                            FlutterError(
                                code: "HELPER_ERROR", message: error ?? "Unknown error",
                                details: nil))
                    }
                }
            case "copyOpenVPNConfigFiles":
                if let args = call.arguments as? [String: Any],
                    let configContent = args["configContent"] as? String,
                    let certFiles = args["certFiles"] as? [String: String]
                {
                    self?.copyOpenVPNConfigFiles(
                        configContent: configContent, certFiles: certFiles, result: result)
                } else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            case "helperInstalled":
                Logger.shared.writeLog("收到特权助手安装完成通知")
                // 发送通知给Flutter应用
                NotificationCenter.default.post(
                    name: Notification.Name("HelperInstalled"), object: nil)
                result(true)
            case "cleanupLogs":
                Logger.shared.writeLog("收到日志清理请求")
                // 从Flutter传递的参数中获取文件大小限制和保留天数
                var fileSizeLimit = 10  // 默认10MB
                var retentionDays = 7  // 默认7天

                if let args = call.arguments as? [String: Any] {
                    fileSizeLimit = args["fileSizeLimit"] as? Int ?? fileSizeLimit
                    retentionDays = args["retentionDays"] as? Int ?? retentionDays
                }

                self?.cleanupLogs(
                    fileSizeLimit: fileSizeLimit, retentionDays: retentionDays, result: result)
            default:
                Logger.shared.writeLog("未实现的方法: \(call.method)", level: "WARN")
                result(FlutterMethodNotImplemented)
            }
        })
    }

    private func checkAndInstallHelperTool() {
        Logger.shared.writeLog("检查并安装助手工具")
        let helperBundleIdentifier = "com.v8en.dualvpnManager.PrivilegedHelper"
        if !isHelperToolInstalled(helperBundleIdentifier) {
            Logger.shared.writeLog("助手工具未安装，开始安装")
            installHelperTool()
        } else {
            Logger.shared.writeLog("助手工具已安装")
        }
    }

    private func isHelperToolInstalled(_ toolBundleIdentifier: String) -> Bool {
        Logger.shared.writeLog("检查助手工具是否已安装: \(toolBundleIdentifier)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", toolBundleIdentifier]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let isInstalled =
                output.contains(toolBundleIdentifier) && process.terminationStatus == 0
            Logger.shared.writeLog("助手工具安装状态: \(isInstalled)")
            return isInstalled
        } catch {
            Logger.shared.writeLog("检查助手工具失败: \(error.localizedDescription)", level: "ERROR")
            return false
        }
    }

    private func installHelperTool() {
        Logger.shared.writeLog("开始安装助手工具")
        let helperBundleIdentifier = "com.v8en.dualvpnManager.PrivilegedHelper"
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)

        if status != errAuthorizationSuccess {
            Logger.shared.writeLog("创建授权引用失败: \(status)", level: "ERROR")
            return
        }

        defer {
            if let authRef = authRef {
                AuthorizationFree(authRef, [.destroyRights])
            }
        }

        // var removError: Unmanaged<CFError>?
        // SMJobRemove(kSMDomainSystemLaunchd, helperBundleIdentifier as CFString, authRef, true, &removError)

        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd, helperBundleIdentifier as CFString, authRef, &error)

        if !success {
            if let error = error?.takeRetainedValue() {
                let errorDesc = CFErrorCopyDescription(error) as String? ?? "未知错误"
                let errorCode = CFErrorGetCode(error)
                let errorDomain = CFErrorGetDomain(error) as String? ?? "未知域"
                Logger.shared.writeLog(
                    "安装助手工具失败: \(errorDesc) (域: \(errorDomain), 代码: \(errorCode))", level: "ERROR")
            } else {
                Logger.shared.writeLog("安装助手工具失败", level: "ERROR")
            }
        } else {
            Logger.shared.writeLog("助手工具安装成功")
            // 通知Flutter应用特权助手安装完成
            self.notifyHelperInstalled()
        }
    }

    // 通知Flutter应用特权助手安装完成
    private func notifyHelperInstalled() {
        Logger.shared.writeLog("通知Flutter应用特权助手安装完成")
        DispatchQueue.main.async {
            guard
                let controller = NSApp.windows.first?.contentViewController
                    as? FlutterViewController
            else {
                Logger.shared.writeLog("无法获取FlutterViewController", level: "ERROR")
                return
            }

            let channel = FlutterMethodChannel(
                name: "dualvpn_manager/macos",
                binaryMessenger: controller.engine.binaryMessenger)

            channel.invokeMethod("helperInstalled", arguments: nil) { result in
                Logger.shared.writeLog("通知Flutter应用特权助手安装完成结果: \(result ?? "nil")")
            }
        }
    }

    private func runGoProxyCore(
        executablePath: String, executableDir: String, arguments: [String],
        completion: @escaping (Bool, String?) -> Void
    ) {
        Logger.shared.writeLog("运行Go代理核心: \(executablePath)")
        if xpcConnection == nil {
            Logger.shared.writeLog("创建XPC连接")
            xpcConnection = NSXPCConnection(
                machServiceName: "com.v8en.dualvpnManager.PrivilegedHelper")
            xpcConnection?.remoteObjectInterface = NSXPCInterface(
                with: PrivilegedHelperProtocol.self)
            xpcConnection?.resume()

            // 主程序中添加连接中断监听
            xpcConnection?.interruptionHandler = {
                Logger.shared.writeLog("XPC连接中断", level: "ERROR")
                self.xpcConnection = nil
            }

            xpcConnection?.invalidationHandler = {
                Logger.shared.writeLog("XPC连接失效", level: "ERROR")
                self.xpcConnection = nil
            }
        }

        guard
            let proxy = xpcConnection?.remoteObjectProxyWithErrorHandler({ error in
                Logger.shared.writeLog("创建XPC代理失败: \(error.localizedDescription)", level: "ERROR")
                completion(false, error.localizedDescription)
            }) as? PrivilegedHelperProtocol
        else {
            Logger.shared.writeLog("无法创建XPC代理", level: "ERROR")
            completion(false, "Failed to create XPC proxy")
            return
        }

        Logger.shared.writeLog("调用特权助手运行Go代理核心")
        proxy.runGoProxyCore(
            executablePath: executablePath, executableDir: executableDir, arguments: arguments,
            completion: completion)
    }

    private func stopGoProxyCore(completion: @escaping (Bool, String?) -> Void) {
        Logger.shared.writeLog("停止Go代理核心")
        if xpcConnection == nil {
            Logger.shared.writeLog("创建XPC连接")
            xpcConnection = NSXPCConnection(
                machServiceName: "com.v8en.dualvpnManager.PrivilegedHelper")
            xpcConnection?.remoteObjectInterface = NSXPCInterface(
                with: PrivilegedHelperProtocol.self)
            xpcConnection?.resume()

            // 主程序中添加连接中断监听
            xpcConnection?.interruptionHandler = {
                Logger.shared.writeLog("XPC连接中断", level: "ERROR")
                self.xpcConnection = nil
            }

            xpcConnection?.invalidationHandler = {
                Logger.shared.writeLog("XPC连接失效", level: "ERROR")
                self.xpcConnection = nil
            }
        }

        guard
            let proxy = xpcConnection?.remoteObjectProxyWithErrorHandler({ error in
                Logger.shared.writeLog("创建XPC代理失败: \(error.localizedDescription)", level: "ERROR")
                completion(false, error.localizedDescription)
            }) as? PrivilegedHelperProtocol
        else {
            Logger.shared.writeLog("无法创建XPC代理", level: "ERROR")
            completion(false, "Failed to create XPC proxy")
            return
        }

        Logger.shared.writeLog("调用特权助手停止Go代理核心")
        proxy.stopGoProxyCore(completion: completion)
    }

    private func copyOpenVPNConfigFiles(
        configContent: String, certFiles: [String: String], result: @escaping FlutterResult
    ) {
        if xpcConnection == nil {
            Logger.shared.writeLog("创建XPC连接")
            xpcConnection = NSXPCConnection(
                machServiceName: "com.v8en.dualvpnManager.PrivilegedHelper")
            xpcConnection?.remoteObjectInterface = NSXPCInterface(
                with: PrivilegedHelperProtocol.self)
            xpcConnection?.resume()

            // 主程序中添加连接中断监听
            xpcConnection?.interruptionHandler = {
                Logger.shared.writeLog("XPC连接中断", level: "ERROR")
                self.xpcConnection = nil
            }

            xpcConnection?.invalidationHandler = {
                Logger.shared.writeLog("XPC连接失效", level: "ERROR")
                self.xpcConnection = nil
            }
        }

        guard
            let proxy = xpcConnection?.remoteObjectProxyWithErrorHandler({ error in
                Logger.shared.writeLog("创建XPC代理失败: \(error.localizedDescription)", level: "ERROR")
                result(
                    FlutterError(
                        code: "HELPER_ERROR", message: error.localizedDescription,
                        details: nil))
                return
            }) as? PrivilegedHelperProtocol
        else {
            Logger.shared.writeLog("无法创建XPC代理", level: "ERROR")
            result(
                FlutterError(
                    code: "HELPER_ERROR", message: "Failed to create XPC proxy",
                    details: nil))
            return
        }

        proxy.copyOpenVPNConfigFiles(configContent: configContent, certFiles: certFiles) {
            success, error, configPath in
            let response: [String: Any?] = [
                "success": success,
                "errorMessage": error,
                "configPath": configPath,
            ]
            result(response)
        }
    }

    // 清理日志文件
    private func cleanupLogs(
        fileSizeLimit: Int, retentionDays: Int, result: @escaping FlutterResult
    ) {
        Logger.shared.writeLog(
            "收到日志清理请求，通过特权助手执行清理，文件大小限制: \(fileSizeLimit)MB，保留天数: \(retentionDays)天")

        if xpcConnection == nil {
            Logger.shared.writeLog("创建XPC连接")
            xpcConnection = NSXPCConnection(
                machServiceName: "com.v8en.dualvpnManager.PrivilegedHelper")
            xpcConnection?.remoteObjectInterface = NSXPCInterface(
                with: PrivilegedHelperProtocol.self)
            xpcConnection?.resume()

            // 主程序中添加连接中断监听
            xpcConnection?.interruptionHandler = {
                Logger.shared.writeLog("XPC连接中断", level: "ERROR")
                self.xpcConnection = nil
            }

            xpcConnection?.invalidationHandler = {
                Logger.shared.writeLog("XPC连接失效", level: "ERROR")
                self.xpcConnection = nil
            }
        }

        guard
            let proxy = xpcConnection?.remoteObjectProxyWithErrorHandler({ error in
                Logger.shared.writeLog("创建XPC代理失败: \(error.localizedDescription)", level: "ERROR")
                result(
                    FlutterError(
                        code: "HELPER_ERROR", message: error.localizedDescription,
                        details: nil))
                return
            }) as? PrivilegedHelperProtocol
        else {
            Logger.shared.writeLog("无法创建XPC代理", level: "ERROR")
            result(
                FlutterError(
                    code: "HELPER_ERROR", message: "Failed to create XPC proxy",
                    details: nil))
            return
        }

        Logger.shared.writeLog("调用特权助手清理日志文件，文件大小限制: \(fileSizeLimit)MB，保留天数: \(retentionDays)天")
        proxy.cleanupLogs(fileSizeLimit: fileSizeLimit, retentionDays: retentionDays) {
            success, error in
            if success {
                Logger.shared.writeLog("特权助手日志清理成功")
                result(true)
            } else {
                Logger.shared.writeLog("特权助手日志清理失败: \(error ?? "未知错误")", level: "ERROR")
                result(
                    FlutterError(
                        code: "CLEANUP_ERROR", message: error ?? "Unknown error",
                        details: nil))
            }
        }
    }
}
