package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"

	"github.com/dualvpn/go-proxy-core/config"
	"github.com/dualvpn/go-proxy-core/internal/core"
	"github.com/dualvpn/go-proxy-core/proxy"
)

// APIServer API服务器
type APIServer struct {
	proxyCore *core.ProxyCore
	port      int
	server    *http.Server
}

// NewAPIServer 创建新的API服务器
func NewAPIServer(proxyCore *core.ProxyCore, port int) *APIServer {
	return &APIServer{
		proxyCore: proxyCore,
		port:      port,
	}
}

// Start 启动API服务器
func (as *APIServer) Start() error {
	mux := http.NewServeMux()

	// 注册路由
	mux.HandleFunc("/rules", as.handleRules)
	mux.HandleFunc("/status", as.handleStatus)
	mux.HandleFunc("/protocols", as.handleProtocols)
	mux.HandleFunc("/protocols/", as.handleProtocol)
	mux.HandleFunc("/test-route", as.handleTestRoute) // 添加测试路由端点
	mux.HandleFunc("/stats", as.handleStats)          // 添加统计信息端点

	addr := net.JoinHostPort("127.0.0.1", fmt.Sprintf("%d", as.port))
	as.server = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	log.Printf("API server listening on %s", addr)

	return as.server.ListenAndServe()
}

// handleRules 处理路由规则API
func (as *APIServer) handleRules(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 获取当前规则
		// 修复：实现获取规则逻辑
		rules := as.proxyCore.GetRulesEngine().GetRules()
		w.Header().Set("Content-Type", "application/json")

		// 添加调试日志
		log.Printf("API返回 %d 条路由规则", len(rules))
		for i, rule := range rules {
			log.Printf("返回规则 %d: Type=%s, Pattern=%s, ProxySource=%s, Enabled=%t",
				i, rule.Type, rule.Pattern, rule.ProxySource, rule.Enabled)
		}

		json.NewEncoder(w).Encode(rules)
	case "PUT":
		// 更新规则
		var rules []config.Rule
		if err := json.NewDecoder(r.Body).Decode(&rules); err != nil {
			log.Printf("解析路由规则请求体失败: %v", err)
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// 添加调试日志
		log.Printf("接收到 %d 条路由规则更新请求", len(rules))
		for i, rule := range rules {
			log.Printf("规则 %d: Type=%s, Pattern=%s, ProxySource=%s, Enabled=%t",
				i, rule.Type, rule.Pattern, rule.ProxySource, rule.Enabled)
		}

		as.proxyCore.UpdateRules(rules)

		// 验证规则是否已更新
		updatedRules := as.proxyCore.GetRulesEngine().GetRules()
		log.Printf("更新后规则数量: %d", len(updatedRules))

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Rules updated"))
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleStatus 处理状态API
func (as *APIServer) handleStatus(w http.ResponseWriter, r *http.Request) {
	// TODO: 实现状态查询逻辑
	status := map[string]interface{}{
		"running": true,
		"version": "0.1.0",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

// handleProtocols 处理协议列表API
func (as *APIServer) handleProtocols(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 获取协议列表
		protocolManager := as.proxyCore.GetProtocolManager()
		protocols := protocolManager.GetAllProtocols()

		// 构建响应数据
		response := make(map[string]interface{})
		protocolsData := make(map[string]interface{})

		for name, protocol := range protocols {
			protocolData := map[string]interface{}{
				"name": name,
				"type": string(protocol.Type()),
			}
			protocolsData[name] = protocolData
		}

		response["protocols"] = protocolsData

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	case "POST":
		// 添加新协议
		var requestData map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// 解析协议类型
		protocolType, ok := requestData["type"].(string)
		if !ok {
			http.Error(w, "Missing protocol type", http.StatusBadRequest)
			return
		}

		// 解析协议名称
		protocolName, ok := requestData["name"].(string)
		if !ok {
			http.Error(w, "Missing protocol name", http.StatusBadRequest)
			return
		}

		// 添加协议
		if err := as.proxyCore.AddProtocol(proxy.ProtocolType(protocolType), protocolName, requestData); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusCreated)
		w.Write([]byte("Protocol added"))
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleProtocol 处理单个协议API
func (as *APIServer) handleProtocol(w http.ResponseWriter, r *http.Request) {
	// TODO: 实现单个协议的处理逻辑
	http.Error(w, "Not implemented", http.StatusNotImplemented)
}

// handleTestRoute 处理测试路由匹配API
func (as *APIServer) handleTestRoute(w http.ResponseWriter, r *http.Request) {
	destination := r.URL.Query().Get("destination")
	if destination == "" {
		http.Error(w, "Missing destination parameter", http.StatusBadRequest)
		return
	}

	// 使用路由引擎匹配目标地址
	proxySource := as.proxyCore.GetRulesEngine().Match(destination)

	// 返回匹配结果
	response := map[string]interface{}{
		"destination":  destination,
		"proxy_source": proxySource,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleStats 处理统计信息API
func (as *APIServer) handleStats(w http.ResponseWriter, r *http.Request) {
	stats := as.proxyCore.GetStats()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}
