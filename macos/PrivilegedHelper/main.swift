import Foundation
import ServiceManagement

// 全局变量用于信号处理
private var globalHelper: PrivilegedHelper?

@objc protocol PrivilegedHelperProtocol {
    func runGoProxyCore(
        executablePath: String, executableDir: String, arguments: [String],
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
        let fileName = "dualvpn_macos_helper_\(dateString).log"

        logFileURL = URL(fileURLWithPath: logDirectory).appendingPathComponent(fileName)

        // 初始化日志文件
        writeLog("dualVPN Helper 日志系统初始化")
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

class PrivilegedHelper: NSObject, PrivilegedHelperProtocol, NSXPCListenerDelegate {
    private var isShuttingDown = false

    override init() {
        super.init()
        Logger.shared.writeLog("PrivilegedHelper object initialized")
    }

    deinit {
        if !isShuttingDown {
            Logger.shared.writeLog("PrivilegedHelper object deinitialized (unexpected shutdown)")
        }
    }

    func listener(
        _ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        Logger.shared.writeLog("Accepting new XPC connection from \(newConnection)")
        newConnection.exportedInterface = NSXPCInterface(with: PrivilegedHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func runGoProxyCore(
        executablePath: String, executableDir: String, arguments: [String],
        completion: @escaping (Bool, String?) -> Void
    ) {
        Logger.shared.writeLog(
            "runGoProxyCore called with executablePath: \(executablePath), executableDir: \(executableDir), arguments: \(arguments)"
        )

        // 验证路径安全性
        let allowedPathPrefix = "/Applications/dualvpn_manager.app/Contents/Resources/bin"
        guard executablePath.hasPrefix(allowedPathPrefix) else {
            let errorMsg =
                "Invalid executable path prefix: \(executablePath) (expected prefix: \(allowedPathPrefix))"
            Logger.shared.writeLog(errorMsg)
            completion(false, errorMsg)
            return
        }

        guard FileManager.default.fileExists(atPath: executablePath) else {
            let errorMsg = "Executable path does not exist: \(executablePath)"
            Logger.shared.writeLog(errorMsg)
            completion(false, errorMsg)
            return
        }

        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            let errorMsg = "Executable path is not executable: \(executablePath)"
            Logger.shared.writeLog(errorMsg)
            completion(false, errorMsg)
            return
        }

        guard FileManager.default.fileExists(atPath: executableDir) else {
            let errorMsg = "Executable directory does not exist: \(executableDir)"
            Logger.shared.writeLog(errorMsg)
            completion(false, errorMsg)
            return
        }

        Logger.shared.writeLog(
            "Starting go-proxy-core with executable: \(executablePath), directory: \(executableDir), arguments: \(arguments)"
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.currentDirectoryURL = URL(fileURLWithPath: executableDir)
        process.arguments = arguments

        // 设置输出和错误管道
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 实时捕获输出
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                let message = "stdout: \(output)"
                Logger.shared.writeLog(message)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                let message = "stderr: \(output)"
                Logger.shared.writeLog(message)
            }
        }

        process.terminationHandler = { proc in
            let message = "go-proxy-core terminated with status: \(proc.terminationStatus)"
            Logger.shared.writeLog(message)
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            completion(
                proc.terminationStatus == 0,
                proc.terminationStatus != 0
                    ? "Terminated with status: \(proc.terminationStatus)" : nil)
        }

        do {
            try process.run()
            Logger.shared.writeLog("Successfully started go-proxy-core")
        } catch {
            let errorMsg = "Failed to start go-proxy-core: \(error.localizedDescription)"
            Logger.shared.writeLog(errorMsg)
            completion(false, errorMsg)
        }
    }

    // 优雅关闭
    func shutdown() {
        if !isShuttingDown {
            isShuttingDown = true
            Logger.shared.writeLog("PrivilegedHelper shutting down...")
            // 这里可以添加其他清理代码
        }
    }
}

// 信号处理函数
func signalHandler(signal: Int32) {
    if let helper = globalHelper {
        helper.shutdown()
    }
    exit(0)
}

func main() {
    let listener = NSXPCListener(machServiceName: "com.v8en.dualvpnManager.PrivilegedHelper")
    let helper = PrivilegedHelper()

    // 设置全局引用以便信号处理函数访问
    globalHelper = helper

    // 注册信号处理器以捕获终止信号
    signal(SIGTERM, signalHandler)
    signal(SIGINT, signalHandler)

    // 使用现有的日志系统替代 syslog
    let uid = getuid()
    let euid = geteuid()
    let pid = getpid()
    let logMessage = "Helper tool started - uid: \(uid), euid: \(euid), pid: \(pid)"
    Logger.shared.writeLog(logMessage)

    Logger.shared.writeLog("Starting PrivilegedHelper XPC listener")
    listener.delegate = helper
    listener.resume()

    // 添加运行循环观察器以检测退出
    Logger.shared.writeLog("Entering run loop")
    RunLoop.current.run()

    // 正常退出时记录日志
    helper.shutdown()
}

main()
