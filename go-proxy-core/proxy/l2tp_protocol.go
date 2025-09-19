package proxy

import (
	"fmt"
	"net"
	"time"
)

// L2TPProtocol L2TP协议实现
type L2TPProtocol struct {
	BaseProtocol
	server   string
	port     int
	username string
	password string
	psk      string // 预共享密钥
}

// L2TPProtocolFactory L2TP协议工厂
type L2TPProtocolFactory struct{}

// CreateProtocol 创建L2TP协议实例
func (f *L2TPProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
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
		name = fmt.Sprintf("l2tp-%s:%d", server, port)
	}

	protocol := &L2TPProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolL2TP,
		},
		server:   server,
		port:     port,
		username: username,
		password: password,
		psk:      psk,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过L2TP）
func (lp *L2TPProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到L2TP服务器
	// 注意：这是一个简化的实现，实际的L2TP连接需要更复杂的控制通道建立过程
	l2tpAddr := fmt.Sprintf("%s:%d", lp.server, lp.port)
	conn, err := net.DialTimeout("udp", l2tpAddr, 10*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to L2TP server %s: %v", l2tpAddr, err)
	}

	// TODO: 实现L2TP协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (lp *L2TPProtocol) Close() error {
	// L2TP协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (lp *L2TPProtocol) IsRunning() bool {
	// L2TP协议运行状态检查
	return true
}
