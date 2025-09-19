package proxy

import (
	"fmt"
	"net"
	"time"
)

// VMessProtocol VMess协议实现
type VMessProtocol struct {
	BaseProtocol
	server   string
	port     int
	userID   string
	alterID  int
	security string // 加密方式
	network  string // 传输协议
}

// VMessProtocolFactory VMess协议工厂
type VMessProtocolFactory struct{}

// CreateProtocol 创建VMess协议实例
func (f *VMessProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	port, ok := config["port"].(int)
	if !ok {
		return nil, fmt.Errorf("missing port in config")
	}

	userID, _ := config["user_id"].(string)
	alterID, _ := config["alter_id"].(int)
	security, _ := config["security"].(string)
	network, _ := config["network"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("vmess-%s:%d", server, port)
	}

	if security == "" {
		security = "auto" // 默认加密方式
	}

	if network == "" {
		network = "tcp" // 默认传输协议
	}

	protocol := &VMessProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolVMess,
		},
		server:   server,
		port:     port,
		userID:   userID,
		alterID:  alterID,
		security: security,
		network:  network,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过VMess）
func (vp *VMessProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到VMess服务器
	vmessAddr := fmt.Sprintf("%s:%d", vp.server, vp.port)
	conn, err := net.DialTimeout("tcp", vmessAddr, 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to VMess server %s: %v", vmessAddr, err)
	}

	// TODO: 实现VMess协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (vp *VMessProtocol) Close() error {
	// VMess协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (vp *VMessProtocol) IsRunning() bool {
	// VMess协议运行状态检查
	return true
}
