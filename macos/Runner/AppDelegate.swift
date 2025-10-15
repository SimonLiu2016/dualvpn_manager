import Cocoa
import FlutterMacOS
import Foundation
import ServiceManagement

@objc protocol PrivilegedHelperProtocol {
    func runGoProxyCore(executablePath: String, executableDir: String, arguments: [String], completion: @escaping (Bool, String?) -> Void, logHandler: @escaping (String) -> Void)
}

@main
class AppDelegate: FlutterAppDelegate {
    private var channel: FlutterMethodChannel?
    private var xpcConnection: NSXPCConnection?
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupMethodChannel()
        }
        self.checkAndInstallHelperTool()
    }
    
    private func setupMethodChannel() {
        guard let controller = NSApp.windows.first?.contentViewController as? FlutterViewController else {
            return
        }
        
        channel = FlutterMethodChannel(name: "dualvpn_manager/macos",
                                      binaryMessenger: controller.engine.binaryMessenger)
        channel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "hideDockIcon":
                NSApp.setActivationPolicy(.accessory)
                result(true)
            case "showDockIcon":
                NSApp.setActivationPolicy(.regular)
                result(true)
            case "runGoProxyCore":
                guard let args = call.arguments as? [String: Any],
                      let executablePath = args["executablePath"] as? String,
                      let executableDir = args["executableDir"] as? String,
                      let arguments = args["arguments"] as? [String] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid parameters", details: nil))
                    return
                }
                self?.runGoProxyCore(executablePath: executablePath, executableDir: executableDir, arguments: arguments, completion: { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "HELPER_ERROR", message: error ?? "Unknown error", details: nil))
                    }
                }, logHandler: { log in
                    self?.channel?.invokeMethod("onGoProxyCoreLog", arguments: log)
                })
            default:
                result(FlutterMethodNotImplemented)
            }
        })
    }
    
    private func checkAndInstallHelperTool() {
        let helperBundleIdentifier = "com.v8en.dualvpnManager.PrivilegedHelper"
        if !isHelperToolInstalled(helperBundleIdentifier) {
            installHelperTool()
        }
    }
    
    private func isHelperToolInstalled(_ toolBundleIdentifier: String) -> Bool {
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
            return output.contains(toolBundleIdentifier) && process.terminationStatus == 0
        } catch {
            print("检查助手工具失败: \(error.localizedDescription)")
            return false
        }
    }
    
    private func installHelperTool() {
        let helperBundleIdentifier = "com.v8en.dualvpnManager.PrivilegedHelper"
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        
        if status != errAuthorizationSuccess {
            print("创建授权引用失败: \(status)")
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
        let success = SMJobBless(kSMDomainSystemLaunchd, helperBundleIdentifier as CFString, authRef, &error)
        
        if !success {
            if let error = error?.takeRetainedValue() {
                let errorDesc = CFErrorCopyDescription(error) as String? ?? "未知错误"
                let errorCode = CFErrorGetCode(error)
                let errorDomain = CFErrorGetDomain(error) as String? ?? "未知域"
                print("安装助手工具失败: \(errorDesc) (域: \(errorDomain), 代码: \(errorCode))")
            } else {
                print("安装助手工具失败")
            }
        } else {
            print("助手工具安装成功")
        }
    }
    
    private func runGoProxyCore(executablePath: String, executableDir: String, arguments: [String], completion: @escaping (Bool, String?) -> Void, logHandler: @escaping (String) -> Void) {
        if xpcConnection == nil {
            xpcConnection = NSXPCConnection(machServiceName: "com.v8en.dualvpnManager.PrivilegedHelper")
            xpcConnection?.remoteObjectInterface = NSXPCInterface(with: PrivilegedHelperProtocol.self)
            xpcConnection?.resume()
        }
        
        guard let proxy = xpcConnection?.remoteObjectProxyWithErrorHandler({ error in
            completion(false, error.localizedDescription)
        }) as? PrivilegedHelperProtocol else {
            completion(false, "Failed to create XPC proxy")
            return
        }
        
        proxy.runGoProxyCore(executablePath: executablePath, executableDir: executableDir, arguments: arguments, completion: completion, logHandler: logHandler)
    }
}
