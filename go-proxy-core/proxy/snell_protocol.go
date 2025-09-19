package proxy

import (
	"fmt"
	"net"
	"time"
)

// SnellProtocol Snell协议实现
type SnellProtocol struct {
	BaseProtocol
	server   string
	port     int
	password string
	version  string // 协议版本
}

// SnellProtocolFactory Snell协议工厂
type SnellProtocolFactory struct{}

// CreateProtocol 创建Snell协议实例
func (f *SnellProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	port, ok := config["port"].(int)
	if !ok {
		return nil, fmt.Errorf("missing port in config")
	}

	password, _ := config["password"].(string)
	version, _ := config["version"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("snell-%s:%d", server, port)
	}

	if version == "" {
		version = "3" // 默认版本
	}

	protocol := &SnellProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolSnell,
		},
		server:   server,
		port:     port,
		password: password,
		version:  version,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过Snell）
func (sp *SnellProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到Snell服务器
	snellAddr := fmt.Sprintf("%s:%d", sp.server, sp.port)
	conn, err := net.DialTimeout("tcp", snellAddr, 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Snell server %s: %v", snellAddr, err)
	}

	// TODO: 实现Snell协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (sp *SnellProtocol) Close() error {
	// Snell协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (sp *SnellProtocol) IsRunning() bool {
	// Snell协议运行状态检查
	return true
}
