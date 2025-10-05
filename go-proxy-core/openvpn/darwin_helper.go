//go:build darwin
// +build darwin

package openvpn

import (
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"time"
)

// checkTUNPermissionWithHelper 使用特权助手工具检查TUN设备权限
func (oc *OpenVPNClient) checkTUNPermissionWithHelper() error {
	// Unix域套接字路径
	socketPath := "/var/run/dualvpn_openvpn_helper.sock"

	// 检查套接字文件是否存在
	if _, err := os.Stat(socketPath); os.IsNotExist(err) {
		return fmt.Errorf("特权助手工具未运行或套接字文件不存在: %s", socketPath)
	}

	// 连接到Unix域套接字
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return fmt.Errorf("无法连接到特权助手工具: %v", err)
	}
	defer conn.Close()

	// 发送创建TUN设备的命令
	_, err = conn.Write([]byte("create_tun"))
	if err != nil {
		return fmt.Errorf("无法发送命令到特权助手工具: %v", err)
	}

	// 设置读取超时
	conn.SetReadDeadline(time.Now().Add(10 * time.Second))

	// 读取响应
	buffer := make([]byte, 1024)
	n, err := conn.Read(buffer)
	if err != nil {
		return fmt.Errorf("无法从特权助手工具读取响应: %v", err)
	}

	response := string(buffer[:n])
	log.Printf("特权助手工具响应: %s", response)

	// 检查响应
	if strings.HasPrefix(response, "error:") {
		return fmt.Errorf("特权助手工具返回错误: %s", response)
	} else if response == "success" {
		log.Printf("特权助手工具确认TUN设备权限可用")
		return nil
	} else {
		return fmt.Errorf("特权助手工具返回未知响应: %s", response)
	}
}

// startOpenVPNWithHelper 使用特权助手工具启动OpenVPN
func (oc *OpenVPNClient) startOpenVPNWithHelper() error {
	// 在macOS上，首先尝试使用特权助手工具
	if runtime.GOOS == "darwin" {
		log.Printf("尝试使用特权助手工具启动OpenVPN")

		// 检查特权助手工具是否可用
		if err := oc.checkTUNPermissionWithHelper(); err != nil {
			log.Printf("特权助手工具不可用，回退到标准方法: %v", err)
		} else {
			log.Printf("特权助手工具可用，继续使用标准OpenVPN启动流程")
			// 如果特权助手工具可用，我们仍然使用标准流程，因为助手工具已经确保了权限
		}
	}

	// 继续标准的OpenVPN启动流程
	return oc.startOpenVPNStandard()
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

	log.Printf("启动OpenVPN客户端: configPath=%s, server=%s, port=%d, protocol=%s", configPath, serverAddr, serverPort, protocol)

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
	configFileName := filepath.Base(configPath)
	tempConfigPath := filepath.Join(tempDir, configFileName)

	// 修改配置文件，添加必要的选项
	if err := oc.modifyConfigFile(configPath, tempConfigPath); err != nil {
		log.Printf("修改配置文件失败，使用原始配置文件: %v", err)
		if err := copyFile(configPath, tempConfigPath); err != nil {
			return fmt.Errorf("复制配置文件失败: %v", err)
		}
	}

	// 解析配置文件并复制所需的证书文件到临时目录
	if err := oc.copyRequiredFiles(configPath, tempDir); err != nil {
		return fmt.Errorf("复制证书文件失败: %v", err)
	}

	// 添加用户名和密码到配置文件
	tempAuthPath := filepath.Join(tempDir, "auth.txt")
	authContent := fmt.Sprintf("%s\n%s\n", username, password)
	if err := os.WriteFile(tempAuthPath, []byte(authContent), 0600); err != nil {
		return fmt.Errorf("创建认证文件失败: %v", err)
	}

	// 构建OpenVPN命令，使用临时目录中的配置文件和认证文件
	var cmd *exec.Cmd
	if runtime.GOOS == "darwin" {
		// 在macOS上，添加一些选项来解决TUN设备权限问题
		// 注意：特权助手工具已经确保了权限，所以这里不需要sudo
		cmd = exec.Command(openvpnPath, "--config", tempConfigPath, "--auth-user-pass", tempAuthPath, "--proto", protocol, "--dev-type", "tun", "--dev", "tun", "--persist-tun", "--pull")
	} else {
		// 在其他平台上直接运行OpenVPN
		cmd = exec.Command(openvpnPath, "--config", tempConfigPath, "--auth-user-pass", tempAuthPath, "--proto", protocol, "--dev-type", "tun", "--dev", "tun", "--pull")
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
	log.Printf("启动OpenVPN进程: %s, protocol=%s, workdir=%s", openvpnPath, protocol, tempDir)
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
