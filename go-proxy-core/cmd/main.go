package main

import (
	"io"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/dualvpn/go-proxy-core/api"
	"github.com/dualvpn/go-proxy-core/config"
	"github.com/dualvpn/go-proxy-core/proxy" // 更改导入路径
)

// setupLogging 设置日志输出到文件
func setupLogging() (*os.File, error) {
	// 尝试在 /private/var/tmp 目录创建日志文件
	logDir := "/private/var/tmp"
	if !isWritable(logDir) {
		// 如果 /private/var/tmp 不可写，尝试使用可执行文件所在目录
		execPath, err := os.Executable()
		if err != nil {
			logDir = "."
		} else {
			logDir = filepath.Dir(execPath)
		}
	}

	logFile := filepath.Join(logDir, "go-proxy-core.log")
	file, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return nil, err
	}

	// 创建一个多写入器，同时写入文件和标准错误
	multiWriter := io.MultiWriter(os.Stderr, file)
	log.SetOutput(multiWriter)

	return file, nil
}

// isWritable 检查目录是否可写
func isWritable(path string) bool {
	// 检查目录是否可写
	testFile := filepath.Join(path, ".test")
	if err := os.WriteFile(testFile, []byte(""), 0644); err != nil {
		return false
	}
	os.Remove(testFile)
	return true
}

func main() {
	// 设置日志输出
	logFile, err := setupLogging()
	if err != nil {
		log.Printf("警告: 无法设置日志文件，将使用标准错误输出: %v", err)
		// 即使文件创建失败，仍然可以输出到标准错误
		log.SetOutput(os.Stderr)
	} else {
		defer func() {
			if logFile != nil {
				logFile.Close()
			}
		}()
	}

	log.Println("Starting DualVPN Proxy Core...")

	// 加载配置
	cfg, err := config.LoadConfig("config.yaml")
	if err != nil {
		log.Printf("Warning: Could not load config file: %v, using default config", err)
		cfg = config.DefaultConfig()
	}

	log.Printf("配置加载完成: HTTPPort=%d, Socks5Port=%d, APIPort=%d", cfg.HTTPPort, cfg.Socks5Port, cfg.APIPort)

	// 创建代理核心
	proxyCore := proxy.NewProxyCore(cfg) // 更改类型引用
	log.Println("代理核心创建完成")

	// 启动API服务
	apiServer := api.NewAPIServer(proxyCore, cfg.APIPort)
	go func() {
		log.Printf("启动API服务器在端口 %d", cfg.APIPort)
		if err := apiServer.Start(); err != nil {
			log.Printf("API server error: %v", err)
		} else {
			log.Printf("API服务器启动成功")
		}
	}()

	// 启动代理核心
	log.Printf("启动代理核心...")
	if err := proxyCore.Start(); err != nil {
		log.Fatalf("Failed to start proxy core: %v", err)
	}

	// 添加启动完成的日志
	log.Printf("Proxy core fully started and ready to accept connections")

	// 等待中断信号
	log.Println("等待中断信号...")
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// 等待几秒钟看是否有错误
	time.Sleep(5 * time.Second)
	log.Println("5秒后程序仍在运行...")

	<-sigChan

	log.Println("Shutting down...")

	// 停止代理核心
	proxyCore.Stop()

	log.Println("Proxy core stopped")
}
