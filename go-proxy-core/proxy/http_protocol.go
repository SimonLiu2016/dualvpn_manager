package proxy

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/url"
	"time"
)

// HTTPProtocol HTTP协议实现
type HTTPProtocol struct {
	BaseProtocol
	server string
	port   int
}

// HTTPProtocolFactory HTTP协议工厂
type HTTPProtocolFactory struct{}

// CreateProtocol 创建HTTP协议实例
func (f *HTTPProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	port, ok := config["port"].(int)
	if !ok {
		return nil, fmt.Errorf("missing port in config")
	}

	name, _ := config["name"].(string)
	if name == "" {
		name = fmt.Sprintf("http-%s:%d", server, port)
	}

	protocol := &HTTPProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolHTTP,
		},
		server: server,
		port:   port,
	}

	// 添加日志以调试HTTP协议创建
	log.Printf("创建HTTP协议: server=%s, port=%d", server, port)

	return protocol, nil
}

// Connect 连接到目标地址（通过HTTP代理）
func (hp *HTTPProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 添加详细的连接日志
	log.Printf("HTTP协议开始连接: targetAddr=%s, server=%s, port=%d",
		targetAddr, hp.server, hp.port)

	// 连接到HTTP代理服务器
	proxyAddr := fmt.Sprintf("%s:%d", hp.server, hp.port)
	log.Printf("连接到HTTP代理服务器地址: %s", proxyAddr)

	conn, err := net.DialTimeout("tcp", proxyAddr, 5*time.Second)
	if err != nil {
		log.Printf("连接HTTP代理服务器失败: %v", err)
		return nil, fmt.Errorf("failed to connect to HTTP proxy server %s: %v", proxyAddr, err)
	}

	// 发送CONNECT请求
	connectReq := &http.Request{
		Method: "CONNECT",
		URL:    &url.URL{Opaque: targetAddr},
		Host:   targetAddr,
		Header: make(http.Header),
	}
	connectReq.Header.Set("User-Agent", "DualVPN-Proxy/1.0")

	// 发送请求
	log.Printf("发送CONNECT请求到HTTP代理服务器")
	if err := connectReq.Write(conn); err != nil {
		conn.Close()
		log.Printf("发送CONNECT请求失败: %v", err)
		return nil, fmt.Errorf("failed to send CONNECT request: %v", err)
	}

	// 读取响应
	log.Printf("读取HTTP代理服务器响应")
	resp, err := http.ReadResponse(bufio.NewReader(conn), connectReq)
	if err != nil {
		conn.Close()
		log.Printf("读取HTTP代理服务器响应失败: %v", err)
		return nil, fmt.Errorf("failed to read CONNECT response: %v", err)
	}
	defer resp.Body.Close()

	// 检查响应状态
	if resp.StatusCode != http.StatusOK {
		conn.Close()
		log.Printf("HTTP代理服务器CONNECT请求失败，状态码: %d", resp.StatusCode)
		return nil, fmt.Errorf("CONNECT request failed with status %d", resp.StatusCode)
	}

	// 添加日志以调试HTTP连接过程
	log.Printf("HTTP协议成功连接到目标: %s 通过代理: %s:%d", targetAddr, hp.server, hp.port)

	return conn, nil
}

// Close 关闭连接
func (hp *HTTPProtocol) Close() error {
	// HTTP协议通常是无状态的，不需要特殊关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (hp *HTTPProtocol) IsRunning() bool {
	// HTTP协议通常是无状态的，总是认为在运行
	return true
}
