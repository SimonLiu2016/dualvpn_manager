package proxy

import (
	"fmt"
	"net"
	"time"
)

// PPTPProtocol PPTP协议实现
type PPTPProtocol struct {
	BaseProtocol
	server   string
	port     int
	username string
	password string
}

// PPTPProtocolFactory PPTP协议工厂
type PPTPProtocolFactory struct{}

// CreateProtocol 创建PPTP协议实例
func (f *PPTPProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
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
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("pptp-%s:%d", server, port)
	}

	protocol := &PPTPProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolPPTP,
		},
		server:   server,
		port:     port,
		username: username,
		password: password,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过PPTP）
func (pp *PPTPProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到PPTP服务器
	// 注意：这是一个简化的实现，实际的PPTP连接需要更复杂的控制通道建立过程
	pptpAddr := fmt.Sprintf("%s:%d", pp.server, pp.port)
	conn, err := net.DialTimeout("tcp", pptpAddr, 10*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to PPTP server %s: %v", pptpAddr, err)
	}

	// TODO: 实现PPTP协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (pp *PPTPProtocol) Close() error {
	// PPTP协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (pp *PPTPProtocol) IsRunning() bool {
	// PPTP协议运行状态检查
	return true
}
