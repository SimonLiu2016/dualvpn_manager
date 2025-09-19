package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/dualvpn/go-proxy-core/api"
	"github.com/dualvpn/go-proxy-core/config"
	"github.com/dualvpn/go-proxy-core/internal/core"
)

func main() {
	log.Println("Starting DualVPN Proxy Core...")

	// 加载配置
	cfg, err := config.LoadConfig("config.yaml")
	if err != nil {
		log.Printf("Warning: Could not load config file: %v, using default config", err)
		cfg = config.DefaultConfig()
	}

	// 创建代理核心
	proxyCore := core.NewProxyCore(cfg)

	// 启动API服务
	apiServer := api.NewAPIServer(proxyCore, cfg.APIPort)
	go func() {
		if err := apiServer.Start(); err != nil {
			log.Printf("API server error: %v", err)
		}
	}()

	// 启动代理核心
	if err := proxyCore.Start(); err != nil {
		log.Fatalf("Failed to start proxy core: %v", err)
	}

	// 等待中断信号
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down...")

	// 停止代理核心
	proxyCore.Stop()

	log.Println("Proxy core stopped")
}
