package proxy

import (
	"fmt"
	"io"
	"log"
	"net"
	"sync/atomic"

	"github.com/dualvpn/go-proxy-core/routing"
)

// SOCKS5Server SOCKS5代理服务器
type SOCKS5Server struct {
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
}

// NewSOCKS5Server 创建新的SOCKS5服务器
func NewSOCKS5Server(port int, rulesEngine *routing.RulesEngine, protocolManager *ProtocolManager, proxyCore *ProxyCore) *SOCKS5Server {
	return &SOCKS5Server{
		port:            port,
		rulesEngine:     rulesEngine,
		protocolManager: protocolManager,
		proxyCore:       proxyCore, // 初始化ProxyCore引用
	}
}

// Start 启动SOCKS5服务器
func (ss *SOCKS5Server) Start() error {
	addr := net.JoinHostPort("127.0.0.1", fmt.Sprintf("%d", ss.port))
	log.Printf("尝试启动SOCKS5服务器在地址: %s", addr)
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		log.Printf("启动SOCKS5服务器失败: %v", err)
		return err
	}

	ss.listener = listener
	ss.running = true

	log.Printf("SOCKS5 proxy server listening on %s", addr)
	log.Printf("SOCKS5服务器配置: port=%d", ss.port)

	for ss.running {
		conn, err := listener.Accept()
		if err != nil {
			if ss.running {
				log.Printf("Error accepting connection: %v", err)
			}
			break
		}

		go ss.handleConnection(conn)
	}

	return nil
}

// Stop 停止SOCKS5服务器
func (ss *SOCKS5Server) Stop() {
	ss.running = false
	if ss.listener != nil {
		ss.listener.Close()
	}
}

// GetStats 获取SOCKS5服务器统计信息
func (ss *SOCKS5Server) GetStats() (upload, download uint64, connections int64) {
	return atomic.LoadUint64(&ss.totalUpload),
		atomic.LoadUint64(&ss.totalDownload),
		atomic.LoadInt64(&ss.connections)
}

// handleConnection 处理连接
func (ss *SOCKS5Server) handleConnection(clientConn net.Conn) {
	defer clientConn.Close()

	// 增加连接数
	atomic.AddInt64(&ss.connections, 1)
	defer atomic.AddInt64(&ss.connections, -1)

	// 读取SOCKS5握手请求
	buf := make([]byte, 256)
	n, err := clientConn.Read(buf)
	if err != nil {
		log.Printf("Error reading SOCKS5 handshake: %v", err)
		return
	}

	// 检查SOCKS5版本
	if buf[0] != 0x05 {
		log.Printf("Invalid SOCKS version: %x", buf[0])
		return
	}

	// 发送握手响应（不支持认证）
	clientConn.Write([]byte{0x05, 0x00})

	// 读取连接请求
	n, err = clientConn.Read(buf)
	if err != nil {
		log.Printf("Error reading SOCKS5 request: %v", err)
		return
	}

	// 检查SOCKS5版本
	if buf[0] != 0x05 {
		log.Printf("Invalid SOCKS version in request: %x", buf[0])
		return
	}

	// 获取目标地址
	var targetAddr string
	switch buf[3] {
	case 0x01: // IPv4
		if n < 10 {
			log.Printf("Invalid IPv4 address length")
			return
		}
		ip := net.IP(buf[4:8])
		port := int(buf[8])<<8 | int(buf[9])
		targetAddr = fmt.Sprintf("%s:%d", ip.String(), port)
	case 0x03: // 域名
		if n < 7 {
			log.Printf("Invalid domain address length")
			return
		}
		domainLen := int(buf[4])
		if n < 5+domainLen+2 {
			log.Printf("Invalid domain address length")
			return
		}
		domain := string(buf[5 : 5+domainLen])
		port := int(buf[5+domainLen])<<8 | int(buf[5+domainLen+1])
		targetAddr = fmt.Sprintf("%s:%d", domain, port)
	case 0x04: // IPv6
		if n < 22 {
			log.Printf("Invalid IPv6 address length")
			return
		}
		ip := net.IP(buf[4:20])
		port := int(buf[20])<<8 | int(buf[21])
		targetAddr = fmt.Sprintf("[%s]:%d", ip.String(), port)
	default:
		log.Printf("Unsupported address type: %x", buf[3])
		return
	}

	// 根据路由规则决定代理源
	proxySource := ss.rulesEngine.Match(targetAddr)
	log.Printf("SOCKS5 request to %s, matched proxy source: %s", targetAddr, proxySource)

	// 添加更详细的日志以调试路由匹配
	log.Printf("路由匹配详情: 目标地址=%s, 匹配到的代理源=%s", targetAddr, proxySource)

	if proxySource == "DIRECT" {
		// 直接连接目标
		ss.handleDirectConnection(clientConn, targetAddr)
	} else {
		// 通过代理连接目标
		ss.handleProxyConnection(clientConn, targetAddr, proxySource)
	}
}

// handleProxyConnection 处理通过代理连接
func (ss *SOCKS5Server) handleProxyConnection(clientConn net.Conn, targetAddr string, proxySource string) {
	log.Printf("SOCKS5服务器通过代理源 %s 连接到目标 %s", proxySource, targetAddr)

	// 使用协议管理器通过指定代理连接
	conn, err := ss.protocolManager.Connect(proxySource, targetAddr)
	if err != nil {
		log.Printf("Proxy connection to %s via %s failed: %v", targetAddr, proxySource, err)
		// 发送连接失败响应
		clientConn.Write([]byte{0x05, 0x05, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00})
		return
	}
	defer conn.Close()

	// 发送连接成功响应
	clientConn.Write([]byte{0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00})

	// 创建按代理源维度的统计收集器
	proxySourceStatsCollector := NewProxySourceStatsCollector(proxySource, ss.proxyCore)

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
}

// handleDirectConnection 处理直接连接
func (ss *SOCKS5Server) handleDirectConnection(clientConn net.Conn, targetAddr string) {
	log.Printf("SOCKS5服务器直接连接到目标 %s", targetAddr)

	// 使用协议管理器进行直连
	conn, err := ss.protocolManager.Connect("direct", targetAddr)
	if err != nil {
		log.Printf("Error connecting to target: %v", err)
		// 发送连接失败响应
		clientConn.Write([]byte{0x05, 0x05, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00})
		return
	}
	defer conn.Close()

	// 发送连接成功响应
	clientConn.Write([]byte{0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00})

	// 创建按代理源维度的统计收集器（直连使用"DIRECT"作为代理源ID）
	proxySourceStatsCollector := NewProxySourceStatsCollector("DIRECT", ss.proxyCore)

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
}
