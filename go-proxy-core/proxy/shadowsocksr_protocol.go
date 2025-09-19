package proxy

import (
	"fmt"
	"net"
	"time"
)

// ShadowsocksRProtocol ShadowsocksR协议实现
type ShadowsocksRProtocol struct {
	BaseProtocol
	server        string
	port          int
	password      string
	method        string // 加密方法
	protocol      string // 协议插件
	obfs          string // 混淆插件
	protocolParam string // 协议参数
	obfsParam     string // 混淆参数
}

// ShadowsocksRProtocolFactory ShadowsocksR协议工厂
type ShadowsocksRProtocolFactory struct{}

// CreateProtocol 创建ShadowsocksR协议实例
func (f *ShadowsocksRProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
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
	protocol, _ := config["protocol"].(string)
	obfs, _ := config["obfs"].(string)
	protocolParam, _ := config["protocol_param"].(string)
	obfsParam, _ := config["obfs_param"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("shadowsocksr-%s:%d", server, port)
	}

	if method == "" {
		method = "AES-256-GCM" // 默认加密方法
	}

	if protocol == "" {
		protocol = "origin" // 默认协议插件
	}

	if obfs == "" {
		obfs = "plain" // 默认混淆插件
	}

	protocolInstance := &ShadowsocksRProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolShadowsocksR,
		},
		server:        server,
		port:          port,
		password:      password,
		method:        method,
		protocol:      protocol,
		obfs:          obfs,
		protocolParam: protocolParam,
		obfsParam:     obfsParam,
	}

	return protocolInstance, nil
}

// Connect 连接到目标地址（通过ShadowsocksR）
func (srp *ShadowsocksRProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 连接到ShadowsocksR服务器
	ssrAddr := fmt.Sprintf("%s:%d", srp.server, srp.port)
	conn, err := net.DialTimeout("tcp", ssrAddr, 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to ShadowsocksR server %s: %v", ssrAddr, err)
	}

	// TODO: 实现ShadowsocksR协议握手逻辑
	// 这里简化实现，直接返回连接

	return conn, nil
}

// Close 关闭连接
func (srp *ShadowsocksRProtocol) Close() error {
	// ShadowsocksR协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (srp *ShadowsocksRProtocol) IsRunning() bool {
	// ShadowsocksR协议运行状态检查
	return true
}
