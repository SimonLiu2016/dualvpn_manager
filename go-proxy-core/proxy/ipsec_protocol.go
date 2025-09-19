package proxy

import (
	"fmt"
	"net"
	"time"
)

// IPsecProtocol IPsec协议实现
type IPsecProtocol struct {
	BaseProtocol
	server   string
	port     int
	username string
	password string
	psk      string // 预共享密钥
}

// IPsecProtocolFactory IPsec协议工厂
type IPsecProtocolFactory struct{}

// CreateProtocol 创建IPsec协议实例
func (f *IPsecProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	port, ok := config["port"].(int)
	if !ok {
		return nil, fmt.Errorf("missing port in config")
	}

	username, _ := config["username"].(string)
	password, _ := config["password"].(string)
	psk, _ := config["psk"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("ipsec-%s:%d", server, port)
	}

	protocol := &IPsecProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolIPsec,
		},
		server:   server,
		port:     port,
		username: username,
		password: password,
		psk:      psk,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过IPsec）
func (ip *IPsecProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到IPsec服务器
	// 注意：这是一个简化的实现，实际的IPsec连接需要更复杂的IKE协商过程
	ipsecAddr := fmt.Sprintf("%s:%d", ip.server, ip.port)
	conn, err := net.DialTimeout("udp", ipsecAddr, 10*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to IPsec server %s: %v", ipsecAddr, err)
	}

	// TODO: 实现IPsec协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (ip *IPsecProtocol) Close() error {
	// IPsec协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (ip *IPsecProtocol) IsRunning() bool {
	// IPsec协议运行状态检查
	return true
}
