package proxy

import (
	"fmt"
	"net"
	"time"
)

// SoftEtherProtocol SoftEther协议实现
type SoftEtherProtocol struct {
	BaseProtocol
	server   string
	port     int
	username string
	password string
	hub      string // 虚拟HUB名称
}

// SoftEtherProtocolFactory SoftEther协议工厂
type SoftEtherProtocolFactory struct{}

// CreateProtocol 创建SoftEther协议实例
func (f *SoftEtherProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
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
	hub, _ := config["hub"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("softether-%s:%d", server, port)
	}

	protocol := &SoftEtherProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolSoftEther,
		},
		server:   server,
		port:     port,
		username: username,
		password: password,
		hub:      hub,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过SoftEther）
func (sp *SoftEtherProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到SoftEther服务器
	softetherAddr := fmt.Sprintf("%s:%d", sp.server, sp.port)
	conn, err := net.DialTimeout("tcp", softetherAddr, 10*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to SoftEther server %s: %v", softetherAddr, err)
	}

	// TODO: 实现SoftEther协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (sp *SoftEtherProtocol) Close() error {
	// SoftEther协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (sp *SoftEtherProtocol) IsRunning() bool {
	// SoftEther协议运行状态检查
	return true
}
