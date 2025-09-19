package proxy

import (
	"fmt"
	"net"
	"time"
)

// TrojanProtocol Trojan协议实现
type TrojanProtocol struct {
	BaseProtocol
	server   string
	port     int
	password string
}

// TrojanProtocolFactory Trojan协议工厂
type TrojanProtocolFactory struct{}

// CreateProtocol 创建Trojan协议实例
func (f *TrojanProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	port, ok := config["port"].(int)
	if !ok {
		return nil, fmt.Errorf("missing port in config")
	}

	password, _ := config["password"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("trojan-%s:%d", server, port)
	}

	protocol := &TrojanProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolTrojan,
		},
		server:   server,
		port:     port,
		password: password,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过Trojan）
func (tp *TrojanProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到Trojan服务器
	trojanAddr := fmt.Sprintf("%s:%d", tp.server, tp.port)
	conn, err := net.DialTimeout("tcp", trojanAddr, 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Trojan server %s: %v", trojanAddr, err)
	}

	// TODO: 实现Trojan协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (tp *TrojanProtocol) Close() error {
	// Trojan协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (tp *TrojanProtocol) IsRunning() bool {
	// Trojan协议运行状态检查
	return true
}
