import Cocoa
import FlutterMacOS
import Foundation
import ServiceManagement

@main
class AppDelegate: FlutterAppDelegate {
  private var channel: FlutterMethodChannel?
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 延迟初始化以确保窗口和FlutterViewController已经创建
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.setupMethodChannel()
    }
    
    // 检查并安装特权助手工具
    self.checkAndInstallHelperTool()
  }
  
  private func setupMethodChannel() {
    guard let controller = NSApp.windows.first?.contentViewController as? FlutterViewController else {
      return
    }
    
    channel = FlutterMethodChannel(name: "dualvpn_manager/macos",
                                   binaryMessenger: controller.engine.binaryMessenger)
    channel?.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "hideDockIcon":
        NSApp.setActivationPolicy(.accessory)
        result(true)
      case "showDockIcon":
        NSApp.setActivationPolicy(.regular)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
  }
  
  private func checkAndInstallHelperTool() {
    let helperBundleIdentifier = "com.dualvpn.manager.helper"
    
    // 检查助手工具是否已经安装
    if !isHelperToolInstalled(helperBundleIdentifier) {
      // 安装助手工具
      installHelperTool()
    }
  }
  
  private func isHelperToolInstalled(_ toolBundleIdentifier: String) -> Bool {
    // 简单检查launchd中是否存在该任务
    let taskList = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["list"])
    let pipe = Pipe()
    taskList.standardOutput = pipe
    taskList.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    return output.contains(toolBundleIdentifier)
  }
  
  private func installHelperTool() {
    let helperBundleIdentifier = "com.dualvpn.manager.helper"
    
    // 检查助手工具资源是否存在
    guard Bundle.main.path(forResource: "PrivilegedHelper", ofType: "app") != nil else {
      print("找不到助手工具资源")
      return
    }
    
    // 创建授权引用
    var authRef: AuthorizationRef?
    let status = AuthorizationCreate(nil, nil, [], &authRef)
    
    if status != errAuthorizationSuccess {
      print("创建授权引用失败")
      return
    }
    
    defer {
      if let authRef = authRef {
        AuthorizationFree(authRef, [])
      }
    }
    
    // 安装助手工具
    var error: Unmanaged<CFError>? = nil
    let success = SMJobBless(kSMDomainSystemLaunchd, helperBundleIdentifier as CFString, authRef, &error)
    
    if !success {
      if let error = error?.takeRetainedValue() {
        let errorDesc = CFErrorCopyDescription(error)
        print("安装助手工具失败: \(errorDesc ?? "未知错误" as CFString)")
      } else {
        print("安装助手工具失败")
      }
    } else {
      print("助手工具安装成功")
    }
  }
}