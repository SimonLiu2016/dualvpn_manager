package openvpn

import (
	"bufio"
	_ "embed"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"
)

//go:embed openvpn_bin/openvpn
var openvpnBinary []byte

// OpenVPNClient 内部OpenVPN客户端实现
type OpenVPNClient struct {
	configPath   string
	serverAddr   string
	serverPort   int
	username     string
	password     string
	protocol     string // 添加协议类型字段
	running      bool
	socksPort    int
	mutex        sync.Mutex
	tunnelReady  bool
	tunnelMutex  sync.RWMutex
	socksServer  net.Listener
	socksRunning bool
	socksMutex   sync.RWMutex
	cmd          *exec.Cmd // 用于外部OpenVPN进程
}

// NewOpenVPNClient 创建新的OpenVPN客户端
func NewOpenVPNClient(configPath, serverAddr string, serverPort int, socksPort int) *OpenVPNClient {
	client := &OpenVPNClient{
		configPath: configPath,
		serverAddr: serverAddr,
		serverPort: serverPort,
		socksPort:  socksPort,
		protocol:   "udp", // 默认使用UDP协议
	}

	// 从配置文件中解析协议类型
	if configPath != "" {
		if proto, err := client.getProtocolFromConfig(configPath); err == nil {
			client.protocol = proto
		}
	}

	return client
}

// copyRequiredFiles 解析配置文件并复制所需的证书文件
func (oc *OpenVPNClient) copyRequiredFiles(configPath, tempDir string) error {
	file, err := os.Open(configPath)
	if err != nil {
		return err
	}
	defer file.Close()

	// 获取配置文件所在目录
	configDir := filepath.Dir(configPath)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		// 忽略注释行
		if strings.HasPrefix(line, "#") || strings.HasPrefix(line, ";") || line == "" {
			continue
		}

		// 解析需要的文件指令
		for _, directive := range []string{"ca", "cert", "key", "dh", "tls-auth", "pkcs12"} {
			if strings.HasPrefix(line, directive+" ") {
				parts := strings.Split(line, " ")
				if len(parts) >= 2 {
					filePath := parts[1]
					// 如果是相对路径，则相对于配置文件目录
					if !filepath.IsAbs(filePath) {
						filePath = filepath.Join(configDir, filePath)
					}
					// 复制文件到临时目录
					destPath := filepath.Join(tempDir, filepath.Base(filePath))
					if err := copyFile(filePath, destPath); err != nil {
						log.Printf("警告: 复制文件 %s 失败: %v", filePath, err)
					} else {
						log.Printf("成功复制文件: %s -> %s", filePath, destPath)
					}
				}
				break
			}
		}
	}

	return scanner.Err()
}

// modifyConfigFile 修改配置文件，添加一些必要的选项
func (oc *OpenVPNClient) modifyConfigFile(configPath, tempConfigPath string) error {
	// 读取原始配置文件
	content, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}

	// 将内容转换为字符串并按行分割
	lines := strings.Split(string(content), "\n")

	// 创建新的配置内容
	var newLines []string
	existingOptions := make(map[string]bool)

	// 检查已存在的选项
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed != "" && !strings.HasPrefix(trimmed, "#") && !strings.HasPrefix(trimmed, ";") {
			parts := strings.Fields(trimmed)
			if len(parts) > 0 {
				existingOptions[parts[0]] = true
			}
		}
		newLines = append(newLines, line)
	}

	// 添加必要的选项来解决AEAD解密错误
	if !existingOptions["mute-replay-warnings"] {
		newLines = append(newLines, "mute-replay-warnings")
		log.Printf("添加配置选项: mute-replay-warnings")
	}

	if !existingOptions["reneg-sec"] {
		newLines = append(newLines, "reneg-sec 0")
		log.Printf("添加配置选项: reneg-sec 0")
	}

	if !existingOptions["auth-nocache"] {
		newLines = append(newLines, "auth-nocache")
		log.Printf("添加配置选项: auth-nocache")
	}

	// 写入修改后的配置文件
	return os.WriteFile(tempConfigPath, []byte(strings.Join(newLines, "\n")), 0644)
}

// Start 启动OpenVPN客户端
func (oc *OpenVPNClient) Start() error {
	oc.mutex.Lock()
	defer oc.mutex.Unlock()

	if oc.running {
		return nil
	}

	log.Printf("启动OpenVPN客户端: configPath=%s, server=%s, port=%d, protocol=%s", oc.configPath, oc.serverAddr, oc.serverPort, oc.protocol)

	// OpenVPN功能完全集成在软件内部，对用户不可见
	// 使用打包在软件中的OpenVPN二进制文件

	// 获取OpenVPN二进制文件路径
	openvpnPath, err := oc.getOpenVPNBinaryPath()
	if err != nil {
		return fmt.Errorf("获取OpenVPN二进制文件路径失败: %v", err)
	}

	// 检查OpenVPN二进制文件是否具有执行权限
	if err := os.Chmod(openvpnPath, 0755); err != nil {
		log.Printf("警告: 设置OpenVPN二进制文件执行权限失败: %v", err)
	}

	// 创建临时目录用于存放配置文件和证书文件
	tempDir, err := os.MkdirTemp("", "openvpn-*")
	if err != nil {
		return fmt.Errorf("创建临时目录失败: %v", err)
	}
	defer os.RemoveAll(tempDir) // 确保在函数退出时清理临时目录

	// 复制配置文件到临时目录
	configFileName := filepath.Base(oc.configPath)
	tempConfigPath := filepath.Join(tempDir, configFileName)

	// 修改配置文件，添加必要的选项
	if err := oc.modifyConfigFile(oc.configPath, tempConfigPath); err != nil {
		log.Printf("修改配置文件失败，使用原始配置文件: %v", err)
		if err := copyFile(oc.configPath, tempConfigPath); err != nil {
			return fmt.Errorf("复制配置文件失败: %v", err)
		}
	}

	// 解析配置文件并复制所需的证书文件到临时目录
	if err := oc.copyRequiredFiles(oc.configPath, tempDir); err != nil {
		return fmt.Errorf("复制证书文件失败: %v", err)
	}

	// 添加用户名和密码到配置文件
	tempAuthPath := filepath.Join(tempDir, "auth.txt")
	authContent := fmt.Sprintf("%s\n%s\n", oc.username, oc.password)
	if err := os.WriteFile(tempAuthPath, []byte(authContent), 0600); err != nil {
		return fmt.Errorf("创建认证文件失败: %v", err)
	}

	// 构建OpenVPN命令，使用临时目录中的配置文件和认证文件
	// 在macOS上，我们尝试不同的方法来解决TUN设备权限问题
	var cmd *exec.Cmd
	if runtime.GOOS == "darwin" {
		// 在macOS上，尝试添加一些选项来解决TUN设备权限问题
		// 移除sudo，因为我们无法在程序中提供密码
		// 添加--pull选项以允许路由推送
		cmd = exec.Command(openvpnPath, "--config", tempConfigPath, "--auth-user-pass", tempAuthPath, "--proto", oc.protocol, "--dev-type", "tun", "--dev", "tun", "--persist-tun", "--pull")
	} else {
		// 在其他平台上直接运行OpenVPN
		// 添加--pull选项以允许路由推送
		cmd = exec.Command(openvpnPath, "--config", tempConfigPath, "--auth-user-pass", tempAuthPath, "--proto", oc.protocol, "--dev-type", "tun", "--dev", "tun", "--pull")
	}

	cmd.Dir = tempDir // 设置工作目录为临时目录，确保OpenVPN能找到证书文件
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}

	// 捕获OpenVPN的输出
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("创建stdout管道失败: %v", err)
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("创建stderr管道失败: %v", err)
	}

	// 启动OpenVPN进程
	log.Printf("启动OpenVPN进程: %s, protocol=%s, workdir=%s", openvpnPath, oc.protocol, tempDir)
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("启动OpenVPN进程失败: %v", err)
	}

	oc.cmd = cmd

	// 监听OpenVPN输出
	go oc.monitorOpenVPNOutput(stdout, "stdout")
	go oc.monitorOpenVPNOutput(stderr, "stderr")

	// 等待OpenVPN连接建立
	if err := oc.waitForOpenVPNConnection(); err != nil {
		// 记录详细的错误信息
		log.Printf("等待OpenVPN连接建立失败: %v", err)
		// 尝试获取更多错误信息
		if cmd.Process != nil {
			log.Printf("OpenVPN进程PID: %d", cmd.Process.Pid)
		}
		cmd.Process.Kill()
		return fmt.Errorf("等待OpenVPN连接建立失败: %v", err)
	}

	// 确保SOCKS代理服务器已启动并运行
	oc.socksMutex.RLock()
	socksRunning := oc.socksRunning
	oc.socksMutex.RUnlock()

	if !socksRunning {
		// 如果SOCKS代理未运行，尝试直接启动它
		log.Printf("SOCKS代理服务器未运行，尝试直接启动")
		if err := oc.startSOCKSProxy(); err != nil {
			log.Printf("直接启动SOCKS代理服务器失败: %v", err)
			cmd.Process.Kill()
			return fmt.Errorf("SOCKS代理服务器未启动: %v", err)
		}

		// 更新SOCKS运行状态
		oc.socksMutex.Lock()
		oc.socksRunning = true
		oc.socksMutex.Unlock()

		log.Printf("SOCKS代理服务器直接启动成功")
	}

	oc.running = true
	oc.tunnelReady = true
	log.Printf("OpenVPN客户端已启动: configPath=%s", oc.configPath)
	return nil
}

// copyFile 复制文件
func copyFile(src, dst string) error {
	// 确保目标目录存在
	dstDir := filepath.Dir(dst)
	if err := os.MkdirAll(dstDir, 0755); err != nil {
		return fmt.Errorf("创建目标目录失败: %v", err)
	}

	// 打开源文件
	srcFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("打开源文件失败: %v", err)
	}
	defer srcFile.Close()

	// 创建目标文件
	dstFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("创建目标文件失败: %v", err)
	}
	defer dstFile.Close()

	// 复制文件内容
	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return fmt.Errorf("复制文件内容失败: %v", err)
	}

	// 同步文件
	err = dstFile.Sync()
	if err != nil {
		return fmt.Errorf("同步文件失败: %v", err)
	}

	return nil
}

// getOpenVPNBinaryPath 获取OpenVPN二进制文件路径
func (oc *OpenVPNClient) getOpenVPNBinaryPath() (string, error) {
	// 首先检查是否已经提取了嵌入的OpenVPN二进制文件
	execPath, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("获取可执行文件路径失败: %v", err)
	}

	// 创建临时目录用于存放OpenVPN二进制文件
	tempDir := filepath.Join(filepath.Dir(execPath), ".openvpn_cache")
	if err := os.MkdirAll(tempDir, 0755); err != nil {
		return "", fmt.Errorf("创建临时目录失败: %v", err)
	}

	// OpenVPN二进制文件路径
	openvpnPath := filepath.Join(tempDir, "openvpn")

	// 检查文件是否存在且是最新的
	if info, err := os.Stat(openvpnPath); err == nil {
		// 检查文件大小是否匹配
		if info.Size() == int64(len(openvpnBinary)) {
			// 文件已存在且大小匹配，直接返回
			return openvpnPath, nil
		}
	}

	// 文件不存在或不匹配，需要重新创建
	if err := os.WriteFile(openvpnPath, openvpnBinary, 0755); err != nil {
		return "", fmt.Errorf("写入OpenVPN二进制文件失败: %v", err)
	}

	log.Printf("成功提取OpenVPN二进制文件到: %s", openvpnPath)
	return openvpnPath, nil
}

// GetOpenVPNBinaryPath 公共方法获取OpenVPN二进制文件路径
func (oc *OpenVPNClient) GetOpenVPNBinaryPath() (string, error) {
	return oc.getOpenVPNBinaryPath()
}

// createTempConfig 创建临时配置文件
func (oc *OpenVPNClient) createTempConfig() (string, error) {
	// 此方法已弃用，因为我们直接使用原始配置文件
	return "", fmt.Errorf("此方法已弃用")
}

// monitorOpenVPNOutput 监听OpenVPN输出
func (oc *OpenVPNClient) monitorOpenVPNOutput(pipeReader interface{}, pipeName string) {
	var reader *bufio.Scanner

	// 检查pipeReader的类型
	switch r := pipeReader.(type) {
	case *os.File:
		reader = bufio.NewScanner(r)
	case io.ReadCloser:
		reader = bufio.NewScanner(r)
	default:
		log.Printf("未知的管道类型: %T", r)
		return
	}

	for reader.Scan() {
		line := reader.Text()
		log.Printf("OpenVPN %s: %s", pipeName, line)

		// 检查是否连接成功
		if strings.Contains(line, "Initialization Sequence Completed") {
			log.Printf("OpenVPN初始化完成")
			// 设置隧道准备就绪标志
			oc.tunnelMutex.Lock()
			oc.tunnelReady = true
			oc.tunnelMutex.Unlock()
		}

		// 检查是否有错误信息
		if strings.Contains(line, "ERROR") || strings.Contains(line, "error") {
			log.Printf("OpenVPN错误: %s", line)
		}
	}

	if err := reader.Err(); err != nil {
		log.Printf("读取OpenVPN输出时出错: %v", err)
	}
}

// waitForOpenVPNConnection 等待OpenVPN连接建立
func (oc *OpenVPNClient) waitForOpenVPNConnection() error {
	// 等待连接建立，超时时间从30秒增加到60秒
	timeout := time.After(60 * time.Second)
	ticker := time.NewTicker(500 * time.Millisecond) // 增加检查频率到500毫秒
	defer ticker.Stop()

	// 使用通道来接收连接状态
	connected := make(chan bool, 1)

	// 启动一个goroutine来监控连接状态
	go func() {
		oc.mutex.Lock()
		cmd := oc.cmd
		oc.mutex.Unlock()

		if cmd == nil {
			connected <- false
			return
		}

		// 标记SOCKS代理是否已启动
		socksStarted := false

		// 定期检查进程状态和隧道状态
		for {
			select {
			case <-ticker.C:
				// 检查进程是否仍在运行
				if cmd.ProcessState != nil && cmd.ProcessState.Exited() {
					connected <- false
					return
				}

				// 检查隧道是否已准备好
				oc.tunnelMutex.RLock()
				tunnelReady := oc.tunnelReady
				oc.tunnelMutex.RUnlock()

				if tunnelReady {
					// 隧道准备就绪后，启动SOCKS代理服务器（仅启动一次）
					if !socksStarted {
						log.Printf("OpenVPN隧道已准备就绪，准备启动SOCKS代理服务器")
						if err := oc.startSOCKSProxy(); err != nil {
							log.Printf("启动SOCKS代理服务器失败: %v", err)
							connected <- false
							return
						}
						log.Printf("SOCKS代理服务器启动成功")
						socksStarted = true

						// 更新SOCKS运行状态
						oc.socksMutex.Lock()
						oc.socksRunning = true
						oc.socksMutex.Unlock()
					}
					connected <- true
					return
				}
			case <-timeout:
				// 超时直接返回
				connected <- false
				return
			}
		}
	}()

	// 等待连接结果或超时
	result := <-connected
	if !result {
		return fmt.Errorf("OpenVPN连接超时")
	}

	// 确保SOCKS代理服务器已启动并运行
	oc.socksMutex.RLock()
	socksRunning := oc.socksRunning
	socksServer := oc.socksServer
	oc.socksMutex.RUnlock()

	if !socksRunning || socksServer == nil {
		// 如果SOCKS代理未运行，尝试直接启动它
		log.Printf("SOCKS代理服务器未运行或未初始化，尝试直接启动")
		if err := oc.startSOCKSProxy(); err != nil {
			log.Printf("直接启动SOCKS代理服务器失败: %v", err)
			return fmt.Errorf("SOCKS代理服务器未启动: %v", err)
		}

		// 更新SOCKS运行状态
		oc.socksMutex.Lock()
		oc.socksRunning = true
		oc.socksMutex.Unlock()

		log.Printf("SOCKS代理服务器直接启动成功")
	}

	return nil
}

// Stop 停止OpenVPN客户端
func (oc *OpenVPNClient) Stop() error {
	oc.mutex.Lock()
	defer oc.mutex.Unlock()

	if !oc.running {
		return nil
	}

	log.Println("停止OpenVPN客户端")

	// 停止SOCKS代理服务器
	oc.stopSOCKSProxy()

	// 停止OpenVPN进程
	if oc.cmd != nil && oc.cmd.Process != nil {
		// 优雅地停止OpenVPN进程
		oc.cmd.Process.Signal(syscall.SIGTERM)

		// 等待进程结束，最多等待5秒
		done := make(chan error, 1)
		go func() {
			done <- oc.cmd.Wait()
		}()

		select {
		case <-time.After(5 * time.Second):
			// 超时，强制杀死进程
			oc.cmd.Process.Kill()
		case <-done:
			// 进程正常结束
		}
	}

	oc.running = false
	oc.tunnelReady = false
	log.Println("OpenVPN客户端已停止")
	return nil
}

// IsRunning 检查OpenVPN客户端是否正在运行
func (oc *OpenVPNClient) IsRunning() bool {
	oc.mutex.Lock()
	defer oc.mutex.Unlock()
	return oc.running
}

// SetCredentials 设置用户名和密码
func (oc *OpenVPNClient) SetCredentials(username, password string) {
	oc.username = username
	oc.password = password
	log.Printf("OpenVPN客户端设置凭据: username=%s", username)
}

// ConnectToTarget 通过OpenVPN连接到目标地址
func (oc *OpenVPNClient) ConnectToTarget(targetAddr string) (net.Conn, error) {
	log.Printf("ConnectToTarget方法开始执行: targetAddr=%s", targetAddr)

	// 检查OpenVPN隧道是否已建立
	oc.tunnelMutex.RLock()
	tunnelReady := oc.tunnelReady
	oc.tunnelMutex.RUnlock()

	log.Printf("ConnectToTarget: tunnelReady=%v, targetAddr=%s", tunnelReady, targetAddr)

	if !tunnelReady {
		log.Printf("OpenVPN隧道未建立，返回错误")
		return nil, fmt.Errorf("OpenVPN隧道未建立")
	}

	// 检查SOCKS代理是否正在运行
	oc.socksMutex.RLock()
	socksRunning := oc.socksRunning
	socksServer := oc.socksServer
	oc.socksMutex.RUnlock()

	log.Printf("ConnectToTarget: socksRunning=%v, socksPort=%d, socksServer=%v", socksRunning, oc.socksPort, socksServer)

	if !socksRunning || socksServer == nil {
		// 如果SOCKS代理未运行，尝试启动它
		log.Printf("SOCKS代理未运行或未初始化，尝试启动")
		if err := oc.startSOCKSProxy(); err != nil {
			log.Printf("启动SOCKS代理失败: %v", err)
			return nil, fmt.Errorf("启动SOCKS代理失败: %v", err)
		}

		// 更新SOCKS运行状态
		oc.socksMutex.Lock()
		oc.socksRunning = true
		oc.socksMutex.Unlock()

		log.Printf("SOCKS代理启动成功")
	}

	// 通过SOCKS代理连接到目标地址，这样流量会通过OpenVPN隧道
	socksAddr := fmt.Sprintf("127.0.0.1:%d", oc.socksPort)
	log.Printf("尝试连接到SOCKS代理: %s，目标地址: %s", socksAddr, targetAddr)

	// 增加连接超时时间到30秒
	conn, err := net.DialTimeout("tcp", socksAddr, 30*time.Second)
	if err != nil {
		log.Printf("连接到SOCKS代理失败: %v", err)
		// 尝试重启SOCKS代理
		log.Printf("尝试重启SOCKS代理")
		oc.socksMutex.Lock()
		if oc.socksServer != nil {
			oc.socksServer.Close()
		}
		oc.socksMutex.Unlock()

		if err := oc.startSOCKSProxy(); err != nil {
			log.Printf("重启SOCKS代理失败: %v", err)
			return nil, fmt.Errorf("连接到SOCKS代理失败: %v", err)
		}

		// 再次尝试连接
		conn, err = net.DialTimeout("tcp", socksAddr, 30*time.Second)
		if err != nil {
			log.Printf("重启后连接到SOCKS代理仍然失败: %v", err)
			return nil, fmt.Errorf("连接到SOCKS代理失败: %v", err)
		}
		log.Printf("重启后连接到SOCKS代理成功")
	}

	log.Printf("成功连接到SOCKS代理，开始SOCKS握手")

	// 发送SOCKS5握手
	// 版本5，1种认证方法（无需认证）
	_, err = conn.Write([]byte{0x05, 0x01, 0x00})
	if err != nil {
		conn.Close()
		log.Printf("发送SOCKS握手失败: %v", err)
		return nil, fmt.Errorf("发送SOCKS握手失败: %v", err)
	}

	// 读取服务器响应
	buf := make([]byte, 2)
	_, err = conn.Read(buf)
	if err != nil {
		conn.Close()
		log.Printf("读取SOCKS握手响应失败: %v", err)
		return nil, fmt.Errorf("读取SOCKS握手响应失败: %v", err)
	}

	// 检查服务器是否接受我们的认证方法
	if buf[0] != 0x05 || buf[1] != 0x00 {
		conn.Close()
		log.Printf("SOCKS服务器不支持无需认证: version=%d, method=%d", buf[0], buf[1])
		return nil, fmt.Errorf("SOCKS服务器不支持无需认证: version=%d, method=%d", buf[0], buf[1])
	}

	log.Printf("SOCKS握手成功，发送连接请求")

	// 发送连接请求
	host, port, err := net.SplitHostPort(targetAddr)
	if err != nil {
		conn.Close()
		log.Printf("解析目标地址失败: %v", err)
		return nil, fmt.Errorf("解析目标地址失败: %v", err)
	}

	var portNum int
	fmt.Sscanf(port, "%d", &portNum)

	// 构造连接请求
	request := []byte{0x05, 0x01, 0x00} // 版本5，CONNECT命令，保留字段
	if ip := net.ParseIP(host); ip != nil {
		if ip.To4() != nil {
			// IPv4
			request = append(request, 0x01) // 地址类型：IPv4
			request = append(request, ip.To4()...)
		} else {
			// IPv6
			request = append(request, 0x04) // 地址类型：IPv6
			request = append(request, ip.To16()...)
		}
	} else {
		// 域名
		request = append(request, 0x03) // 地址类型：域名
		request = append(request, byte(len(host)))
		request = append(request, []byte(host)...)
	}
	request = append(request, byte(portNum>>8), byte(portNum&0xFF))

	log.Printf("发送SOCKS连接请求到 %s", targetAddr)
	_, err = conn.Write(request)
	if err != nil {
		conn.Close()
		log.Printf("发送连接请求失败: %v", err)
		return nil, fmt.Errorf("发送连接请求失败: %v", err)
	}

	log.Printf("SOCKS连接请求发送成功，等待响应")

	// 读取连接响应，设置读取超时
	conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	buf = make([]byte, 10) // 足够读取响应头
	n, err := conn.Read(buf)
	if err != nil {
		conn.Close()
		log.Printf("读取连接响应失败: %v", err)
		return nil, fmt.Errorf("读取连接响应失败: %v", err)
	}
	log.Printf("收到SOCKS连接响应: n=%d, data=%x", n, buf[:n])

	// 检查连接是否成功
	if buf[0] != 0x05 {
		conn.Close()
		log.Printf("SOCKS版本错误: expected=5, got=%d", buf[0])
		return nil, fmt.Errorf("SOCKS版本错误: expected=5, got=%d", buf[0])
	}

	if buf[1] != 0x00 {
		conn.Close()
		log.Printf("SOCKS连接失败: reply=%d", buf[1])
		// 添加更详细的错误信息
		replyCode := buf[1]
		var replyMsg string
		switch replyCode {
		case 0x01:
			replyMsg = "general SOCKS server failure"
		case 0x02:
			replyMsg = "connection not allowed by ruleset"
		case 0x03:
			replyMsg = "Network unreachable"
		case 0x04:
			replyMsg = "Host unreachable"
		case 0x05:
			replyMsg = "Connection refused"
		case 0x06:
			replyMsg = "TTL expired"
		case 0x07:
			replyMsg = "Command not supported"
		case 0x08:
			replyMsg = "Address type not supported"
		default:
			replyMsg = "unknown error"
		}
		log.Printf("SOCKS错误详情: %s (code: %d)", replyMsg, replyCode)
		return nil, fmt.Errorf("SOCKS连接失败: %s (code: %d)", replyMsg, replyCode)
	}

	log.Printf("SOCKS连接成功，读取地址信息")

	// 根据地址类型跳过剩余的地址字段
	switch buf[3] {
	case 0x01: // IPv4
		// 还需要读取剩余的6字节（IPv4地址4字节 + 端口2字节）
		_, err = conn.Read(buf[:6])
		log.Printf("读取IPv4地址信息: %v", err)
	case 0x03: // 域名
		// 读取域名长度
		_, err = conn.Read(buf[:1])
		if err != nil {
			conn.Close()
			log.Printf("读取域名长度失败: %v", err)
			return nil, fmt.Errorf("读取域名长度失败: %v", err)
		}
		// 读取域名和端口
		domainLen := int(buf[0])
		_, err = conn.Read(buf[:domainLen+2])
		log.Printf("读取域名信息: len=%d, err=%v", domainLen, err)
	case 0x04: // IPv6
		// 还需要读取剩余的18字节（IPv6地址16字节 + 端口2字节）
		_, err = conn.Read(buf[:18])
		log.Printf("读取IPv6地址信息: %v", err)
	}

	if err != nil {
		conn.Close()
		log.Printf("读取地址信息失败: %v", err)
		return nil, fmt.Errorf("读取地址信息失败: %v", err)
	}

	// 清除读取超时设置
	conn.SetReadDeadline(time.Time{})

	log.Printf("成功通过SOCKS代理连接到目标地址: %s", targetAddr)
	return conn, nil
}

// startSOCKSProxy 启动SOCKS代理服务器
func (oc *OpenVPNClient) startSOCKSProxy() error {
	// 检查SOCKS端口是否已被占用
	addr := fmt.Sprintf("127.0.0.1:%d", oc.socksPort)
	log.Printf("尝试启动SOCKS代理服务器: %s", addr)

	// 先检查端口是否已被占用，如果占用则尝试关闭
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		log.Printf("启动SOCKS代理失败: %v", err)
		return fmt.Errorf("启动SOCKS代理失败: %v", err)
	}

	// 关闭之前的SOCKS服务器（如果存在）
	oc.socksMutex.Lock()
	if oc.socksServer != nil {
		log.Printf("关闭之前的SOCKS服务器")
		oc.socksServer.Close()
	}
	oc.socksServer = listener
	oc.socksRunning = true
	oc.socksMutex.Unlock()

	log.Printf("SOCKS代理已启动: %s", addr)

	// 在单独的goroutine中处理连接
	go oc.handleSOCKSConnections()

	return nil
}

// stopSOCKSProxy 停止SOCKS代理服务器
func (oc *OpenVPNClient) stopSOCKSProxy() {
	oc.socksMutex.Lock()
	defer oc.socksMutex.Unlock()

	if oc.socksRunning && oc.socksServer != nil {
		log.Printf("停止SOCKS代理服务器")
		oc.socksServer.Close()
		oc.socksRunning = false
		log.Println("SOCKS代理已停止")
	}
}

// handleSOCKSConnections 处理SOCKS连接
func (oc *OpenVPNClient) handleSOCKSConnections() {
	log.Printf("开始监听SOCKS连接")

	for {
		oc.socksMutex.RLock()
		running := oc.socksRunning
		server := oc.socksServer
		oc.socksMutex.RUnlock()

		if !running || server == nil {
			log.Printf("SOCKS代理已停止或未初始化，退出监听循环")
			break
		}

		conn, err := server.Accept()
		if err != nil {
			// 检查是否是超时错误
			if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
				// 超时继续循环
				continue
			}
			// 如果不是超时错误且服务仍在运行，则记录错误
			oc.socksMutex.RLock()
			stillRunning := oc.socksRunning
			oc.socksMutex.RUnlock()
			if stillRunning {
				log.Printf("接受SOCKS连接失败: %v", err)
			}
			continue
		}

		log.Printf("接受到新的SOCKS连接: %s", conn.RemoteAddr().String())
		go oc.handleSOCKSConnection(conn)
	}
}

// handleSOCKSConnection 处理单个SOCKS连接
func (oc *OpenVPNClient) handleSOCKSConnection(clientConn net.Conn) {
	defer clientConn.Close()

	log.Printf("开始处理SOCKS连接")

	// 简化的SOCKS5握手过程
	buf := make([]byte, 256)
	n, err := clientConn.Read(buf)
	if err != nil {
		log.Printf("读取SOCKS握手失败: %v", err)
		return
	}
	log.Printf("收到SOCKS握手请求: n=%d, data=%x", n, buf[:n])

	// 检查SOCKS版本和认证方法
	if n < 2 || buf[0] != 0x05 {
		log.Printf("无效的SOCKS版本: expected=5, got=%d", buf[0])
		return
	}

	// 发送认证方法选择（无需认证）
	_, err = clientConn.Write([]byte{0x05, 0x00})
	if err != nil {
		log.Printf("发送SOCKS认证响应失败: %v", err)
		return
	}
	log.Printf("发送SOCKS认证响应成功")

	// 读取连接请求
	n, err = clientConn.Read(buf)
	if err != nil {
		log.Printf("读取SOCKS请求失败: %v", err)
		return
	}
	log.Printf("收到SOCKS连接请求: n=%d, data=%x", n, buf[:n])

	// 解析目标地址
	if n < 5 || buf[0] != 0x05 || buf[1] != 0x01 {
		log.Printf("无效的SOCKS请求: version=%d, command=%d", buf[0], buf[1])
		return
	}

	var targetAddr string
	switch buf[3] {
	case 0x01: // IPv4
		if n < 10 {
			log.Printf("无效的IPv4地址")
			return
		}
		ip := net.IP(buf[4:8])
		port := int(buf[8])<<8 | int(buf[9])
		targetAddr = fmt.Sprintf("%s:%d", ip.String(), port)
		log.Printf("解析IPv4地址: %s", targetAddr)
	case 0x03: // 域名
		if n < 5 {
			log.Printf("无效的域名地址")
			return
		}
		domainLen := int(buf[4])
		if n < 5+domainLen+2 {
			log.Printf("无效的域名地址")
			return
		}
		domain := string(buf[5 : 5+domainLen])
		port := int(buf[5+domainLen])<<8 | int(buf[5+domainLen+1])
		targetAddr = fmt.Sprintf("%s:%d", domain, port)
		log.Printf("解析域名地址: %s", targetAddr)
	case 0x04: // IPv6
		if n < 22 {
			log.Printf("无效的IPv6地址")
			return
		}
		ip := net.IP(buf[4:20])
		port := int(buf[20])<<8 | int(buf[21])
		targetAddr = fmt.Sprintf("[%s]:%d", ip.String(), port)
		log.Printf("解析IPv6地址: %s", targetAddr)
	default:
		log.Printf("不支持的地址类型: %d", buf[3])
		return
	}

	// 发送连接成功的响应
	response := []byte{0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
	_, err = clientConn.Write(response)
	if err != nil {
		log.Printf("发送SOCKS连接成功响应失败: %v", err)
		return
	}
	log.Printf("发送SOCKS连接成功响应")

	// 通过OpenVPN隧道连接到目标地址
	// 注意：这里需要实际通过TUN设备或系统网络栈转发流量
	// 由于我们使用的是外部OpenVPN进程，流量会自动通过TUN设备传输

	// 检查OpenVPN隧道是否已建立
	oc.tunnelMutex.RLock()
	tunnelReady := oc.tunnelReady
	oc.tunnelMutex.RUnlock()

	if !tunnelReady {
		log.Printf("OpenVPN隧道未建立，无法连接到目标地址: %s", targetAddr)
		return
	}

	// 通过系统网络栈连接到目标地址（流量将自动通过OpenVPN隧道传输）
	log.Printf("通过OpenVPN隧道连接到目标地址: %s", targetAddr)
	targetConn, err := net.DialTimeout("tcp", targetAddr, 30*time.Second)
	if err != nil {
		log.Printf("连接到目标地址失败: %v", err)
		// 发送连接失败的响应
		errorResponse := []byte{0x05, 0x05, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
		clientConn.Write(errorResponse)
		return
	}
	defer targetConn.Close()
	log.Printf("成功连接到目标地址: %s", targetAddr)

	// 在客户端和目标服务器之间转发数据
	// 使用带缓冲的通道来协调两个goroutine
	done := make(chan error, 2)

	// 客户端到目标服务器的数据流（上传）
	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := clientConn.Read(buf)
			if err != nil {
				if err != io.EOF {
					done <- fmt.Errorf("从客户端读取数据失败: %v", err)
					return
				}
				done <- nil
				return
			}
			log.Printf("从客户端读取数据: %d 字节", n)
			_, err = targetConn.Write(buf[:n])
			if err != nil {
				done <- fmt.Errorf("向目标服务器写入数据失败: %v", err)
				return
			}
			log.Printf("向目标服务器写入数据: %d 字节", n)
		}
	}()

	// 目标服务器到客户端的数据流（下载）
	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := targetConn.Read(buf)
			if err != nil {
				if err != io.EOF {
					done <- fmt.Errorf("从目标服务器读取数据失败: %v", err)
					return
				}
				done <- nil
				return
			}
			log.Printf("从目标服务器读取数据: %d 字节", n)
			_, err = clientConn.Write(buf[:n])
			if err != nil {
				done <- fmt.Errorf("向客户端写入数据失败: %v", err)
				return
			}
			log.Printf("向客户端写入数据: %d 字节", n)
		}
	}()

	// 等待任一方向的数据传输完成或出错
	err = <-done
	if err != nil {
		log.Printf("数据转发过程中出现错误: %v", err)
	} else {
		log.Printf("数据转发完成")
	}

	log.Printf("通过OpenVPN隧道成功连接到目标地址: %s", targetAddr)
}

// getProtocolFromConfig 从配置文件中解析协议类型
func (oc *OpenVPNClient) getProtocolFromConfig(configPath string) (string, error) {
	file, err := os.Open(configPath)
	if err != nil {
		return "udp", err // 默认返回UDP
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		// 忽略注释行
		if strings.HasPrefix(line, "#") || strings.HasPrefix(line, ";") || line == "" {
			continue
		}

		// 解析proto指令
		if strings.HasPrefix(line, "proto ") {
			parts := strings.Split(line, " ")
			if len(parts) >= 2 {
				proto := strings.ToLower(parts[1])
				if proto == "udp" || proto == "udp4" || proto == "udp6" {
					return "udp", nil
				} else if proto == "tcp" || proto == "tcp4" || proto == "tcp6" {
					return "tcp", nil
				}
			}
		}
	}

	// 如果没有找到proto指令，默认返回udp
	return "udp", nil
}
