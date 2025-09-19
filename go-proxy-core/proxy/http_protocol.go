package proxy

import (
	"fmt"
	"net"
	"strings"
	"time"
)

// HTTPProtocol HTTP协议实现
type HTTPProtocol struct {
	BaseProtocol
	server   string
	port     int
	username string
	password string
}

// HTTPProtocolFactory HTTP协议工厂
type HTTPProtocolFactory struct{}

// CreateProtocol 创建HTTP协议实例
func (f *HTTPProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	// 修复：正确处理端口配置
	var port int
	switch v := config["port"].(type) {
	case int:
		port = v
	case float64:
		port = int(v)
	default:
		return nil, fmt.Errorf("missing or invalid port in config")
	}

	username, _ := config["username"].(string)
	password, _ := config["password"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("http-%s:%d", server, port)
	}

	protocol := &HTTPProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolHTTP,
		},
		server:   server,
		port:     port,
		username: username,
		password: password,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过HTTP代理）
func (hp *HTTPProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到HTTP代理服务器
	proxyAddr := fmt.Sprintf("%s:%d", hp.server, hp.port)
	conn, err := net.DialTimeout("tcp", proxyAddr, 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to HTTP proxy %s: %v", proxyAddr, err)
	}

	// 实现HTTP代理协议握手逻辑
	// 发送CONNECT请求
	connectReq := fmt.Sprintf("CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n", targetAddr, targetAddr)
	_, err = conn.Write([]byte(connectReq))
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to send CONNECT request: %v", err)
	}

	// 读取响应
	buf := make([]byte, 1024)
	response := ""

	// 循环读取直到找到响应头结束标记
	for {
		n, err := conn.Read(buf)
		if err != nil {
			conn.Close()
			return nil, fmt.Errorf("failed to read CONNECT response: %v", err)
		}

		response += string(buf[:n])

		// 检查是否收到完整的响应头
		if strings.Contains(response, "\r\n\r\n") {
			break
		}

		// 防止无限循环
		if len(response) > 8192 {
			conn.Close()
			return nil, fmt.Errorf("response too large or malformed")
		}
	}

	// 检查响应状态码
	if !strings.HasPrefix(response, "HTTP/1.1 200") && !strings.HasPrefix(response, "HTTP/1.0 200") {
		conn.Close()
		return nil, fmt.Errorf("CONNECT request failed: %s", response)
	}

	// 连接已建立，返回连接
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
