package proxy

import (
	"log"
	"sync"

	"github.com/dualvpn/go-proxy-core/config"
	"github.com/dualvpn/go-proxy-core/dns"
	"github.com/dualvpn/go-proxy-core/openvpn"
	"github.com/dualvpn/go-proxy-core/routing"
)

// ProxyCore 代理核心
type ProxyCore struct {
	config          *config.Config
	rulesEngine     *routing.RulesEngine
	httpServer      *HTTPServer
	socks5Server    *SOCKS5Server
	dnsServer       *dns.DNSServer
	openVPNProxy    *openvpn.OpenVPNProxy
	tunDevice       *TUNDevice
	protocolManager *ProtocolManager

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
	protocolManager := NewProtocolManager()

	// 注册协议工厂
	protocolManager.RegisterFactory(ProtocolHTTP, &HTTPProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolHTTPS, &HTTPProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolDIRECT, &DirectProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolSOCKS5, &HTTPProtocolFactory{}) // SOCKS5可以复用HTTP的连接逻辑
	protocolManager.RegisterFactory(ProtocolOpenVPN, &OpenVPNProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolWireGuard, &WireGuardProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolIPsec, &IPsecProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolL2TP, &L2TPProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolPPTP, &PPTPProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolShadowsocks, &ShadowsocksProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolShadowsocksR, &ShadowsocksRProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolVMess, &VMessProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolTrojan, &TrojanProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolSnell, &SnellProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolIKEv2, &IKEv2ProtocolFactory{})
	protocolManager.RegisterFactory(ProtocolSoftEther, &SoftEtherProtocolFactory{})
	// TODO: 注册其他协议工厂

	// 创建TUN设备（如果需要）
	var tunDevice *TUNDevice
	// TODO: 根据配置决定是否启用TUN模式

	// 添加默认的直连协议
	directConfig := map[string]interface{}{
		"name": "direct",
	}
	protocolManager.CreateProtocol(ProtocolDIRECT, "direct", directConfig)

	// 添加默认的clash协议（用于测试）
	clashHTTPConfig := map[string]interface{}{
		"name":   "clash",
		"server": "127.0.0.1",
		"port":   7890,
	}
	protocolManager.CreateProtocol(ProtocolHTTP, "clash", clashHTTPConfig)

	clashSocksConfig := map[string]interface{}{
		"name":   "clash-socks",
		"server": "127.0.0.1",
		"port":   7891,
	}
	protocolManager.CreateProtocol(ProtocolSOCKS5, "clash-socks", clashSocksConfig)

	return &ProxyCore{
		config:          cfg,
		rulesEngine:     rulesEngine,
		protocolManager: protocolManager,
		tunDevice:       tunDevice,
		// 其他组件将在后续实现
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
	pc.httpServer = NewHTTPServer(pc.config.HTTPPort, pc.rulesEngine, pc.protocolManager)
	go func() {
		if err := pc.httpServer.Start(); err != nil {
			log.Printf("HTTP server error: %v", err)
		}
	}()

	// 启动SOCKS5服务器
	pc.socks5Server = NewSOCKS5Server(pc.config.Socks5Port, pc.rulesEngine, pc.protocolManager)
	go func() {
		if err := pc.socks5Server.Start(); err != nil {
			log.Printf("SOCKS5 server error: %v", err)
		}
	}()

	// 启动TUN设备（如果配置了）
	if pc.tunDevice != nil {
		if err := pc.tunDevice.Start(); err != nil {
			log.Printf("Warning: Failed to start TUN device: %v", err)
		}
	}

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
	if pc.tunDevice != nil {
		pc.tunDevice.Stop()
	}

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

	// 验证规则是否已正确更新
	updatedRules := pc.rulesEngine.GetRules()
	log.Printf("验证更新后规则数量: %d", len(updatedRules))
}

// GetProtocolManager 获取协议管理器
func (pc *ProxyCore) GetProtocolManager() *ProtocolManager {
	return pc.protocolManager
}

// AddProtocol 添加协议
func (pc *ProxyCore) AddProtocol(protocolType ProtocolType, name string, config map[string]interface{}) error {
	_, err := pc.protocolManager.CreateProtocol(protocolType, name, config)
	return err
}
