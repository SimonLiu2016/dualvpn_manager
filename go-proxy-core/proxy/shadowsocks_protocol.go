package proxy

import (
	"fmt"
	"net"
	"time"
)

// ShadowsocksProtocol Shadowsocks协议实现
type ShadowsocksProtocol struct {
	BaseProtocol
	server   string
	port     int
	password string
	method   string // 加密方法
}

// ShadowsocksProtocolFactory Shadowsocks协议工厂
type ShadowsocksProtocolFactory struct{}

// CreateProtocol 创建Shadowsocks协议实例
func (f *ShadowsocksProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	port, ok := config["port"].(int)
	if !ok {
		return nil, fmt.Errorf("missing port in config")
	}

	password, _ := config["password"].(string)
	method, _ := config["method"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("shadowsocks-%s:%d", server, port)
	}

	if method == "" {
		method = "AES-256-GCM" // 默认加密方法
	}

	protocol := &ShadowsocksProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolShadowsocks,
		},
		server:   server,
		port:     port,
		password: password,
		method:   method,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过Shadowsocks）
func (sp *ShadowsocksProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到Shadowsocks服务器
	ssAddr := fmt.Sprintf("%s:%d", sp.server, sp.port)
	conn, err := net.DialTimeout("tcp", ssAddr, 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Shadowsocks server %s: %v", ssAddr, err)
	}

	// TODO: 实现Shadowsocks协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (sp *ShadowsocksProtocol) Close() error {
	// Shadowsocks协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (sp *ShadowsocksProtocol) IsRunning() bool {
	// Shadowsocks协议运行状态检查
	return true
}
