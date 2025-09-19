package proxy

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"sync/atomic"

	"github.com/dualvpn/go-proxy-core/routing"
)

// HTTPServer HTTP代理服务器
type HTTPServer struct {
	port            int
	rulesEngine     *routing.RulesEngine
	protocolManager *ProtocolManager
	listener        net.Listener
	running         bool
	// 统计信息
	totalUpload   uint64
	totalDownload uint64
	connections   int64
}

// NewHTTPServer 创建新的HTTP服务器
func NewHTTPServer(port int, rulesEngine *routing.RulesEngine, protocolManager *ProtocolManager) *HTTPServer {
	return &HTTPServer{
		port:            port,
		rulesEngine:     rulesEngine,
		protocolManager: protocolManager,
	}
}

// Start 启动HTTP服务器
func (hs *HTTPServer) Start() error {
	addr := net.JoinHostPort("127.0.0.1", fmt.Sprintf("%d", hs.port))
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}

	hs.listener = listener
	hs.running = true

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

// handleConnection 处理连接
func (hs *HTTPServer) handleConnection(clientConn net.Conn) {
	defer clientConn.Close()

	// 增加连接数
	atomic.AddInt64(&hs.connections, 1)
	defer atomic.AddInt64(&hs.connections, -1)

	// 读取客户端请求
	reader := bufio.NewReader(clientConn)
	req, err := http.ReadRequest(reader)
	if err != nil {
		log.Printf("Error reading request: %v", err)
		return
	}

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

// handleDirectConnection 处理直接连接
func (hs *HTTPServer) handleDirectConnection(clientConn net.Conn, req *http.Request, targetAddr string) {
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
		clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))

		// 创建带统计的连接包装器
		statsClientConn := &StatsConn{Conn: clientConn, collector: &HTTPServerStats{server: hs}}
		statsTargetConn := &StatsConn{Conn: conn, collector: &HTTPServerStats{server: hs}}

		// 在客户端和目标服务器之间转发数据
		go io.Copy(statsTargetConn, statsClientConn)
		io.Copy(statsClientConn, statsTargetConn)
	} else {
		// 对于普通HTTP请求，转发请求到目标服务器
		// 创建带统计的连接包装器
		statsClientConn := &StatsConn{Conn: clientConn, collector: &HTTPServerStats{server: hs}}
		statsTargetConn := &StatsConn{Conn: conn, collector: &HTTPServerStats{server: hs}}

		// 先转发请求到目标服务器
		err = req.Write(statsTargetConn)
		if err != nil {
			log.Printf("Error writing request to target: %v", err)
			// 发送错误响应
			statsClientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
			return
		}

		// 将目标服务器的响应转发给客户端
		io.Copy(statsClientConn, statsTargetConn)
	}
}

// handleProxyConnection 处理通过代理连接
func (hs *HTTPServer) handleProxyConnection(clientConn net.Conn, req *http.Request, targetAddr string, proxySource string) {
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
		clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))

		// 创建带统计的连接包装器
		statsClientConn := &StatsConn{Conn: clientConn, collector: &HTTPServerStats{server: hs}}
		statsTargetConn := &StatsConn{Conn: conn, collector: &HTTPServerStats{server: hs}}

		// 在客户端和目标服务器之间转发数据
		go io.Copy(statsTargetConn, statsClientConn)
		io.Copy(statsClientConn, statsTargetConn)
	} else {
		// 对于普通HTTP请求，转发请求到目标服务器
		// 创建带统计的连接包装器
		statsClientConn := &StatsConn{Conn: clientConn, collector: &HTTPServerStats{server: hs}}
		statsTargetConn := &StatsConn{Conn: conn, collector: &HTTPServerStats{server: hs}}

		// 先转发请求到目标服务器
		err = req.Write(statsTargetConn)
		if err != nil {
			log.Printf("Error writing request to target: %v", err)
			// 发送错误响应
			statsClientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
			return
		}

		// 将目标服务器的响应转发给客户端
		io.Copy(statsClientConn, statsTargetConn)
	}
}
