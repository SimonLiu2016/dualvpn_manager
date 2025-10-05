//go:build darwin
// +build darwin

package openvpn

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// InstallHelperTool 安装特权助手工具
// 注意：在新的macOS版本中，SMJobBless已被弃用，建议使用SMAppService
// 但为了兼容性，我们仍然提供此实现
func InstallHelperTool(label, bundlePath string) error {
	// 检查助手工具是否存在
	if _, err := os.Stat(bundlePath); os.IsNotExist(err) {
		return fmt.Errorf("助手工具不存在: %s", bundlePath)
	}

	// 在实际实现中，您可能需要使用SMAppService API（macOS 13.0+）
	// 或者继续使用SMJobBless（macOS 13.0之前的版本）
	// 这里我们提供一个简化的实现，仅用于演示

	// 获取当前可执行文件的路径
	execPath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("无法获取可执行文件路径: %v", err)
	}

	// 构建目标路径
	targetDir := filepath.Join(filepath.Dir(execPath), "..", "Helpers")
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("无法创建助手工具目录: %v", err)
	}

	// 复制助手工具到目标位置
	targetPath := filepath.Join(targetDir, filepath.Base(bundlePath))
	cpCmd := exec.Command("cp", "-R", bundlePath, targetPath)
	if err := cpCmd.Run(); err != nil {
		return fmt.Errorf("无法复制助手工具: %v", err)
	}

	// 设置权限
	chmodCmd := exec.Command("chmod", "-R", "755", targetPath)
	if err := chmodCmd.Run(); err != nil {
		return fmt.Errorf("无法设置助手工具权限: %v", err)
	}

	return nil
}
