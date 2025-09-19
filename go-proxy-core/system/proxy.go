package system

import (
	"fmt"
	"log"
	"os/exec"
	"runtime"
)

// SetSystemProxy 设置系统代理
func SetSystemProxy(httpHost string, httpPort int, socksHost string, socksPort int) error {
	switch runtime.GOOS {
	case "windows":
		return setWindowsProxy(httpHost, httpPort, socksHost, socksPort)
	case "darwin": // macOS
		return setMacOSProxy(httpHost, httpPort, socksHost, socksPort)
	case "linux":
		return setLinuxProxy(httpHost, httpPort, socksHost, socksPort)
	default:
		return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
}

// ClearSystemProxy 清除系统代理
func ClearSystemProxy() error {
	switch runtime.GOOS {
	case "windows":
		return clearWindowsProxy()
	case "darwin": // macOS
		return clearMacOSProxy()
	case "linux":
		return clearLinuxProxy()
	default:
		return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
}

// setWindowsProxy 设置Windows系统代理
func setWindowsProxy(httpHost string, httpPort int, socksHost string, socksPort int) error {
	// 设置HTTP代理
	httpCmd := exec.Command("reg", "add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
		"/v", "ProxyServer", "/t", "REG_SZ", "/d", fmt.Sprintf("%s:%d", httpHost, httpPort), "/f")
	if err := httpCmd.Run(); err != nil {
		return fmt.Errorf("failed to set HTTP proxy: %v", err)
	}

	// 启用代理
	enableCmd := exec.Command("reg", "add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
		"/v", "ProxyEnable", "/t", "REG_DWORD", "/d", "1", "/f")
	if err := enableCmd.Run(); err != nil {
		return fmt.Errorf("failed to enable proxy: %v", err)
	}

	log.Println("Windows system proxy set")
	return nil
}

// clearWindowsProxy 清除Windows系统代理
func clearWindowsProxy() error {
	// 禁用代理
	disableCmd := exec.Command("reg", "add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
		"/v", "ProxyEnable", "/t", "REG_DWORD", "/d", "0", "/f")
	if err := disableCmd.Run(); err != nil {
		return fmt.Errorf("failed to disable proxy: %v", err)
	}

	log.Println("Windows system proxy cleared")
	return nil
}

// setMacOSProxy 设置macOS系统代理
func setMacOSProxy(httpHost string, httpPort int, socksHost string, socksPort int) error {
	// 设置HTTP代理
	httpCmd := exec.Command("networksetup", "-setwebproxy", "Wi-Fi", httpHost, fmt.Sprintf("%d", httpPort))
	if err := httpCmd.Run(); err != nil {
		return fmt.Errorf("failed to set HTTP proxy: %v", err)
	}

	// 设置HTTPS代理
	httpsCmd := exec.Command("networksetup", "-setsecurewebproxy", "Wi-Fi", httpHost, fmt.Sprintf("%d", httpPort))
	if err := httpsCmd.Run(); err != nil {
		return fmt.Errorf("failed to set HTTPS proxy: %v", err)
	}

	// 设置SOCKS代理
	socksCmd := exec.Command("networksetup", "-setsocksfirewallproxy", "Wi-Fi", socksHost, fmt.Sprintf("%d", socksPort))
	if err := socksCmd.Run(); err != nil {
		return fmt.Errorf("failed to set SOCKS proxy: %v", err)
	}

	// 启用代理
	enableHttpCmd := exec.Command("networksetup", "-setwebproxystate", "Wi-Fi", "on")
	if err := enableHttpCmd.Run(); err != nil {
		return fmt.Errorf("failed to enable HTTP proxy: %v", err)
	}

	enableHttpsCmd := exec.Command("networksetup", "-setsecurewebproxystate", "Wi-Fi", "on")
	if err := enableHttpsCmd.Run(); err != nil {
		return fmt.Errorf("failed to enable HTTPS proxy: %v", err)
	}

	enableSocksCmd := exec.Command("networksetup", "-setsocksfirewallproxystate", "Wi-Fi", "on")
	if err := enableSocksCmd.Run(); err != nil {
		return fmt.Errorf("failed to enable SOCKS proxy: %v", err)
	}

	log.Println("macOS system proxy set")
	return nil
}

// clearMacOSProxy 清除macOS系统代理
func clearMacOSProxy() error {
	// 禁用代理
	disableHttpCmd := exec.Command("networksetup", "-setwebproxystate", "Wi-Fi", "off")
	if err := disableHttpCmd.Run(); err != nil {
		return fmt.Errorf("failed to disable HTTP proxy: %v", err)
	}

	disableHttpsCmd := exec.Command("networksetup", "-setsecurewebproxystate", "Wi-Fi", "off")
	if err := disableHttpsCmd.Run(); err != nil {
		return fmt.Errorf("failed to disable HTTPS proxy: %v", err)
	}

	disableSocksCmd := exec.Command("networksetup", "-setsocksfirewallproxystate", "Wi-Fi", "off")
	if err := disableSocksCmd.Run(); err != nil {
		return fmt.Errorf("failed to disable SOCKS proxy: %v", err)
	}

	log.Println("macOS system proxy cleared")
	return nil
}

// setLinuxProxy 设置Linux系统代理
func setLinuxProxy(httpHost string, httpPort int, socksHost string, socksPort int) error {
	// 在Linux上，通常通过环境变量设置代理
	// 这里我们只记录日志，实际应用中可能需要修改系统配置文件
	log.Printf("Setting Linux proxy: HTTP=%s:%d, SOCKS=%s:%d", httpHost, httpPort, socksHost, socksPort)
	log.Println("Note: On Linux, you may need to set environment variables manually:")
	log.Printf("export http_proxy=http://%s:%d", httpHost, httpPort)
	log.Printf("export https_proxy=http://%s:%d", httpHost, httpPort)
	log.Printf("export socks_proxy=socks5://%s:%d", socksHost, socksPort)

	return nil
}

// clearLinuxProxy 清除Linux系统代理
func clearLinuxProxy() error {
	// 在Linux上，通常通过环境变量设置代理
	// 这里我们只记录日志，实际应用中可能需要修改系统配置文件
	log.Println("Clearing Linux proxy")
	log.Println("Note: On Linux, you may need to unset environment variables manually:")
	log.Println("unset http_proxy https_proxy socks_proxy")

	return nil
}
