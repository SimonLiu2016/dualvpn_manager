package core

import (
	"log"
	"sync"

	"github.com/dualvpn/go-proxy-core/config"
	"github.com/dualvpn/go-proxy-core/proxy"
	"github.com/dualvpn/go-proxy-core/routing"
)

// ProxyCore 代理核心
type ProxyCore struct {
	config          *config.Config
	rulesEngine     *routing.RulesEngine
	httpServer      *proxy.HTTPServer
	socks5Server    *proxy.SOCKS5Server
	protocolManager *proxy.ProtocolManager
	// tunDevice    *proxy.TUNDevice

	mu      sync.RWMutex
	running bool
}

// NewProxyCore 创建新的代理核心
func NewProxyCore(cfg *config.Config) *ProxyCore {
	rulesEngine := routing.NewRulesEngine()

	// 设置默认规则
	defaultRules := config.DefaultRules()
	rulesEngine.UpdateRules(defaultRules.Rules)

	// 创建协议管理器
	protocolManager := proxy.NewProtocolManager()

	// 注册协议工厂
	protocolManager.RegisterFactory(proxy.ProtocolHTTP, &proxy.HTTPProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolHTTPS, &proxy.HTTPProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolDIRECT, &proxy.DirectProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolSOCKS5, &proxy.HTTPProtocolFactory{}) // SOCKS5可以复用HTTP的连接逻辑
	protocolManager.RegisterFactory(proxy.ProtocolOpenVPN, &proxy.OpenVPNProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolWireGuard, &proxy.WireGuardProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolIPsec, &proxy.IPsecProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolL2TP, &proxy.L2TPProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolPPTP, &proxy.PPTPProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolShadowsocks, &proxy.ShadowsocksProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolShadowsocksR, &proxy.ShadowsocksRProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolVMess, &proxy.VMessProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolTrojan, &proxy.TrojanProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolSnell, &proxy.SnellProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolIKEv2, &proxy.IKEv2ProtocolFactory{})
	protocolManager.RegisterFactory(proxy.ProtocolSoftEther, &proxy.SoftEtherProtocolFactory{})
	// TODO: 注册其他协议工厂

	// 添加默认的直连协议
	directConfig := map[string]interface{}{
		"name": "direct",
	}
	protocolManager.CreateProtocol(proxy.ProtocolDIRECT, "direct", directConfig)

	// 创建TUN设备（如果需要）
	// var tunDevice *proxy.TUNDevice
	// TODO: 根据配置决定是否启用TUN模式

	return &ProxyCore{
		config:          cfg,
		rulesEngine:     rulesEngine,
		protocolManager: protocolManager,
		// tunDevice:    tunDevice,
	}
}

// Start 启动代理核心
func (pc *ProxyCore) Start() error {
	pc.mu.Lock()
	defer pc.mu.Unlock()

	if pc.running {
		return nil
	}

	log.Printf("Starting proxy core on HTTP:%d, SOCKS5:%d", pc.config.HTTPPort, pc.config.Socks5Port)

	// 启动HTTP服务器
	pc.httpServer = proxy.NewHTTPServer(pc.config.HTTPPort, pc.rulesEngine, pc.protocolManager)
	go func() {
		if err := pc.httpServer.Start(); err != nil {
			log.Printf("HTTP server error: %v", err)
		}
	}()

	// 启动SOCKS5服务器
	pc.socks5Server = proxy.NewSOCKS5Server(pc.config.Socks5Port, pc.rulesEngine, pc.protocolManager)
	go func() {
		if err := pc.socks5Server.Start(); err != nil {
			log.Printf("SOCKS5 server error: %v", err)
		}
	}()

	// 不再在启动时加载规则，规则将通过API动态配置
	log.Printf("Proxy core started with default rules")

	pc.running = true

	return nil
}

// Stop 停止代理核心
func (pc *ProxyCore) Stop() {
	pc.mu.Lock()
	defer pc.mu.Unlock()

	if !pc.running {
		return
	}

	log.Println("Stopping proxy core...")

	// 停止HTTP服务器
	if pc.httpServer != nil {
		pc.httpServer.Stop()
	}

	// 停止SOCKS5服务器
	if pc.socks5Server != nil {
		pc.socks5Server.Stop()
	}

	// 停止TUN设备
	// if pc.tunDevice != nil {
	// 	pc.tunDevice.Stop()
	// }

	pc.running = false
	log.Println("Proxy core stopped")
}

// UpdateRules 更新路由规则
func (pc *ProxyCore) UpdateRules(rules []config.Rule) {
	pc.rulesEngine.UpdateRules(rules)
	log.Printf("Updated %d rules", len(rules))

	// 添加调试日志，打印所有规则
	for i, rule := range rules {
		log.Printf("Rule %d: Type=%s, Pattern=%s, ProxySource=%s, Enabled=%t",
			i, rule.Type, rule.Pattern, rule.ProxySource, rule.Enabled)
	}
}

// GetProtocolManager 获取协议管理器
func (pc *ProxyCore) GetProtocolManager() *proxy.ProtocolManager {
	return pc.protocolManager
}

// GetRulesEngine 获取路由规则引擎
func (pc *ProxyCore) GetRulesEngine() *routing.RulesEngine {
	return pc.rulesEngine
}

// AddProtocol 添加协议
func (pc *ProxyCore) AddProtocol(protocolType proxy.ProtocolType, name string, config map[string]interface{}) error {
	_, err := pc.protocolManager.CreateProtocol(protocolType, name, config)
	return err
}
