import Cocoa
import FlutterMacOS
import Foundation

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
}