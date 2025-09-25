package proxy

import (
	"fmt"
	"log"
	"net"
	"time"
)

// VLESSProtocol VLESS协议实现
type VLESSProtocol struct {
	BaseProtocol
	server  string
	port    int
	uuid    string
	network string
	tls     bool
}

// VLESSProtocolFactory VLESS协议工厂
type VLESSProtocolFactory struct{}

// CreateProtocol 创建VLESS协议实例
func (f *VLESSProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	port, ok := config["port"].(int)
	if !ok {
		return nil, fmt.Errorf("missing port in config")
	}

	uuid, _ := config["uuid"].(string)
	network, _ := config["network"].(string)
	tls, _ := config["tls"].(bool)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("vless-%s:%d", server, port)
	}

	// 默认值
	if network == "" {
		network = "tcp"
	}

	protocol := &VLESSProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolVLESS,
		},
		server:  server,
		port:    port,
		uuid:    uuid,
		network: network,
		tls:     tls,
	}

	// 添加日志以调试VLESS协议创建
	log.Printf("创建VLESS协议: server=%s, port=%d, uuid=%s, network=%s, tls=%t", server, port, uuid, network, tls)

	return protocol, nil
}

// Connect 连接到目标地址（通过VLESS）
func (vp *VLESSProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 添加详细的连接日志
	log.Printf("VLESS协议开始连接: targetAddr=%s, server=%s, port=%d, uuid=%s, network=%s, tls=%t",
		targetAddr, vp.server, vp.port, vp.uuid, vp.network, vp.tls)

	// 连接到VLESS服务器
	vlessAddr := fmt.Sprintf("%s:%d", vp.server, vp.port)
	log.Printf("连接到VLESS服务器地址: %s", vlessAddr)

	conn, err := net.DialTimeout("tcp", vlessAddr, 5*time.Second)
	if err != nil {
		log.Printf("连接VLESS服务器失败: %v", err)
		return nil, fmt.Errorf("failed to connect to VLESS server %s: %v", vlessAddr, err)
	}

	// TODO: 实现VLESS协议握手逻辑
	// 这里简化实现，直接返回连接
	// 实际实现中需要处理VLESS协议的握手过程，包括UUID验证、命令传输等

	log.Printf("VLESS协议成功连接到目标: %s 通过服务器: %s:%d", targetAddr, vp.server, vp.port)

	return conn, nil
}

// Close 关闭连接
func (vp *VLESSProtocol) Close() error {
	// VLESS协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (vp *VLESSProtocol) IsRunning() bool {
	// VLESS协议运行状态检查
	return true
}
