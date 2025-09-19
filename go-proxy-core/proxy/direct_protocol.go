package proxy

import (
	"fmt"
	"net"
	"time"
)

// DirectProtocol 直连协议实现
type DirectProtocol struct {
	BaseProtocol
}

// DirectProtocolFactory 直连协议工厂
type DirectProtocolFactory struct{}

// CreateProtocol 创建直连协议实例
func (f *DirectProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	name, _ := config["name"].(string)

	if name == "" {
		name = "direct"
	}

	protocol := &DirectProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolDIRECT,
		},
	}

	return protocol, nil
}

// Connect 直接连接到目标地址
func (dp *DirectProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 直接连接到目标地址
	conn, err := net.DialTimeout("tcp", targetAddr, 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to target %s: %v", targetAddr, err)
	}

	return conn, nil
}

// Close 关闭连接
func (dp *DirectProtocol) Close() error {
	// 直连协议不需要特殊关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (dp *DirectProtocol) IsRunning() bool {
	// 直连协议总是认为在运行
	return true
}
