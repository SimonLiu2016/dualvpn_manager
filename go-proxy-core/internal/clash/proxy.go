package clash

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"os"

	"gopkg.in/yaml.v3"
)

// ProxyConfig 代理配置
type ProxyConfig struct {
	Name   string `yaml:"name" json:"name"`
	Type   string `yaml:"type" json:"type"`
	Server string `yaml:"server" json:"server"`
	Port   int    `yaml:"port" json:"port"`
}

// ProxyGroupConfig 代理组配置
type ProxyGroupConfig struct {
	Name     string   `yaml:"name" json:"name"`
	Type     string   `yaml:"type" json:"type"`
	Proxies  []string `yaml:"proxies" json:"proxies"`
	URL      string   `yaml:"url,omitempty" json:"url,omitempty"`
	Interval int      `yaml:"interval,omitempty" json:"interval,omitempty"`
}

// RuleConfig 路由规则配置
type RuleConfig struct {
	Type    string `yaml:"type" json:"type"`
	Pattern string `yaml:"pattern" json:"pattern"`
	Target  string `yaml:"target" json:"target"`
}

// ClashConfig Clash配置
type ClashConfig struct {
	Port        int                `yaml:"port" json:"port"`
	SocksPort   int                `yaml:"socks-port" json:"socks-port"`
	AllowLAN    bool               `yaml:"allow-lan" json:"allow-lan"`
	Mode        string             `yaml:"mode" json:"mode"`
	LogLevel    string             `yaml:"log-level" json:"log-level"`
	APIPort     int                `yaml:"external-controller" json:"external-controller"`
	Proxies     []ProxyConfig      `yaml:"proxies" json:"proxies"`
	ProxyGroups []ProxyGroupConfig `yaml:"proxy-groups" json:"proxy-groups"`
	Rules       []RuleConfig       `yaml:"rules" json:"rules"`
	TUN         TUNConfig          `yaml:"tun,omitempty" json:"tun,omitempty"`
}

// TUNConfig TUN配置
type TUNConfig struct {
	Enable              bool     `yaml:"enable" json:"enable"`
	Stack               string   `yaml:"stack" json:"stack"`
	DNSHijack           []string `yaml:"dns-hijack" json:"dns-hijack"`
	AutoRoute           bool     `yaml:"auto-route" json:"auto-route"`
	AutoDetectInterface bool     `yaml:"auto-detect-interface" json:"auto-detect-interface"`
}

// LoadConfig 从文件加载配置
func LoadConfig(filename string) (*ClashConfig, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var config ClashConfig
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	// 设置默认值
	if config.Port == 0 {
		config.Port = 7890
	}
	if config.SocksPort == 0 {
		config.SocksPort = 7891
	}
	if config.Mode == "" {
		config.Mode = "Rule"
	}
	if config.LogLevel == "" {
		config.LogLevel = "info"
	}

	// 解析API端口
	if config.APIPort == 0 {
		config.APIPort = 9090
	}

	return &config, nil
}

// RuleType 规则类型
type RuleType string

const (
	RuleTypeDomain       RuleType = "DOMAIN"
	RuleTypeDomainSuffix RuleType = "DOMAIN-SUFFIX"
	RuleTypeIPCIDR       RuleType = "IP-CIDR"
	RuleTypeMatch        RuleType = "MATCH"
)

// Rule 路由规则
type Rule struct {
	Type    RuleType `json:"type"`
	Pattern string   `json:"pattern"`
	Target  string   `json:"target"`
}

// RulesEngine 路由规则引擎
type RulesEngine struct {
	rules []Rule
	mu    sync.RWMutex
}

// NewRulesEngine 创建新的路由规则引擎
func NewRulesEngine() *RulesEngine {
	return &RulesEngine{
		rules: make([]Rule, 0),
	}
}

// UpdateRules 更新路由规则
func (re *RulesEngine) UpdateRules(ruleConfigs []RuleConfig) {
	re.mu.Lock()
	defer re.mu.Unlock()

	rules := make([]Rule, len(ruleConfigs))
	for i, config := range ruleConfigs {
		rules[i] = Rule{
			Type:    RuleType(config.Type),
			Pattern: config.Pattern,
			Target:  config.Target,
		}
	}

	re.rules = rules
	log.Printf("Updated %d rules", len(rules))
}

// Match 匹配路由规则
func (re *RulesEngine) Match(destination string) string {
	re.mu.RLock()
	defer re.mu.RUnlock()

	for _, rule := range re.rules {
		switch rule.Type {
		case RuleTypeDomain:
			if destination == rule.Pattern {
				return rule.Target
			}
		case RuleTypeDomainSuffix:
			if strings.HasSuffix(destination, rule.Pattern) {
				return rule.Target
			}
		case RuleTypeIPCIDR:
			if re.matchCIDR(destination, rule.Pattern) {
				return rule.Target
			}
		case RuleTypeMatch:
			// MATCH规则匹配所有流量
			return rule.Target
		}
	}

	// 默认返回DIRECT
	return "DIRECT"
}

// matchCIDR 匹配CIDR IP段
func (re *RulesEngine) matchCIDR(destination, pattern string) bool {
	// 解析目标地址
	host, _, err := net.SplitHostPort(destination)
	if err != nil {
		host = destination
	}

	// 解析CIDR
	_, ipnet, err := net.ParseCIDR(pattern)
	if err != nil {
		log.Printf("Invalid CIDR pattern: %s", pattern)
		return false
	}

	// 解析目标IP
	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}

	return ipnet.Contains(ip)
}

// GetRules 获取当前规则
func (re *RulesEngine) GetRules() []Rule {
	re.mu.RLock()
	defer re.mu.RUnlock()

	rules := make([]Rule, len(re.rules))
	copy(rules, re.rules)
	return rules
}

// getStringValue 从map中获取字符串值
func getStringValue(m map[string]interface{}, key string) string {
	if val, ok := m[key].(string); ok {
		return val
	}
	return ""
}

// APIServer API服务器
type APIServer struct {
	port         int
	proxyManager *ProxyManager
	rulesEngine  *RulesEngine
	server       *http.Server
	mu           sync.RWMutex
	running      bool
}

// NewAPIServer 创建新的API服务器
func NewAPIServer(port int, proxyManager *ProxyManager, rulesEngine *RulesEngine) *APIServer {
	return &APIServer{
		port:         port,
		proxyManager: proxyManager,
		rulesEngine:  rulesEngine,
	}
}

// Start 启动API服务器
func (as *APIServer) Start() error {
	as.mu.Lock()
	defer as.mu.Unlock()

	if as.running {
		return nil
	}

	mux := http.NewServeMux()

	// 注册路由
	mux.HandleFunc("/proxies", as.handleProxies)
	mux.HandleFunc("/proxies/", as.handleProxy)
	mux.HandleFunc("/rules", as.handleRules)
	mux.HandleFunc("/traffic", as.handleTraffic)
	mux.HandleFunc("/configs", as.handleConfigs)
	mux.HandleFunc("/configs/", as.handleConfigs)

	addr := net.JoinHostPort("127.0.0.1", fmt.Sprintf("%d", as.port))
	as.server = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	as.running = true
	log.Printf("Clash API server listening on %s", addr)

	return as.server.ListenAndServe()
}

// Stop 停止API服务器
func (as *APIServer) Stop() {
	as.mu.Lock()
	defer as.mu.Unlock()

	if !as.running || as.server == nil {
		return
	}

	if err := as.server.Close(); err != nil {
		log.Printf("Error closing API server: %v", err)
	}

	as.running = false
	log.Println("Clash API server stopped")
}

// handleProxies 处理代理列表API
func (as *APIServer) handleProxies(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 获取代理列表
		proxies := as.proxyManager.GetProxies()
		proxyGroups := as.proxyManager.GetProxyGroups()

		// 构建响应数据
		response := make(map[string]interface{})
		proxiesData := make(map[string]interface{})

		// 添加独立代理
		for name, proxy := range proxies {
			proxyData := map[string]interface{}{
				"name":    proxy.Name(),
				"type":    string(proxy.Type()),
				"address": proxy.Address(),
			}
			proxiesData[name] = proxyData
		}

		// 添加代理组
		for name, group := range proxyGroups {
			groupData := map[string]interface{}{
				"name":    group.Name(),
				"type":    group.Type(),
				"proxies": group.GetProxies(),
			}
			proxiesData[name] = groupData
		}

		response["proxies"] = proxiesData

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleProxy 处理单个代理API
func (as *APIServer) handleProxy(w http.ResponseWriter, r *http.Request) {
	// 解析代理名称
	path := strings.TrimPrefix(r.URL.Path, "/proxies/")
	parts := strings.Split(path, "/")
	if len(parts) == 0 {
		http.Error(w, "Invalid proxy name", http.StatusBadRequest)
		return
	}

	proxyName := parts[0]

	switch r.Method {
	case "GET":
		// 获取代理信息
		proxy := as.proxyManager.GetProxy(proxyName)
		if proxy == nil {
			// 检查是否是代理组
			group := as.proxyManager.GetProxyGroup(proxyName)
			if group == nil {
				http.Error(w, "Proxy not found", http.StatusNotFound)
				return
			}

			groupData := map[string]interface{}{
				"name":    group.Name(),
				"type":    group.Type(),
				"proxies": group.GetProxies(),
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(groupData)
			return
		}

		proxyData := map[string]interface{}{
			"name":    proxy.Name(),
			"type":    string(proxy.Type()),
			"address": proxy.Address(),
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(proxyData)
	case "PUT":
		// 选择代理（用于代理组）
		var requestData map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// 检查是否是代理组
		group := as.proxyManager.GetProxyGroup(proxyName)
		if group == nil {
			http.Error(w, "Proxy group not found", http.StatusNotFound)
			return
		}

		// 获取要选择的代理名称
		proxyName, ok := requestData["name"].(string)
		if !ok {
			http.Error(w, "Invalid proxy name", http.StatusBadRequest)
			return
		}

		// 检查代理是否存在
		proxy := as.proxyManager.GetProxy(proxyName)
		if proxy == nil {
			http.Error(w, "Proxy not found", http.StatusNotFound)
			return
		}

		// 这里应该实现代理选择逻辑
		// 简化实现，只记录日志
		log.Printf("Selected proxy %s for group %s", proxyName, proxyName)

		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleRules 处理路由规则API
func (as *APIServer) handleRules(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 获取当前规则
		rules := as.rulesEngine.GetRules()
		response := map[string]interface{}{
			"rules": rules,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	case "PUT":
		// 更新规则
		var requestData map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// 解析规则数据
		rulesData, ok := requestData["rules"].([]interface{})
		if !ok {
			http.Error(w, "Invalid rules data", http.StatusBadRequest)
			return
		}

		// 转换规则数据
		ruleConfigs := make([]RuleConfig, len(rulesData))
		for i, ruleData := range rulesData {
			ruleMap, ok := ruleData.(map[string]interface{})
			if !ok {
				http.Error(w, "Invalid rule data", http.StatusBadRequest)
				return
			}

			ruleConfigs[i] = RuleConfig{
				Type:    getStringValue(ruleMap, "type"),
				Pattern: getStringValue(ruleMap, "pattern"),
				Target:  getStringValue(ruleMap, "target"),
			}
		}

		// 更新规则
		as.rulesEngine.UpdateRules(ruleConfigs)

		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleTraffic 处理流量统计API
func (as *APIServer) handleTraffic(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 返回流量统计信息
		trafficData := map[string]interface{}{
			"up":   0,
			"down": 0,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(trafficData)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleConfigs 处理配置API
func (as *APIServer) handleConfigs(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 返回配置信息
		configData := map[string]interface{}{
			"port":       7890,
			"socks-port": 7891,
			"mode":       "Rule",
			"log-level":  "info",
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(configData)
	case "PATCH":
		// 更新配置
		var requestData map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// 处理配置更新
		if mode, ok := requestData["mode"].(string); ok {
			log.Printf("Config mode updated to: %s", mode)
		}

		w.WriteHeader(http.StatusNoContent)
	case "PUT":
		// 重新加载配置
		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// Server Clash服务器
type Server struct {
	config       *ClashConfig
	proxyManager *ProxyManager
	rulesEngine  *RulesEngine
	apiServer    *APIServer
	running      bool
	mu           sync.Mutex
}

// NewServer 创建新的Clash服务器
func NewServer(configPath string) (*Server, error) {
	// 加载配置
	clashConfig, err := LoadConfig(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to load clash config: %v", err)
	}

	// 创建代理管理器
	proxyManager := NewProxyManager()

	// 创建路由规则引擎
	rulesEngine := NewRulesEngine()

	// 创建API服务器
	apiServer := NewAPIServer(clashConfig.APIPort, proxyManager, rulesEngine)

	return &Server{
		config:       clashConfig,
		proxyManager: proxyManager,
		rulesEngine:  rulesEngine,
		apiServer:    apiServer,
	}, nil
}

// Start 启动Clash服务器
func (s *Server) Start() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.running {
		return nil
	}

	log.Println("Starting Clash server...")

	// 启动API服务器
	go func() {
		if err := s.apiServer.Start(); err != nil {
			log.Printf("Clash API server error: %v", err)
		}
	}()

	// 启动代理管理器
	if err := s.proxyManager.Start(); err != nil {
		return fmt.Errorf("failed to start proxy manager: %v", err)
	}

	// 应用配置中的代理
	for _, proxyConfig := range s.config.Proxies {
		proxy, err := NewProxyFromConfig(proxyConfig)
		if err != nil {
			log.Printf("Warning: failed to create proxy from config: %v", err)
			continue
		}
		s.proxyManager.AddProxy(proxy)
	}

	// 应用配置中的代理组
	for _, groupConfig := range s.config.ProxyGroups {
		group := NewProxyGroupFromConfig(groupConfig)
		s.proxyManager.AddProxyGroup(group)
	}

	// 应用配置中的路由规则
	s.rulesEngine.UpdateRules(s.config.Rules)

	s.running = true
	log.Println("Clash server started")

	return nil
}

// Stop 停止Clash服务器
func (s *Server) Stop() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if !s.running {
		return nil
	}

	log.Println("Stopping Clash server...")

	// 停止代理管理器
	s.proxyManager.Stop()

	// 停止API服务器
	s.apiServer.Stop()

	s.running = false
	log.Println("Clash server stopped")

	return nil
}

// IsRunning 检查Clash服务器是否正在运行
func (s *Server) IsRunning() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.running
}

// GetProxies 获取代理列表
func (s *Server) GetProxies() (map[string]interface{}, error) {
	// 这里应该通过API获取代理列表
	// 简化实现，返回空map
	return make(map[string]interface{}), nil
}

// ClashProxy Clash代理（使用新的核心实现）
type ClashProxy struct {
	configPath   string
	clashPort    int
	clashAPIPort int
	server       *Server
	running      bool
	mu           sync.Mutex
}

// NewClashProxy 创建新的Clash代理
func NewClashProxy(configPath string, clashPort, clashAPIPort int) *ClashProxy {
	return &ClashProxy{
		configPath:   configPath,
		clashPort:    clashPort,
		clashAPIPort: clashAPIPort,
	}
}

// Start 启动Clash代理
func (cp *ClashProxy) Start() error {
	cp.mu.Lock()
	defer cp.mu.Unlock()

	if cp.running {
		return nil
	}

	log.Println("Starting Clash proxy with embedded server...")

	// 创建Clash服务器
	server, err := NewServer(cp.configPath)
	if err != nil {
		return fmt.Errorf("failed to create clash server: %v", err)
	}

	// 启动服务器
	if err := server.Start(); err != nil {
		return fmt.Errorf("failed to start clash server: %v", err)
	}

	cp.server = server
	cp.running = true
	log.Printf("Clash proxy started with config: %s", cp.configPath)

	return nil
}

// Stop 停止Clash代理
func (cp *ClashProxy) Stop() error {
	cp.mu.Lock()
	defer cp.mu.Unlock()

	if !cp.running || cp.server == nil {
		return nil
	}

	// 停止服务器
	if err := cp.server.Stop(); err != nil {
		return fmt.Errorf("failed to stop clash server: %v", err)
	}

	cp.running = false
	log.Println("Clash proxy stopped")

	return nil
}

// IsRunning 检查Clash是否正在运行
func (cp *ClashProxy) IsRunning() bool {
	cp.mu.Lock()
	defer cp.mu.Unlock()
	return cp.running
}

// GetProxyPort 获取Clash代理端口
func (cp *ClashProxy) GetProxyPort() int {
	return cp.clashPort
}

// GetProxies 获取代理列表
func (cp *ClashProxy) GetProxies() (map[string]interface{}, error) {
	if cp.server != nil {
		return cp.server.GetProxies()
	}
	// 返回空map
	return make(map[string]interface{}), nil
}

// ProxyType 代理类型
type ProxyType string

const (
	ProxyTypeHTTP   ProxyType = "http"
	ProxyTypeHTTPS  ProxyType = "https"
	ProxyTypeSOCKS5 ProxyType = "socks5"
)

// Proxy 代理接口
type Proxy interface {
	Name() string
	Type() ProxyType
	Address() string
	Connect(addr string) (net.Conn, error)
	Close() error
}

// BaseProxy 基础代理结构
type BaseProxy struct {
	name      string
	proxyType ProxyType
	server    string
	port      int
}

// Name 获取代理名称
func (bp *BaseProxy) Name() string {
	return bp.name
}

// Type 获取代理类型
func (bp *BaseProxy) Type() ProxyType {
	return bp.proxyType
}

// Address 获取代理地址
func (bp *BaseProxy) Address() string {
	return fmt.Sprintf("%s:%d", bp.server, bp.port)
}

// Connect 连接到目标地址
func (bp *BaseProxy) Connect(addr string) (net.Conn, error) {
	// 这里应该根据代理类型实现不同的连接逻辑
	// 简化实现，直接连接到代理服务器
	conn, err := net.DialTimeout("tcp", bp.Address(), 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to proxy %s: %v", bp.Address(), err)
	}
	return conn, nil
}

// Close 关闭代理连接
func (bp *BaseProxy) Close() error {
	// 基础代理不需要特殊关闭逻辑
	return nil
}

// NewProxyFromConfig 从配置创建代理
func NewProxyFromConfig(config ProxyConfig) (Proxy, error) {
	proxyType := ProxyType(config.Type)

	// 验证代理类型
	switch proxyType {
	case ProxyTypeHTTP, ProxyTypeHTTPS, ProxyTypeSOCKS5:
		// 支持的类型
	default:
		return nil, fmt.Errorf("unsupported proxy type: %s", config.Type)
	}

	proxy := &BaseProxy{
		name:      config.Name,
		proxyType: proxyType,
		server:    config.Server,
		port:      config.Port,
	}

	return proxy, nil
}

// ProxyGroup 代理组
type ProxyGroup struct {
	name      string
	groupType string
	proxies   []Proxy
	current   int
	mu        sync.RWMutex
}

// NewProxyGroupFromConfig 从配置创建代理组
func NewProxyGroupFromConfig(config ProxyGroupConfig) *ProxyGroup {
	return &ProxyGroup{
		name:      config.Name,
		groupType: config.Type,
		proxies:   make([]Proxy, 0),
		current:   0,
	}
}

// Name 获取代理组名称
func (pg *ProxyGroup) Name() string {
	return pg.name
}

// Type 获取代理组类型
func (pg *ProxyGroup) Type() string {
	return pg.groupType
}

// AddProxy 添加代理到组
func (pg *ProxyGroup) AddProxy(proxy Proxy) {
	pg.mu.Lock()
	defer pg.mu.Unlock()
	pg.proxies = append(pg.proxies, proxy)
}

// SelectProxy 选择代理（轮询方式）
func (pg *ProxyGroup) SelectProxy() Proxy {
	pg.mu.Lock()
	defer pg.mu.Unlock()

	if len(pg.proxies) == 0 {
		return nil
	}

	proxy := pg.proxies[pg.current]
	pg.current = (pg.current + 1) % len(pg.proxies)
	return proxy
}

// GetProxies 获取所有代理
func (pg *ProxyGroup) GetProxies() []Proxy {
	pg.mu.RLock()
	defer pg.mu.RUnlock()

	proxies := make([]Proxy, len(pg.proxies))
	copy(proxies, pg.proxies)
	return proxies
}

// ProxyManager 代理管理器
type ProxyManager struct {
	proxies     map[string]Proxy
	proxyGroups map[string]*ProxyGroup
	mu          sync.RWMutex
	running     bool
}

// NewProxyManager 创建新的代理管理器
func NewProxyManager() *ProxyManager {
	return &ProxyManager{
		proxies:     make(map[string]Proxy),
		proxyGroups: make(map[string]*ProxyGroup),
	}
}

// Start 启动代理管理器
func (pm *ProxyManager) Start() error {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	if pm.running {
		return nil
	}

	pm.running = true
	log.Println("Proxy manager started")
	return nil
}

// Stop 停止代理管理器
func (pm *ProxyManager) Stop() {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	if !pm.running {
		return
	}

	// 关闭所有代理
	for _, proxy := range pm.proxies {
		if err := proxy.Close(); err != nil {
			log.Printf("Error closing proxy %s: %v", proxy.Name(), err)
		}
	}

	pm.running = false
	log.Println("Proxy manager stopped")
}

// AddProxy 添加代理
func (pm *ProxyManager) AddProxy(proxy Proxy) {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	pm.proxies[proxy.Name()] = proxy
	log.Printf("Added proxy: %s (%s)", proxy.Name(), proxy.Type())
}

// GetProxy 获取代理
func (pm *ProxyManager) GetProxy(name string) Proxy {
	pm.mu.RLock()
	defer pm.mu.RUnlock()
	return pm.proxies[name]
}

// RemoveProxy 移除代理
func (pm *ProxyManager) RemoveProxy(name string) {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	delete(pm.proxies, name)
	log.Printf("Removed proxy: %s", name)
}

// AddProxyGroup 添加代理组
func (pm *ProxyManager) AddProxyGroup(group *ProxyGroup) {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	pm.proxyGroups[group.Name()] = group
	log.Printf("Added proxy group: %s (%s)", group.Name(), group.Type())
}

// GetProxyGroup 获取代理组
func (pm *ProxyManager) GetProxyGroup(name string) *ProxyGroup {
	pm.mu.RLock()
	defer pm.mu.RUnlock()
	return pm.proxyGroups[name]
}

// GetProxies 获取所有代理
func (pm *ProxyManager) GetProxies() map[string]Proxy {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	result := make(map[string]Proxy)
	for name, proxy := range pm.proxies {
		result[name] = proxy
	}
	return result
}

// GetProxyGroups 获取所有代理组
func (pm *ProxyManager) GetProxyGroups() map[string]*ProxyGroup {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	result := make(map[string]*ProxyGroup)
	for name, group := range pm.proxyGroups {
		result[name] = group
	}
	return result
}
