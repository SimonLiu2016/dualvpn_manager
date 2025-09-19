package proxy

import (
	"fmt"
	"io"
	"log"
	"net"

	"github.com/dualvpn/go-proxy-core/routing"
)

// SOCKS5Server SOCKS5代理服务器
type SOCKS5Server struct {
	port            int
	rulesEngine     *routing.RulesEngine
	protocolManager *ProtocolManager
	listener        net.Listener
	running         bool
}

// NewSOCKS5Server 创建新的SOCKS5服务器
func NewSOCKS5Server(port int, rulesEngine *routing.RulesEngine, protocolManager *ProtocolManager) *SOCKS5Server {
	return &SOCKS5Server{
		port:            port,
		rulesEngine:     rulesEngine,
		protocolManager: protocolManager,
	}
}

// Start 启动SOCKS5服务器
func (ss *SOCKS5Server) Start() error {
	addr := net.JoinHostPort("127.0.0.1", fmt.Sprintf("%d", ss.port))
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}

	ss.listener = listener
	ss.running = true

	log.Printf("SOCKS5 proxy server listening on %s", addr)

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

// handleConnection 处理连接
func (ss *SOCKS5Server) handleConnection(clientConn net.Conn) {
	defer clientConn.Close()

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

	if proxySource == "DIRECT" {
		// 直接连接目标
		ss.handleDirectConnection(clientConn, targetAddr)
	} else {
		// 通过代理连接目标
		ss.handleProxyConnection(clientConn, targetAddr, proxySource)
	}
}

// handleDirectConnection 处理直接连接
func (ss *SOCKS5Server) handleDirectConnection(clientConn net.Conn, targetAddr string) {
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

	// 在客户端和目标服务器之间转发数据
	go io.Copy(conn, clientConn)
	io.Copy(clientConn, conn)
}

// handleProxyConnection 处理通过代理连接
func (ss *SOCKS5Server) handleProxyConnection(clientConn net.Conn, targetAddr string, proxySource string) {
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

	// 在客户端和目标服务器之间转发数据
	go io.Copy(conn, clientConn)
	io.Copy(clientConn, conn)
}
