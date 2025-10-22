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
	configPath       string
	serverAddr       string
	serverPort       int
	username         string
	password         string
	protocol         string // 添加协议类型字段
	running          bool
	mutex            sync.Mutex
	tunnelReady      bool
	tunnelMutex      sync.RWMutex
	cmd              *exec.Cmd // 用于外部OpenVPN进程
	tunIP            string    // TUN设备的IP地址
	helperConfigPath string    // 特权助手处理后的配置文件路径
}

// NewOpenVPNClient 创建新的OpenVPN客户端
func NewOpenVPNClient(configPath, serverAddr string, serverPort int, socksPort int) *OpenVPNClient {
	client := &OpenVPNClient{
		configPath:       configPath,
		serverAddr:       serverAddr,
		serverPort:       serverPort,
		protocol:         "udp", // 默认使用UDP协议
		helperConfigPath: "",    // 初始化为空
	}

	// 从配置文件中解析协议类型
	if configPath != "" {
		if proto, err := client.getProtocolFromConfig(configPath); err == nil {
			client.protocol = proto
		}
	}

	return client
}

// SetCredentials 设置用户名和密码
func (oc *OpenVPNClient) SetCredentials(username, password string) {
	oc.mutex.Lock()
	defer oc.mutex.Unlock()
	oc.username = username
	oc.password = password
	log.Printf("OpenVPN客户端设置凭据: username=%s", username)
}

// SetHelperConfigPath 设置特权助手处理后的配置文件路径
func (oc *OpenVPNClient) SetHelperConfigPath(helperConfigPath string) {
	oc.mutex.Lock()
	defer oc.mutex.Unlock()
	oc.helperConfigPath = helperConfigPath
	log.Printf("设置特权助手处理后的配置文件路径: %s", helperConfigPath)
}

// IsRunning 检查OpenVPN客户端是否正在运行
func (oc *OpenVPNClient) IsRunning() bool {
	oc.mutex.Lock()
	defer oc.mutex.Unlock()
	return oc.running
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
	log.Printf("4-当前用户 UID: %d", os.Getuid())
	log.Printf("4-当前工作目录: %s", func() string { p, _ := os.Getwd(); return p }())
	log.Printf("4-操作的文件路径: %s", configPath)
	// 读取原始配置文件
	content, err := os.ReadFile(configPath)
	if err != nil {
		log.Printf("4-错误详情: %v", err)
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

	if oc.running {
		oc.mutex.Unlock()
		return nil
	}
	oc.mutex.Unlock()

	// 在其他平台上使用标准启动流程
	return oc.startOpenVPNStandard()
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
	// 在新的实现中，我们直接使用应用包中的OpenVPN二进制文件
	// 而不是提取嵌入的二进制文件到临时目录
	log.Printf("1-当前用户 UID: %d", os.Getuid())
	log.Printf("1-当前工作目录: %s", func() string { p, _ := os.Getwd(); return p }())

	execPath, err := os.Executable()
	log.Printf("1-操作的文件路径: %s", execPath)
	if err != nil {
		log.Printf("1-错误详情: %v", err)
		return "", fmt.Errorf("获取可执行文件路径失败: %v", err)
	}

	// 构建应用包中Resources目录下的OpenVPN二进制文件路径
	// 路径为: Contents/Resources/bin/openvpn
	openvpnPath := filepath.Join(filepath.Dir(execPath), "..", "bin", "openvpn")
	log.Printf("查找OpenVPN二进制文件路径: %s", openvpnPath)

	// 检查文件是否存在
	if _, err := os.Stat(openvpnPath); os.IsNotExist(err) {
		log.Printf("OpenVPN二进制文件不存在: %v", err)
		return "", fmt.Errorf("OpenVPN二进制文件不存在: %s", openvpnPath)
	}

	// 检查文件是否可执行
	fileInfo, err := os.Stat(openvpnPath)
	if err != nil {
		log.Printf("无法获取OpenVPN二进制文件信息: %v", err)
		return "", fmt.Errorf("无法获取OpenVPN二进制文件信息: %s", openvpnPath)
	}

	// 检查执行权限位
	if fileInfo.Mode()&0111 == 0 {
		log.Printf("OpenVPN二进制文件不可执行，尝试添加执行权限")
		// 尝试添加执行权限
		if err := os.Chmod(openvpnPath, 0755); err != nil {
			log.Printf("添加执行权限失败: %v", err)
			return "", fmt.Errorf("OpenVPN二进制文件不可执行且无法添加权限: %s", openvpnPath)
		}
	}

	log.Printf("成功找到OpenVPN二进制文件: %s", openvpnPath)
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

		// 提取TUN设备的IP地址
		// 匹配类似 "TUN/TAP device tun0 opened" 和 "net_iface_mtu_set: mtu 1500 for tun0"
		// 或者 "do_ifconfig, tt->did_ifconfig_ipv6_setup=0" 后面跟着IP地址信息
		// 或者 "/sbin/ifconfig tun0 10.8.0.6 pointopoint 10.8.0.5 mtu 1500"
		if strings.Contains(line, "/sbin/ifconfig") && strings.Contains(line, "pointopoint") {
			// 解析ifconfig命令行中的IP地址
			parts := strings.Fields(line)
			for i, part := range parts {
				if part == "pointopoint" && i > 2 {
					// IP地址通常在pointopoint之前
					if i > 0 {
						ip := parts[i-1]
						if net.ParseIP(ip) != nil {
							oc.tunnelMutex.Lock()
							oc.tunIP = ip
							oc.tunnelMutex.Unlock()
							log.Printf("提取到TUN设备IP地址: %s", ip)
						}
					}
					break
				}
			}
		} else if strings.Contains(line, "Initialization Sequence Completed") {
			// 如果在初始化完成时还没有获取到IP地址，尝试从系统获取
			go oc.getTunIPFromSystem()
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

// getTunIPFromSystem 从系统获取TUN设备的IP地址
func (oc *OpenVPNClient) getTunIPFromSystem() {
	// 等待一段时间让TUN设备完全初始化
	time.Sleep(2 * time.Second)

	// 在macOS和Linux上尝试获取TUN设备IP
	var cmd *exec.Cmd
	if runtime.GOOS == "darwin" {
		// macOS上使用ifconfig
		cmd = exec.Command("ifconfig")
	} else if runtime.GOOS == "linux" {
		// Linux上使用ip addr
		cmd = exec.Command("ip", "addr")
	} else {
		return
	}

	output, err := cmd.Output()
	if err != nil {
		log.Printf("获取网络接口信息失败: %v", err)
		return
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		// 查找TUN设备相关行
		if strings.Contains(line, "tun") && strings.Contains(line, "inet") {
			// 解析IP地址
			fields := strings.Fields(line)
			for i, field := range fields {
				if field == "inet" && i+1 < len(fields) {
					ip := fields[i+1]
					// 移除可能的子网掩码
					if strings.Contains(ip, "/") {
						ip = strings.Split(ip, "/")[0]
					}
					if net.ParseIP(ip) != nil {
						oc.tunnelMutex.Lock()
						oc.tunIP = ip
						oc.tunnelMutex.Unlock()
						log.Printf("从系统获取到TUN设备IP地址: %s", ip)
						return
					}
				}
			}
		}
	}
}

// GetTunIP 获取TUN设备的IP地址
func (oc *OpenVPNClient) GetTunIP() string {
	oc.tunnelMutex.RLock()
	defer oc.tunnelMutex.RUnlock()
	return oc.tunIP
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

	// 直接通过系统网络栈连接到目标地址（流量会自动通过TUN设备传输）
	log.Printf("通过OpenVPN隧道连接到目标: %s", targetAddr)
	conn, err := net.DialTimeout("tcp", targetAddr, 30*time.Second)
	if err != nil {
		log.Printf("通过OpenVPN隧道连接到目标失败: %v", err)
		return nil, fmt.Errorf("failed to connect to target %s through OpenVPN: %v", targetAddr, err)
	}

	log.Printf("成功通过OpenVPN隧道连接到目标: %s", targetAddr)
	return conn, nil
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

// startOpenVPNStandard 标准的OpenVPN启动流程
func (oc *OpenVPNClient) startOpenVPNStandard() error {
	// 保存必要的参数用于后续启动
	configPath := oc.configPath
	serverAddr := oc.serverAddr
	serverPort := oc.serverPort
	protocol := oc.protocol
	username := oc.username
	password := oc.password
	helperConfigPath := oc.helperConfigPath

	log.Printf("启动OpenVPN客户端: configPath=%s, server=%s, port=%d, protocol=%s", configPath, serverAddr, serverPort, protocol)

	// 获取OpenVPN二进制文件路径
	openvpnPath, err := oc.getOpenVPNBinaryPath()
	if err != nil {
		return fmt.Errorf("获取OpenVPN二进制文件路径失败: %v", err)
	}

	// 确定要使用的配置文件路径
	// 如果特权助手已经处理了配置文件，则使用处理后的路径
	var finalConfigPath string
	if helperConfigPath != "" {
		finalConfigPath = helperConfigPath
		log.Printf("使用特权助手处理后的配置文件: %s", finalConfigPath)
	} else {
		// 否则使用原始配置文件路径
		finalConfigPath = configPath
		log.Printf("使用原始配置文件: %s", finalConfigPath)
	}

	// 确定OpenVPN的工作目录
	// 如果有特权助手处理后的配置文件，使用其所在目录作为工作目录
	// 否则使用原始配置文件所在目录
	var workDir string
	if helperConfigPath != "" {
		workDir = filepath.Dir(helperConfigPath)
	} else {
		workDir = filepath.Dir(configPath)
	}
	log.Printf("使用工作目录: %s", workDir)

	// 在工作目录中创建认证文件
	tempAuthPath := filepath.Join(workDir, "auth.txt")
	authContent := fmt.Sprintf("%s\n%s\n", username, password)
	if err := os.WriteFile(tempAuthPath, []byte(authContent), 0600); err != nil {
		return fmt.Errorf("创建认证文件失败: %v", err)
	}

	// 构建OpenVPN命令，使用最终确定的配置文件和认证文件
	var cmd *exec.Cmd
	if runtime.GOOS == "darwin" {
		// 在macOS上，通过特权助手工具启动OpenVPN以确保有足够的权限
		// 注意：特权助手工具已经确保了权限，所以这里不需要sudo
		cmd = exec.Command(openvpnPath, "--config", finalConfigPath, "--auth-user-pass", tempAuthPath, "--proto", protocol, "--dev-type", "tun", "--dev", "tun", "--persist-tun", "--pull")

		// 设置DYLD_LIBRARY_PATH环境变量，指向openvpn_frameworks目录以解决动态库加载问题
		appContentsDir := filepath.Join(filepath.Dir(openvpnPath), "..", "..")
		frameworksPath := filepath.Join(appContentsDir, "Resources", "openvpn_frameworks")
		cmd.Env = append(os.Environ(), "DYLD_LIBRARY_PATH="+frameworksPath)
		log.Printf("设置DYLD_LIBRARY_PATH环境变量: %s", frameworksPath)
	} else {
		// 在其他平台上直接运行OpenVPN
		cmd = exec.Command(openvpnPath, "--config", finalConfigPath, "--auth-user-pass", tempAuthPath, "--proto", protocol, "--dev-type", "tun", "--dev", "tun", "--pull")
	}

	cmd.Dir = workDir // 设置工作目录
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
	log.Printf("启动OpenVPN进程: %s, protocol=%s, workdir=%s", openvpnPath, protocol, workDir)
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("启动OpenVPN进程失败: %v", err)
	}

	// 更新客户端状态
	oc.mutex.Lock()
	oc.cmd = cmd
	oc.configPath = configPath
	oc.serverAddr = serverAddr
	oc.serverPort = serverPort
	oc.protocol = protocol
	oc.username = username
	oc.password = password
	oc.mutex.Unlock()

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

	// 更新运行状态
	oc.mutex.Lock()
	oc.running = true
	oc.tunnelReady = true
	oc.mutex.Unlock()

	log.Printf("OpenVPN客户端已启动: configPath=%s", configPath)
	return nil
}
