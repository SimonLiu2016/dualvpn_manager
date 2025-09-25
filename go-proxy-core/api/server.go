package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"strings"

	"github.com/dualvpn/go-proxy-core/config"
	"github.com/dualvpn/go-proxy-core/proxy"
)

// APIServer API服务器
type APIServer struct {
	proxyCore *proxy.ProxyCore
	port      int
	server    *http.Server
}

// NewAPIServer 创建新的API服务器
func NewAPIServer(proxyCore *proxy.ProxyCore, port int) *APIServer {
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
	mux.HandleFunc("/proxy-sources", as.handleProxySources)
	mux.HandleFunc("/proxy-sources/", as.handleProxySource)
	mux.HandleFunc("/stats", as.handleStats)
	mux.HandleFunc("/protocols", as.handleProtocols)

	addr := net.JoinHostPort("127.0.0.1", fmt.Sprintf("%d", as.port))
	as.server = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	log.Printf("API server listening on %s", addr)
	log.Printf("API服务器配置: port=%d", as.port)

	return as.server.ListenAndServe()
}

// handleRules 处理路由规则API
func (as *APIServer) handleRules(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 获取当前规则
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

// handleProxySources 处理代理源API
func (as *APIServer) handleProxySources(w http.ResponseWriter, r *http.Request) {
	// 确保路径是 /proxy-sources
	if r.URL.Path != "/proxy-sources" {
		http.Error(w, "Not found", http.StatusNotFound)
		return
	}

	switch r.Method {
	case "GET":
		// 获取所有代理源
		proxySources := as.proxyCore.GetAllProxySources()

		// 构建响应数据
		response := make(map[string]interface{})
		sourcesData := make(map[string]interface{})

		for id, source := range proxySources {
			// 构建代理列表数据
			proxiesData := make(map[string]interface{})
			for pid, proxyInfo := range source.Proxies {
				proxyData := map[string]interface{}{
					"id":     proxyInfo.ID,
					"name":   proxyInfo.Name,
					"type":   string(proxyInfo.Type),
					"server": proxyInfo.Server,
					"port":   proxyInfo.Port,
					"config": proxyInfo.Config,
				}
				proxiesData[pid] = proxyData
			}

			sourceData := map[string]interface{}{
				"id":      source.ID,
				"name":    source.Name,
				"type":    source.Type,
				"config":  source.Config,
				"proxies": proxiesData,
			}
			sourcesData[id] = sourceData
		}

		response["proxy_sources"] = sourcesData

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	case "POST":
		// 添加新的代理源
		var requestData map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// 解析代理源信息
		sourceId, ok := requestData["id"].(string)
		if !ok {
			http.Error(w, "Missing source id", http.StatusBadRequest)
			return
		}

		sourceName, ok := requestData["name"].(string)
		if !ok {
			http.Error(w, "Missing source name", http.StatusBadRequest)
			return
		}

		sourceType, ok := requestData["type"].(string)
		if !ok {
			http.Error(w, "Missing source type", http.StatusBadRequest)
			return
		}

		sourceConfig, ok := requestData["config"].(map[string]interface{})
		if !ok {
			http.Error(w, "Missing source config", http.StatusBadRequest)
			return
		}

		// 创建代理源
		source := &proxy.ProxySource{
			ID:      sourceId,
			Name:    sourceName,
			Type:    sourceType,
			Config:  sourceConfig,
			Proxies: make(map[string]*proxy.ProxyInfo),
		}

		// 添加代理源
		as.proxyCore.AddProxySource(source)

		w.WriteHeader(http.StatusCreated)
		w.Write([]byte("Proxy source added"))
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleProxySource 处理单个代理源API
func (as *APIServer) handleProxySource(w http.ResponseWriter, r *http.Request) {
	// 解析代理源ID
	path := strings.TrimPrefix(r.URL.Path, "/proxy-sources/")
	parts := strings.Split(path, "/")
	if len(parts) == 0 || parts[0] == "" {
		http.Error(w, "Invalid proxy source id", http.StatusBadRequest)
		return
	}

	sourceId := parts[0]
	log.Printf("处理代理源API请求: sourceId=%s, path=%s", sourceId, r.URL.Path)

	// 获取代理源
	source := as.proxyCore.GetProxySource(sourceId)
	if source == nil {
		log.Printf("代理源未找到: %s", sourceId)
		http.Error(w, "Proxy source not found", http.StatusNotFound)
		return
	}

	// 如果路径是 /proxy-sources/{id}
	if len(parts) == 1 {
		switch r.Method {
		case "GET":
			// 获取代理源信息
			// 构建代理列表数据
			proxiesData := make(map[string]interface{})
			for pid, proxyInfo := range source.Proxies {
				proxyData := map[string]interface{}{
					"id":     proxyInfo.ID,
					"name":   proxyInfo.Name,
					"type":   string(proxyInfo.Type),
					"server": proxyInfo.Server,
					"port":   proxyInfo.Port,
					"config": proxyInfo.Config,
				}
				proxiesData[pid] = proxyData
			}

			sourceData := map[string]interface{}{
				"id":      source.ID,
				"name":    source.Name,
				"type":    source.Type,
				"config":  source.Config,
				"proxies": proxiesData,
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(sourceData)
		case "DELETE":
			// 删除代理源
			as.proxyCore.RemoveProxySource(sourceId)
			w.WriteHeader(http.StatusNoContent)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
		return
	}

	// 如果路径是 /proxy-sources/{id}/proxies
	if len(parts) == 2 && parts[1] == "proxies" {
		switch r.Method {
		case "GET":
			// 获取代理源的所有代理
			proxiesData := make(map[string]interface{})
			for pid, proxyInfo := range source.Proxies {
				proxyData := map[string]interface{}{
					"id":     proxyInfo.ID,
					"name":   proxyInfo.Name,
					"type":   string(proxyInfo.Type),
					"server": proxyInfo.Server,
					"port":   proxyInfo.Port,
					"config": proxyInfo.Config,
				}
				proxiesData[pid] = proxyData
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(proxiesData)
		case "PUT":
			// 更新代理源的所有代理
			var requestData []map[string]interface{}
			if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
				log.Printf("解析代理列表请求体失败: %v", err)
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}

			// 转换代理数据
			proxies := make(map[string]*proxy.ProxyInfo)
			for _, proxyData := range requestData {
				proxyId, ok := proxyData["id"].(string)
				if !ok {
					continue
				}

				proxyName, ok := proxyData["name"].(string)
				if !ok {
					continue
				}

				proxyType, ok := proxyData["type"].(string)
				if !ok {
					continue
				}

				proxyServer, ok := proxyData["server"].(string)
				if !ok {
					continue
				}

				proxyPort, ok := proxyData["port"].(float64) // JSON中的数字默认是float64
				if !ok {
					continue
				}

				proxyConfig, ok := proxyData["config"].(map[string]interface{})
				if !ok {
					proxyConfig = make(map[string]interface{})
				}

				proxyInfo := &proxy.ProxyInfo{
					ID:     proxyId,
					Name:   proxyName,
					Type:   proxy.ProtocolType(proxyType),
					Server: proxyServer,
					Port:   int(proxyPort),
					Config: proxyConfig,
					Stats: &proxy.ProxyStats{
						Upload:   0,
						Download: 0,
					},
				}

				proxies[proxyId] = proxyInfo
			}

			// 更新代理源的代理列表
			as.proxyCore.UpdateProxySourceProxies(sourceId, proxies)

			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Proxies updated"))
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
		return
	}

	// 如果路径是 /proxy-sources/{id}/current-proxy
	if len(parts) == 2 && parts[1] == "current-proxy" {
		switch r.Method {
		case "GET":
			// 获取代理源的当前代理
			currentProxy := as.proxyCore.GetCurrentProxy(sourceId)
			if currentProxy == nil {
				log.Printf("代理源 %s 没有当前代理", sourceId)
				http.Error(w, "No current proxy", http.StatusNotFound)
				return
			}

			proxyData := map[string]interface{}{
				"id":     currentProxy.ID,
				"name":   currentProxy.Name,
				"type":   string(currentProxy.Type),
				"server": currentProxy.Server,
				"port":   currentProxy.Port,
				"config": currentProxy.Config,
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(proxyData)
		case "PUT":
			// 设置代理源的当前代理
			var requestData map[string]interface{}
			if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
				log.Printf("解析当前代理请求体失败: %v", err)
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}

			// 解析代理信息
			proxyId, ok := requestData["id"].(string)
			if !ok {
				log.Printf("缺少代理ID")
				http.Error(w, "Missing proxy id", http.StatusBadRequest)
				return
			}

			proxyName, ok := requestData["name"].(string)
			if !ok {
				log.Printf("缺少代理名称")
				http.Error(w, "Missing proxy name", http.StatusBadRequest)
				return
			}

			proxyType, ok := requestData["type"].(string)
			if !ok {
				log.Printf("缺少代理类型")
				http.Error(w, "Missing proxy type", http.StatusBadRequest)
				return
			}

			proxyServer, ok := requestData["server"].(string)
			if !ok {
				log.Printf("缺少代理服务器")
				http.Error(w, "Missing proxy server", http.StatusBadRequest)
				return
			}

			proxyPort, ok := requestData["port"].(float64) // JSON中的数字默认是float64
			if !ok {
				log.Printf("缺少代理端口")
				http.Error(w, "Missing proxy port", http.StatusBadRequest)
				return
			}

			proxyConfig, ok := requestData["config"].(map[string]interface{})
			if !ok {
				proxyConfig = make(map[string]interface{})
			}

			// 创建代理信息
			proxyInfo := &proxy.ProxyInfo{
				ID:     proxyId,
				Name:   proxyName,
				Type:   proxy.ProtocolType(proxyType),
				Server: proxyServer,
				Port:   int(proxyPort),
				Config: proxyConfig,
				Stats: &proxy.ProxyStats{
					Upload:   0,
					Download: 0,
				},
			}

			// 添加日志以调试当前代理设置
			log.Printf("设置代理源 %s 的当前代理: %+v", sourceId, proxyInfo)
			log.Printf("代理配置详情: server=%s, port=%d, type=%s", proxyServer, int(proxyPort), proxyType)
			if proxyType == "shadowsocks" {
				if cipher, ok := proxyConfig["cipher"]; ok {
					log.Printf("Shadowsocks cipher: %v", cipher)
				}
				if password, ok := proxyConfig["password"]; ok {
					log.Printf("Shadowsocks password: %v", password)
				}
				if method, ok := proxyConfig["method"]; ok {
					log.Printf("Shadowsocks method: %v", method)
				}
			}

			// 设置当前代理
			as.proxyCore.SetCurrentProxy(sourceId, proxyInfo)

			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Current proxy set"))
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
		return
	}

	// 其他路径
	http.Error(w, "Not found", http.StatusNotFound)
}

// handleStats 处理统计信息API
func (as *APIServer) handleStats(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 获取所有代理源的当前代理的统计信息
		currentProxies := as.proxyCore.GetAllCurrentProxies()

		// 计算总上传和下载速度
		var totalUpload uint64 = 0
		var totalDownload uint64 = 0

		// 构建响应数据
		response := make(map[string]interface{})
		statsData := make(map[string]interface{})

		for sourceId, proxyInfo := range currentProxies {
			proxyStats := map[string]interface{}{
				"source_id":  sourceId,
				"proxy_id":   proxyInfo.ID,
				"proxy_name": proxyInfo.Name,
				"upload":     proxyInfo.Stats.Upload,
				"download":   proxyInfo.Stats.Download,
			}
			statsData[sourceId] = proxyStats

			// 累加总流量
			totalUpload += proxyInfo.Stats.Upload
			totalDownload += proxyInfo.Stats.Download
		}

		// 添加总的上传和下载速度字段，以满足Flutter端的期望格式
		response["stats"] = statsData
		response["upload_speed"] = formatSpeed(totalUpload)     // 格式化为字符串，如 "↑ 10 KB/s"
		response["download_speed"] = formatSpeed(totalDownload) // 格式化为字符串，如 "↓ 20 KB/s"

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleProtocols 处理协议API
func (as *APIServer) handleProtocols(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// 获取所有协议
		protocols := as.proxyCore.GetProtocolManager().GetAllProtocols()

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

		// 解析协议信息
		protocolName, ok := requestData["name"].(string)
		if !ok {
			http.Error(w, "Missing protocol name", http.StatusBadRequest)
			return
		}

		protocolType, ok := requestData["type"].(string)
		if !ok {
			http.Error(w, "Missing protocol type", http.StatusBadRequest)
			return
		}

		// 创建协议配置
		config := make(map[string]interface{})
		for k, v := range requestData {
			if k != "name" && k != "type" {
				config[k] = v
			}
		}

		// 创建协议
		_, err := as.proxyCore.GetProtocolManager().CreateProtocol(proxy.ProtocolType(protocolType), protocolName, config)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusCreated)
		w.Write([]byte("Protocol added"))
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// formatSpeed 将字节速率格式化为人类可读的字符串
func formatSpeed(bytesPerSecond uint64) string {
	if bytesPerSecond < 1024 {
		return fmt.Sprintf("↑ %d B/s", bytesPerSecond)
	} else if bytesPerSecond < 1024*1024 {
		return fmt.Sprintf("↑ %.2f KB/s", float64(bytesPerSecond)/1024)
	} else {
		return fmt.Sprintf("↑ %.2f MB/s", float64(bytesPerSecond)/(1024*1024))
	}
}
