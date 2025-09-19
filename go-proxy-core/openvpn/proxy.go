package openvpn

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"runtime"
)

// OpenVPNProxy OpenVPN代理
type OpenVPNProxy struct {
	configPath  string
	openVPNPort int
	cmd         *exec.Cmd
	running     bool
}

// NewOpenVPNProxy 创建新的OpenVPN代理
func NewOpenVPNProxy(configPath string, openVPNPort int) *OpenVPNProxy {
	return &OpenVPNProxy{
		configPath:  configPath,
		openVPNPort: openVPNPort,
	}
}

// Start 启动OpenVPN代理
func (op *OpenVPNProxy) Start() error {
	if op.running {
		return nil
	}

	// 确定OpenVPN二进制文件名
	openvpnBinary := "openvpn"
	if runtime.GOOS == "windows" {
		openvpnBinary = "openvpn.exe"
	}

	// 构建命令参数
	args := []string{
		"--config", op.configPath,
		"--socks-proxy", fmt.Sprintf("127.0.0.1:%d", op.openVPNPort),
		"--daemon",
	}

	// 启动OpenVPN进程
	cmd := exec.Command(openvpnBinary, args...)
	op.cmd = cmd

	// 启动进程
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start openvpn: %v", err)
	}

	op.running = true
	log.Printf("OpenVPN proxy started with config: %s", op.configPath)

	return nil
}

// Stop 停止OpenVPN代理
func (op *OpenVPNProxy) Stop() error {
	if !op.running || op.cmd == nil {
		return nil
	}

	// 优雅地停止进程
	if err := op.cmd.Process.Signal(os.Interrupt); err != nil {
		log.Printf("Failed to send interrupt signal to openvpn: %v", err)
		// 强制杀死进程
		if err := op.cmd.Process.Kill(); err != nil {
			return fmt.Errorf("failed to kill openvpn process: %v", err)
		}
	}

	// 等待进程退出
	if _, err := op.cmd.Process.Wait(); err != nil {
		log.Printf("Error waiting for openvpn process to exit: %v", err)
	}

	op.running = false
	log.Println("OpenVPN proxy stopped")

	return nil
}

// IsRunning 检查OpenVPN是否正在运行
func (op *OpenVPNProxy) IsRunning() bool {
	return op.running
}

// GetProxyPort 获取OpenVPN代理端口
func (op *OpenVPNProxy) GetProxyPort() int {
	return op.openVPNPort
}
