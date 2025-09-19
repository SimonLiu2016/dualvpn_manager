package proxy

import (
	"fmt"
	"net"
	"time"
)

// WireGuardProtocol WireGuard协议实现
type WireGuardProtocol struct {
	BaseProtocol
	server     string
	port       int
	publicKey  string
	privateKey string
}

// WireGuardProtocolFactory WireGuard协议工厂
type WireGuardProtocolFactory struct{}

// CreateProtocol 创建WireGuard协议实例
func (f *WireGuardProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	port, ok := config["port"].(int)
	if !ok {
		return nil, fmt.Errorf("missing port in config")
	}

	publicKey, _ := config["public_key"].(string)
	privateKey, _ := config["private_key"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("wireguard-%s:%d", server, port)
	}

	protocol := &WireGuardProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolWireGuard,
		},
		server:     server,
		port:       port,
		publicKey:  publicKey,
		privateKey: privateKey,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过WireGuard）
func (wp *WireGuardProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到WireGuard服务器
	// 注意：这是一个简化的实现，实际的WireGuard连接需要更复杂的握手过程
	wgAddr := fmt.Sprintf("%s:%d", wp.server, wp.port)
	conn, err := net.DialTimeout("udp", wgAddr, 10*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to WireGuard server %s: %v", wgAddr, err)
	}

	// TODO: 实现WireGuard协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (wp *WireGuardProtocol) Close() error {
	// WireGuard协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (wp *WireGuardProtocol) IsRunning() bool {
	// WireGuard协议运行状态检查
	return true
}
