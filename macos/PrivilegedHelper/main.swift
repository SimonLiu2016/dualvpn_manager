import Foundation
import ServiceManagement

@objc protocol PrivilegedHelperProtocol {
    func runGoProxyCore(executablePath: String, executableDir: String, arguments: [String], completion: @escaping (Bool, String?) -> Void, logHandler: @escaping (String) -> Void)
}

class PrivilegedHelper: NSObject, PrivilegedHelperProtocol, NSXPCListenerDelegate {
    private let logFilePath = "/tmp/privileged_helper.log"

    // 初始化日志文件
    fileprivate func initializeLogFile() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logFilePath) {
            fileManager.createFile(atPath: logFilePath, contents: nil, attributes: [.posixPermissions: 0o666])
            print("PrivilegedHelper: Created log file at \(logFilePath)")
        }
    }

    // 写入日志到文件
    fileprivate func writeToLogFile(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        do {
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logFilePath))
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
            print("PrivilegedHelper: Wrote to log file: \(message)")
        } catch {
            // 如果无法追加，尝试直接写入
            try? logMessage.write(to: URL(fileURLWithPath: logFilePath), atomically: true, encoding: .utf8)
            print("PrivilegedHelper: Failed to write to log file: \(error.localizedDescription)")
        }
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        initializeLogFile()
        writeToLogFile("Accepting new XPC connection from \(newConnection)")
        print("PrivilegedHelper: Accepting new XPC connection from \(newConnection)")
        newConnection.exportedInterface = NSXPCInterface(with: PrivilegedHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func runGoProxyCore(executablePath: String, executableDir: String, arguments: [String], completion: @escaping (Bool, String?) -> Void, logHandler: @escaping (String) -> Void) {
        writeToLogFile("runGoProxyCore called with executablePath: \(executablePath), executableDir: \(executableDir), arguments: \(arguments)")
        print("PrivilegedHelper: runGoProxyCore called with executablePath: \(executablePath), executableDir: \(executableDir), arguments: \(arguments)")

        // 验证路径安全性
        let allowedPathPrefix = "/Applications/dualvpn_manager.app/Contents/Resources/bin"
        guard executablePath.hasPrefix(allowedPathPrefix) else {
            let errorMsg = "Invalid executable path prefix: \(executablePath) (expected prefix: \(allowedPathPrefix))"
            writeToLogFile(errorMsg)
            print("PrivilegedHelper: \(errorMsg)")
            completion(false, errorMsg)
            return
        }

        guard FileManager.default.fileExists(atPath: executablePath) else {
            let errorMsg = "Executable path does not exist: \(executablePath)"
            writeToLogFile(errorMsg)
            print("PrivilegedHelper: \(errorMsg)")
            completion(false, errorMsg)
            return
        }

        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            let errorMsg = "Executable path is not executable: \(executablePath)"
            writeToLogFile(errorMsg)
            print("PrivilegedHelper: \(errorMsg)")
            completion(false, errorMsg)
            return
        }

        guard FileManager.default.fileExists(atPath: executableDir) else {
            let errorMsg = "Executable directory does not exist: \(executableDir)"
            writeToLogFile(errorMsg)
            print("PrivilegedHelper: \(errorMsg)")
            completion(false, errorMsg)
            return
        }

        writeToLogFile("Starting go-proxy-core with executable: \(executablePath), directory: \(executableDir), arguments: \(arguments)")
        print("PrivilegedHelper: Starting go-proxy-core with executable: \(executablePath), directory: \(executableDir), arguments: \(arguments)")

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
                self.writeToLogFile(message)
                print("PrivilegedHelper: \(message)")
                logHandler(message)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                let message = "stderr: \(output)"
                self.writeToLogFile(message)
                print("PrivilegedHelper: \(message)")
                logHandler(message)
            }
        }

        process.terminationHandler = { proc in
            let message = "go-proxy-core terminated with status: \(proc.terminationStatus)"
            self.writeToLogFile(message)
            print("PrivilegedHelper: \(message)")
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            completion(proc.terminationStatus == 0, proc.terminationStatus != 0 ? "Terminated with status: \(proc.terminationStatus)" : nil)
        }

        do {
            try process.run()
            writeToLogFile("Successfully started go-proxy-core")
            print("PrivilegedHelper: Successfully started go-proxy-core")
        } catch {
            let errorMsg = "Failed to start go-proxy-core: \(error.localizedDescription)"
            writeToLogFile(errorMsg)
            print("PrivilegedHelper: \(errorMsg)")
            completion(false, errorMsg)
        }
    }
}

func main() {
    let listener = NSXPCListener(machServiceName: "com.v8en.dualvpnManager.PrivilegedHelper")
    let helper = PrivilegedHelper()
    helper.initializeLogFile()
    
    // 使用现有的日志系统替代 syslog
    let uid = getuid()
    let euid = geteuid()
    let pid = getpid()
    let logMessage = "Helper tool started - uid: \(uid), euid: \(euid), pid: \(pid)"
    helper.writeToLogFile(logMessage)
    print("PrivilegedHelper: \(logMessage)")

    helper.writeToLogFile("Starting PrivilegedHelper XPC listener")
    print("PrivilegedHelper: Starting XPC listener")
    listener.delegate = helper
    listener.resume()
    RunLoop.current.run()
}

main()