package proxy

import (
	"fmt"
	"net"
	"time"
)

// IKEv2Protocol IKEv2协议实现
type IKEv2Protocol struct {
	BaseProtocol
	server   string
	port     int
	username string
	password string
	psk      string // 预共享密钥
}

// IKEv2ProtocolFactory IKEv2协议工厂
type IKEv2ProtocolFactory struct{}

// CreateProtocol 创建IKEv2协议实例
func (f *IKEv2ProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
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
		name = fmt.Sprintf("ikev2-%s:%d", server, port)
	}

	protocol := &IKEv2Protocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolIKEv2,
		},
		server:   server,
		port:     port,
		username: username,
		password: password,
		psk:      psk,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过IKEv2）
func (ip *IKEv2Protocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到IKEv2服务器
	// 注意：这是一个简化的实现，实际的IKEv2连接需要更复杂的IKE协商过程
	ikev2Addr := fmt.Sprintf("%s:%d", ip.server, ip.port)
	conn, err := net.DialTimeout("udp", ikev2Addr, 10*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to IKEv2 server %s: %v", ikev2Addr, err)
	}

	// TODO: 实现IKEv2协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (ip *IKEv2Protocol) Close() error {
	// IKEv2协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (ip *IKEv2Protocol) IsRunning() bool {
	// IKEv2协议运行状态检查
	return true
}
