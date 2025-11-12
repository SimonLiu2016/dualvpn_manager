package proxy

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"sync"
	"sync/atomic"
	"time"

	"github.com/dualvpn/go-proxy-core/routing"
)

// HTTPServer HTTP代理服务器
type HTTPServer struct {
	port            int
	rulesEngine     *routing.RulesEngine
	protocolManager *ProtocolManager
	proxyCore       *ProxyCore // 添加对ProxyCore的引用
	listener        net.Listener
	running         bool
	// 统计信息
	totalUpload   uint64
	totalDownload uint64
	connections   int64
	// 实时速率计算
	lastUpload   uint64
	lastDownload uint64
	uploadRate   uint64
	downloadRate uint64
	lastUpdate   time.Time
	rateMutex    sync.RWMutex
}

// NewHTTPServer 创建新的HTTP服务器
func NewHTTPServer(port int, rulesEngine *routing.RulesEngine, protocolManager *ProtocolManager, proxyCore *ProxyCore) *HTTPServer {
	return &HTTPServer{
		port:            port,
		rulesEngine:     rulesEngine,
		protocolManager: protocolManager,
		proxyCore:       proxyCore, // 初始化ProxyCore引用
	}
}

// Start 启动HTTP服务器
func (hs *HTTPServer) Start() error {
	addr := net.JoinHostPort("127.0.0.1", fmt.Sprintf("%d", hs.port))
	log.Printf("尝试启动HTTP服务器在地址: %s", addr)
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		log.Printf("启动HTTP服务器失败: %v", err)
		return err
	}

	hs.listener = listener
	hs.running = true

	// 启动速率更新协程
	go hs.updateRates()

	log.Printf("HTTP proxy server listening on %s", addr)

	for hs.running {
		conn, err := listener.Accept()
		if err != nil {
			if hs.running {
				log.Printf("Error accepting connection: %v", err)
			}
			break
		}

		go hs.handleConnection(conn)
	}

	return nil
}

// Stop 停止HTTP服务器
func (hs *HTTPServer) Stop() {
	hs.running = false
	if hs.listener != nil {
		hs.listener.Close()
	}
}

// GetStats 获取HTTP服务器统计信息
func (hs *HTTPServer) GetStats() (upload, download uint64, connections int64) {
	return atomic.LoadUint64(&hs.totalUpload),
		atomic.LoadUint64(&hs.totalDownload),
		atomic.LoadInt64(&hs.connections)
}

// GetDetailedStats 获取HTTP服务器详细统计信息（包括实时速率）
func (hs *HTTPServer) GetDetailedStats() (upload, download, uploadRate, downloadRate uint64) {
	upload = atomic.LoadUint64(&hs.totalUpload)
	download = atomic.LoadUint64(&hs.totalDownload)

	// 获取实时速率
	hs.rateMutex.RLock()
	uploadRate = hs.uploadRate
	downloadRate = hs.downloadRate
	hs.rateMutex.RUnlock()

	return
}

// updateRates 定期更新速率计算
func (hs *HTTPServer) updateRates() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			currentUpload := atomic.LoadUint64(&hs.totalUpload)
			currentDownload := atomic.LoadUint64(&hs.totalDownload)

			// 原子地获取并更新lastUpload和lastDownload
			oldLastUpload := atomic.LoadUint64(&hs.lastUpload)
			oldLastDownload := atomic.LoadUint64(&hs.lastDownload)

			// 尝试原子更新lastUpload和lastDownload
			if !atomic.CompareAndSwapUint64(&hs.lastUpload, oldLastUpload, currentUpload) {
				// 如果更新失败，重新获取当前值
				oldLastUpload = atomic.LoadUint64(&hs.lastUpload)
			}

			if !atomic.CompareAndSwapUint64(&hs.lastDownload, oldLastDownload, currentDownload) {
				// 如果更新失败，重新获取当前值
				oldLastDownload = atomic.LoadUint64(&hs.lastDownload)
			}

			// 计算每秒速率
			uploadDiff := currentUpload - oldLastUpload
			downloadDiff := currentDownload - oldLastDownload

			hs.rateMutex.Lock()
			hs.uploadRate = uploadDiff
			hs.downloadRate = downloadDiff
			hs.rateMutex.Unlock()

			hs.lastUpdate = time.Now()
		}
	}
}

// handleConnection 处理连接
func (hs *HTTPServer) handleConnection(clientConn net.Conn) {
	defer clientConn.Close()

	// 增加连接数
	atomic.AddInt64(&hs.connections, 1)
	defer atomic.AddInt64(&hs.connections, -1)

	log.Printf("接受新的HTTP连接: %s", clientConn.RemoteAddr().String())

	// 读取客户端请求
	reader := bufio.NewReader(clientConn)
	req, err := http.ReadRequest(reader)
	if err != nil {
		log.Printf("Error reading request: %v", err)
		return
	}

	log.Printf("收到HTTP请求: %s %s", req.Method, req.URL.String())

	// 获取目标地址
	var targetAddr string
	if req.Method == "CONNECT" {
		// HTTPS CONNECT 请求
		targetAddr = req.Host
	} else {
		// HTTP 请求
		targetURL, err := url.Parse(req.URL.String())
		if err != nil {
			log.Printf("Error parsing URL: %v", err)
			return
		}
		targetAddr = targetURL.Host
		if targetURL.Port() == "" {
			if targetURL.Scheme == "https" {
				targetAddr += ":443"
			} else {
				targetAddr += ":80"
			}
		}
	}

	log.Printf("目标地址: %s", targetAddr)

	// 根据路由规则决定代理源
	proxySource := hs.rulesEngine.Match(targetAddr)
	log.Printf("HTTP request to %s, matched proxy source: %s", targetAddr, proxySource)

	if proxySource == "DIRECT" {
		// 直接连接目标
		hs.handleDirectConnection(clientConn, req, targetAddr)
	} else {
		// 通过代理连接目标
		hs.handleProxyConnection(clientConn, req, targetAddr, proxySource)
	}
}

// handleProxyConnection 处理通过代理连接
func (hs *HTTPServer) handleProxyConnection(clientConn net.Conn, req *http.Request, targetAddr string, proxySource string) {
	log.Printf("HTTP服务器通过代理源 %s 连接到目标 %s", proxySource, targetAddr)

	// 使用协议管理器通过指定代理连接
	conn, err := hs.protocolManager.Connect(proxySource, targetAddr)
	if err != nil {
		log.Printf("Proxy connection to %s via %s failed: %v", targetAddr, proxySource, err)
		// 发送错误响应
		clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
		return
	}
	defer conn.Close()

	if req.Method == "CONNECT" {
		// 对于HTTPS CONNECT请求，发送连接成功的响应
		log.Printf("发送HTTP CONNECT成功响应")
		clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))

		// 创建按代理源维度的统计收集器
		proxySourceStatsCollector := hs.proxyCore.CreateOrGetProxySourceStatsCollector(proxySource)

		// 创建自定义的流量统计连接，正确区分上传和下载
		// 客户端连接：isClientSide=true
		uploadConn := &DirectionalStatsConn{
			Conn:         clientConn,
			collector:    proxySourceStatsCollector,
			isClientSide: true,
		}
		// 目标服务器连接：isClientSide=false
		downloadConn := &DirectionalStatsConn{
			Conn:         conn,
			collector:    proxySourceStatsCollector,
			isClientSide: false,
		}

		// 在客户端和目标服务器之间转发数据
		// 客户端到目标服务器的数据流（上传）
		go func() {
			_, err := io.Copy(downloadConn, uploadConn)
			if err != nil {
				log.Printf("数据转发错误 (客户端到目标): %v", err)
			}
		}()

		// 目标服务器到客户端的数据流（下载）
		_, err = io.Copy(uploadConn, downloadConn)
		if err != nil {
			log.Printf("数据转发错误 (目标到客户端): %v", err)
		}
	} else {
		// 对于普通HTTP请求，转发请求到目标服务器
		// 创建按代理源维度的统计收集器
		proxySourceStatsCollector := hs.proxyCore.CreateOrGetProxySourceStatsCollector(proxySource)

		// 创建自定义的流量统计连接，正确区分上传和下载
		// 客户端连接：isClientSide=true
		uploadConn := &DirectionalStatsConn{
			Conn:         clientConn,
			collector:    proxySourceStatsCollector,
			isClientSide: true,
		}
		// 目标服务器连接：isClientSide=false
		downloadConn := &DirectionalStatsConn{
			Conn:         conn,
			collector:    proxySourceStatsCollector,
			isClientSide: false,
		}

		// 修复：正确处理HTTP请求转发
		// 创建一个新的请求，确保Host头正确设置
		newReq := &http.Request{
			Method: req.Method,
			URL: &url.URL{
				Scheme:   req.URL.Scheme,
				Host:     targetAddr,
				Path:     req.URL.Path,
				RawQuery: req.URL.RawQuery,
			},
			Host:       targetAddr,
			Header:     req.Header,
			Body:       req.Body,
			Proto:      req.Proto,
			ProtoMajor: req.ProtoMajor,
			ProtoMinor: req.ProtoMinor,
		}

		// 移除代理特有的头部
		newReq.Header.Del("Proxy-Connection")
		newReq.Header.Del("Proxy-Authorization")

		// 移除可能干扰的头部
		newReq.Header.Del("Connection")
		newReq.Header.Del("Upgrade")
		newReq.Header.Del("Accept-Encoding") // 避免压缩问题

		// 添加必要的头部
		if newReq.Header.Get("User-Agent") == "" {
			newReq.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36")
		}

		// 设置连接为关闭状态，避免连接复用问题
		newReq.Header.Set("Connection", "close")

		// 先转发请求到目标服务器（上传）
		log.Printf("转发HTTP请求到目标服务器")
		err = newReq.Write(downloadConn)
		if err != nil {
			log.Printf("Error writing request to target: %v", err)
			// 发送错误响应
			uploadConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
			return
		}

		// 将目标服务器的响应转发给客户端（下载）
		log.Printf("转发目标服务器响应到客户端")
		_, err = io.Copy(uploadConn, downloadConn)
		if err != nil {
			log.Printf("转发目标服务器响应失败: %v", err)
		}
	}
}

// handleDirectConnection 处理直接连接
func (hs *HTTPServer) handleDirectConnection(clientConn net.Conn, req *http.Request, targetAddr string) {
	log.Printf("HTTP服务器直接连接到目标 %s", targetAddr)

	// 使用协议管理器进行直连
	conn, err := hs.protocolManager.Connect("direct", targetAddr)
	if err != nil {
		log.Printf("Error connecting to target: %v", err)
		// 发送错误响应
		clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
		return
	}
	defer conn.Close()

	if req.Method == "CONNECT" {
		// 对于HTTPS CONNECT请求，发送连接成功的响应
		log.Printf("发送HTTP CONNECT成功响应")
		clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))

		// 创建按代理源维度的统计收集器（直连使用"DIRECT"作为代理源ID）
		proxySourceStatsCollector := hs.proxyCore.CreateOrGetProxySourceStatsCollector("DIRECT")

		// 创建自定义的流量统计连接，正确区分上传和下载
		// 客户端连接：isClientSide=true
		uploadConn := &DirectionalStatsConn{
			Conn:         clientConn,
			collector:    proxySourceStatsCollector,
			isClientSide: true,
		}
		// 目标服务器连接：isClientSide=false
		downloadConn := &DirectionalStatsConn{
			Conn:         conn,
			collector:    proxySourceStatsCollector,
			isClientSide: false,
		}

		// 在客户端和目标服务器之间转发数据
		// 客户端到目标服务器的数据流（上传）
		go func() {
			_, err := io.Copy(downloadConn, uploadConn)
			if err != nil {
				log.Printf("数据转发错误 (客户端到目标): %v", err)
			}
		}()

		// 目标服务器到客户端的数据流（下载）
		_, err = io.Copy(uploadConn, downloadConn)
		if err != nil {
			log.Printf("数据转发错误 (目标到客户端): %v", err)
		}
	} else {
		// 对于普通HTTP请求，转发请求到目标服务器
		// 创建按代理源维度的统计收集器（直连使用"DIRECT"作为代理源ID）
		proxySourceStatsCollector := hs.proxyCore.CreateOrGetProxySourceStatsCollector("DIRECT")

		// 创建自定义的流量统计连接，正确区分上传和下载
		// 客户端连接：isClientSide=true
		uploadConn := &DirectionalStatsConn{
			Conn:         clientConn,
			collector:    proxySourceStatsCollector,
			isClientSide: true,
		}
		// 目标服务器连接：isClientSide=false
		downloadConn := &DirectionalStatsConn{
			Conn:         conn,
			collector:    proxySourceStatsCollector,
			isClientSide: false,
		}

		// 修复：正确处理HTTP请求转发
		// 创建一个新的请求，确保Host头正确设置
		newReq := &http.Request{
			Method: req.Method,
			URL: &url.URL{
				Scheme:   "http", // 直连时使用http协议
				Host:     targetAddr,
				Path:     req.URL.Path,
				RawQuery: req.URL.RawQuery,
			},
			Host:       targetAddr,
			Header:     req.Header,
			Body:       req.Body,
			Proto:      req.Proto,
			ProtoMajor: req.ProtoMajor,
			ProtoMinor: req.ProtoMinor,
		}

		// 移除代理特有的头部
		newReq.Header.Del("Proxy-Connection")
		newReq.Header.Del("Proxy-Authorization")

		// 移除可能干扰的头部
		newReq.Header.Del("Connection")
		newReq.Header.Del("Upgrade")
		newReq.Header.Del("Accept-Encoding") // 避免压缩问题

		// 添加必要的头部
		if newReq.Header.Get("User-Agent") == "" {
			newReq.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36")
		}

		// 设置连接为关闭状态，避免连接复用问题
		newReq.Header.Set("Connection", "close")

		// 先转发请求到目标服务器（上传）
		log.Printf("转发HTTP请求到目标服务器")
		err = newReq.Write(downloadConn)
		if err != nil {
			log.Printf("Error writing request to target: %v", err)
			// 发送错误响应
			uploadConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
			return
		}

		// 将目标服务器的响应转发给客户端（下载）
		log.Printf("转发目标服务器响应到客户端")
		_, err = io.Copy(uploadConn, downloadConn)
		if err != nil {
			log.Printf("转发目标服务器响应失败: %v", err)
		}
	}
}
