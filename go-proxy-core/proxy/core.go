package proxy

import (
	"log"
	"sync"
	"time"

	"github.com/dualvpn/go-proxy-core/config"
	"github.com/dualvpn/go-proxy-core/dns"
	"github.com/dualvpn/go-proxy-core/routing"
)

// ProxyCore 代理核心
type ProxyCore struct {
	config       *config.Config
	rulesEngine  *routing.RulesEngine
	httpServer   *HTTPServer
	socks5Server *SOCKS5Server
	dnsServer    *dns.DNSServer
	// openVPNProxy    *openvpn.OpenVPNProxy  // 已移除，使用内部OpenVPN实现
	tunDevice       *TUNDevice
	protocolManager *ProtocolManager

	// 代理源管理
	proxySources   map[string]*ProxySource // key: proxySourceId
	currentProxies map[string]*ProxyInfo   // key: proxySourceId, value: current proxy for that source
	proxySourceMu  sync.RWMutex

	mu      sync.RWMutex
	running bool
}

// ProxySource 代理源信息
type ProxySource struct {
	ID      string                 `json:"id"`
	Name    string                 `json:"name"`
	Type    string                 `json:"type"`    // clash, openvpn, shadowsocks, v2ray 等
	Config  map[string]interface{} `json:"config"`  // 订阅地址或直接配置的代理服务器信息
	Proxies map[string]*ProxyInfo  `json:"proxies"` // 该代理源下的所有代理服务器
}

// ProxyInfo 代理信息
type ProxyInfo struct {
	ID     string                 `json:"id"`
	Name   string                 `json:"name"`
	Type   ProtocolType           `json:"type"`
	Server string                 `json:"server"`
	Port   int                    `json:"port"`
	Config map[string]interface{} `json:"config"` // 认证信息等
	Stats  *ProxyStats            `json:"stats"`
}

// ProxyStats 代理统计信息
type ProxyStats struct {
	Upload   uint64 `json:"upload"`
	Download uint64 `json:"download"`
}

// ProxySourceStats 代理源统计信息
type ProxySourceStats struct {
	Upload   uint64 `json:"upload"`
	Download uint64 `json:"download"`
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
	protocolManager.RegisterFactory(ProtocolVLESS, &VLESSProtocolFactory{}) // 注册VLESS协议工厂
	// TODO: 注册其他协议工厂

	// 添加默认的直连协议
	directConfig := map[string]interface{}{
		"name": "direct",
	}
	protocolManager.CreateProtocol(ProtocolDIRECT, "direct", directConfig)

	// 移除初始化时创建的默认 Clash 协议，这些应该通过 API 动态添加
	/*
		// Clash协议 (HTTP)
		clashHttpConfig := map[string]interface{}{
			"name":   "clash",
			"server": "127.0.0.1",
			"port":   7890,
		}
		protocolManager.CreateProtocol(ProtocolHTTP, "clash", clashHttpConfig)

		// Clash协议 (SOCKS5)
		clashSocksConfig := map[string]interface{}{
			"name":   "clash-socks",
			"server": "127.0.0.1",
			"port":   7891,
		}
		protocolManager.CreateProtocol(ProtocolSOCKS5, "clash-socks", clashSocksConfig)
	*/

	// Shadowsocks协议
	shadowsocksConfig := map[string]interface{}{
		"name":   "shadowsocks",
		"server": "127.0.0.1",
		"port":   1080,
	}
	protocolManager.CreateProtocol(ProtocolShadowsocks, "shadowsocks", shadowsocksConfig)

	// V2Ray协议
	v2rayConfig := map[string]interface{}{
		"name":   "v2ray",
		"server": "127.0.0.1",
		"port":   1080,
	}
	protocolManager.CreateProtocol(ProtocolSOCKS5, "v2ray", v2rayConfig)

	// HTTP代理协议
	httpConfig := map[string]interface{}{
		"name":   "http",
		"server": "127.0.0.1",
		"port":   8080,
	}
	protocolManager.CreateProtocol(ProtocolHTTP, "http", httpConfig)

	// SOCKS5代理协议
	socks5Config := map[string]interface{}{
		"name":   "socks5",
		"server": "127.0.0.1",
		"port":   1080,
	}
	protocolManager.CreateProtocol(ProtocolSOCKS5, "socks5", socks5Config)

	// OpenVPN协议
	// 注释掉默认的OpenVPN协议创建，OpenVPN协议应该通过API动态添加
	/*
		openvpnConfig := map[string]interface{}{
			"name":   "openvpn",
			"server": "127.0.0.1",
			"port":   1194,
		}
		protocolManager.CreateProtocol(ProtocolOpenVPN, "openvpn", openvpnConfig)
	*/

	// 创建TUN设备（如果需要）
	var tunDevice *TUNDevice
	// TODO: 根据配置决定是否启用TUN模式

	// 添加日志以确认协议管理器初始化完成
	log.Printf("协议管理器初始化完成，已注册的协议工厂数量: %d", len(protocolManager.factories))
	log.Printf("协议管理器中已创建的协议数量: %d", len(protocolManager.protocols))
	for name, protocol := range protocolManager.protocols {
		log.Printf("已创建协议: name=%s, type=%s", name, protocol.Type())
	}

	return &ProxyCore{
		config:          cfg,
		rulesEngine:     rulesEngine,
		protocolManager: protocolManager,
		tunDevice:       tunDevice,
		proxySources:    make(map[string]*ProxySource),
		currentProxies:  make(map[string]*ProxyInfo),
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
	log.Printf("配置信息: HTTPPort=%d, Socks5Port=%d, APIPort=%d", pc.config.HTTPPort, pc.config.Socks5Port, pc.config.APIPort)

	// 启动HTTP服务器
	pc.httpServer = NewHTTPServer(pc.config.HTTPPort, pc.rulesEngine, pc.protocolManager, pc) // 传递pc引用
	go func() {
		if err := pc.httpServer.Start(); err != nil {
			log.Printf("HTTP server error: %v", err)
		} else {
			log.Printf("HTTP server started successfully on port %d", pc.config.HTTPPort)
		}
	}()

	// 启动SOCKS5服务器
	pc.socks5Server = NewSOCKS5Server(pc.config.Socks5Port, pc.rulesEngine, pc.protocolManager, pc) // 传递pc引用
	go func() {
		if err := pc.socks5Server.Start(); err != nil {
			log.Printf("SOCKS5 server error: %v", err)
		} else {
			log.Printf("SOCKS5 server started successfully on port %d", pc.config.Socks5Port)
		}
	}()

	// 启动统计信息更新协程
	go pc.updateStats()

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

	// 停止OpenVPN代理（如果正在运行）
	// 注意：现在OpenVPN实现在协议内部处理，不需要在这里单独停止

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

	// 添加更详细的规则验证日志
	for i, rule := range updatedRules {
		log.Printf("验证规则 %d: Type=%s, Pattern=%s, ProxySource=%s, Enabled=%t",
			i, rule.Type, rule.Pattern, rule.ProxySource, rule.Enabled)
	}
}

// GetProtocolManager 获取协议管理器
func (pc *ProxyCore) GetProtocolManager() *ProtocolManager {
	return pc.protocolManager
}

// GetRulesEngine 获取路由规则引擎
func (pc *ProxyCore) GetRulesEngine() *routing.RulesEngine {
	return pc.rulesEngine
}

// AddProxySource 添加代理源
func (pc *ProxyCore) AddProxySource(source *ProxySource) {
	pc.proxySourceMu.Lock()
	defer pc.proxySourceMu.Unlock()
	pc.proxySources[source.ID] = source
}

// RemoveProxySource 移除代理源
func (pc *ProxyCore) RemoveProxySource(sourceId string) {
	pc.proxySourceMu.Lock()
	defer pc.proxySourceMu.Unlock()
	delete(pc.proxySources, sourceId)
	// 同时移除当前代理
	delete(pc.currentProxies, sourceId)
}

// GetProxySource 获取代理源
func (pc *ProxyCore) GetProxySource(sourceId string) *ProxySource {
	pc.proxySourceMu.RLock()
	defer pc.proxySourceMu.RUnlock()
	return pc.proxySources[sourceId]
}

// GetAllProxySources 获取所有代理源
func (pc *ProxyCore) GetAllProxySources() map[string]*ProxySource {
	pc.proxySourceMu.RLock()
	defer pc.proxySourceMu.RUnlock()

	result := make(map[string]*ProxySource)
	for id, source := range pc.proxySources {
		// 创建副本以避免并发访问问题
		proxies := make(map[string]*ProxyInfo)
		for pid, proxy := range source.Proxies {
			proxies[pid] = proxy
		}

		sourceCopy := &ProxySource{
			ID:      source.ID,
			Name:    source.Name,
			Type:    source.Type,
			Config:  source.Config,
			Proxies: proxies,
		}
		result[id] = sourceCopy
	}
	return result
}

// UpdateProxySourceProxies 更新代理源的代理列表
func (pc *ProxyCore) UpdateProxySourceProxies(sourceId string, proxies map[string]*ProxyInfo) {
	pc.proxySourceMu.Lock()
	defer pc.proxySourceMu.Unlock()

	if source, exists := pc.proxySources[sourceId]; exists {
		source.Proxies = proxies
	}
}

// SetCurrentProxy 设置代理源的当前代理
func (pc *ProxyCore) SetCurrentProxy(sourceId string, proxy *ProxyInfo) {
	pc.proxySourceMu.Lock()
	defer pc.proxySourceMu.Unlock()

	// 更新代理源中的代理信息
	if source, exists := pc.proxySources[sourceId]; exists {
		source.Proxies[proxy.ID] = proxy
	}

	// 设置当前代理
	pc.currentProxies[sourceId] = proxy

	// 同时在协议管理器中创建或更新协议实例
	config := make(map[string]interface{})
	for k, v := range proxy.Config {
		config[k] = v
	}
	config["server"] = proxy.Server
	config["port"] = proxy.Port

	// 添加日志以调试协议创建过程
	log.Printf("创建协议: type=%s, name=%s, config=%v", proxy.Type, sourceId, config)

	// 特别处理Shadowsocks协议，确保包含必要的配置
	if proxy.Type == ProtocolShadowsocks {
		log.Printf("特别处理Shadowsocks协议配置")
		if cipher, ok := config["cipher"]; ok {
			config["method"] = cipher
			log.Printf("设置method为cipher值: %v", cipher)
		}
		if password, ok := config["password"]; ok {
			config["password"] = password
			log.Printf("设置password值: %v", password)
		}
		if method, ok := config["method"]; ok {
			config["method"] = method
			log.Printf("设置method值: %v", method)
		}
		log.Printf("Shadowsocks协议配置: %v", config)
	}

	// 使用代理的实际类型创建协议，而不是使用代理源ID作为协议名称
	protocol, err := pc.protocolManager.CreateProtocol(proxy.Type, proxy.ID, config)
	if err != nil {
		log.Printf("创建协议失败: %v", err)
	} else {
		log.Printf("成功创建协议: %s", protocol.Name())
	}

	// 同时确保代理源ID对应的协议也存在，以便路由规则可以正确匹配
	// 使用代理的实际类型创建代理源协议
	sourceProtocol, err := pc.protocolManager.CreateProtocol(proxy.Type, sourceId, config)
	if err != nil {
		log.Printf("创建代理源协议失败: %v", err)
	} else {
		log.Printf("成功创建代理源协议: %s", sourceProtocol.Name())
	}

	// 添加日志以确认当前代理已设置
	log.Printf("代理源 %s 的当前代理已设置为: %+v", sourceId, proxy)

	// 注意：我们不再需要启动外部的OpenVPN代理，因为OpenVPN协议现在完全在内部实现
	// OpenVPN连接将通过OpenVPNProtocol和OpenVPNClient内部处理
}

// GetCurrentProxy 获取代理源的当前代理
func (pc *ProxyCore) GetCurrentProxy(sourceId string) *ProxyInfo {
	pc.proxySourceMu.RLock()
	defer pc.proxySourceMu.RUnlock()
	return pc.currentProxies[sourceId]
}

// GetAllCurrentProxies 获取所有代理源的当前代理
func (pc *ProxyCore) GetAllCurrentProxies() map[string]*ProxyInfo {
	pc.proxySourceMu.RLock()
	defer pc.proxySourceMu.RUnlock()

	result := make(map[string]*ProxyInfo)
	for id, proxy := range pc.currentProxies {
		result[id] = proxy
	}
	return result
}

// updateStats 定期更新代理统计信息
func (pc *ProxyCore) updateStats() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		pc.mu.RLock()
		running := pc.running
		pc.mu.RUnlock()

		if !running {
			break
		}

		select {
		case <-ticker.C:
			// 获取HTTP和SOCKS5服务器的统计数据
			var httpUpload, httpDownload uint64
			var socks5Upload, socks5Download uint64

			if pc.httpServer != nil {
				httpUpload, httpDownload, _ = pc.httpServer.GetStats()
			}

			if pc.socks5Server != nil {
				socks5Upload, socks5Download, _ = pc.socks5Server.GetStats()
			}

			// 不再需要计算总统计数据和平均分配
			// 每个代理源的统计信息已经由ProxySourceStatsCollector独立维护

			// 可以在这里添加其他需要定期更新的统计逻辑
			_ = httpUpload
			_ = httpDownload
			_ = socks5Upload
			_ = socks5Download
		}
	}
}
