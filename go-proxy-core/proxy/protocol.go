package proxy

import (
	"fmt"
	"log"
	"net"
)

// ProtocolType 协议类型
type ProtocolType string

const (
	ProtocolOpenVPN      ProtocolType = "openvpn"
	ProtocolWireGuard    ProtocolType = "wireguard"
	ProtocolIPsec        ProtocolType = "ipsec"
	ProtocolL2TP         ProtocolType = "l2tp"
	ProtocolPPTP         ProtocolType = "pptp"
	ProtocolShadowsocks  ProtocolType = "shadowsocks"
	ProtocolShadowsocksR ProtocolType = "shadowsocksr"
	ProtocolVMess        ProtocolType = "vmess"
	ProtocolTrojan       ProtocolType = "trojan"
	ProtocolSnell        ProtocolType = "snell"
	ProtocolIKEv2        ProtocolType = "ikev2"
	ProtocolSoftEther    ProtocolType = "softether"
	ProtocolHTTP         ProtocolType = "http"
	ProtocolHTTPS        ProtocolType = "https"
	ProtocolSOCKS5       ProtocolType = "socks5"
	ProtocolDIRECT       ProtocolType = "direct"
	ProtocolVLESS        ProtocolType = "vless" // 添加VLESS协议类型
)

// ProxyProtocol 代理协议接口
type ProxyProtocol interface {
	// Type 返回协议类型
	Type() ProtocolType

	// Name 返回协议名称
	Name() string

	// Connect 连接到目标地址
	Connect(targetAddr string) (net.Conn, error)

	// Close 关闭连接
	Close() error

	// IsRunning 检查协议是否正在运行
	IsRunning() bool
}

// BaseProtocol 基础协议结构
type BaseProtocol struct {
	name         string
	protocolType ProtocolType
}

// Type 返回协议类型
func (bp *BaseProtocol) Type() ProtocolType {
	return bp.protocolType
}

// Name 返回协议名称
func (bp *BaseProtocol) Name() string {
	return bp.name
}

// Close 关闭连接
func (bp *BaseProtocol) Close() error {
	// 基础实现，子类可以覆盖
	return nil
}

// IsRunning 检查协议是否正在运行
func (bp *BaseProtocol) IsRunning() bool {
	// 基础实现，子类可以覆盖
	return true
}

// ProtocolFactory 协议工厂接口
type ProtocolFactory interface {
	// CreateProtocol 创建协议实例
	CreateProtocol(config map[string]interface{}) (ProxyProtocol, error)
}

// ProtocolManager 协议管理器
type ProtocolManager struct {
	protocols map[string]ProxyProtocol
	factories map[ProtocolType]ProtocolFactory
}

// NewProtocolManager 创建新的协议管理器
func NewProtocolManager() *ProtocolManager {
	log.Printf("创建新的协议管理器")
	return &ProtocolManager{
		protocols: make(map[string]ProxyProtocol),
		factories: make(map[ProtocolType]ProtocolFactory),
	}
}

// RegisterFactory 注册协议工厂
func (pm *ProtocolManager) RegisterFactory(protocolType ProtocolType, factory ProtocolFactory) {
	log.Printf("注册协议工厂: type=%s", protocolType)
	pm.factories[protocolType] = factory
}

// CreateProtocol 创建协议实例
func (pm *ProtocolManager) CreateProtocol(protocolType ProtocolType, name string, config map[string]interface{}) (ProxyProtocol, error) {
	log.Printf("尝试创建协议: type=%s, name=%s", protocolType, name)

	factory, exists := pm.factories[protocolType]
	if !exists {
		log.Printf("不支持的协议类型: %s", protocolType)
		return nil, fmt.Errorf("unsupported protocol type: %s", protocolType)
	}

	protocol, err := factory.CreateProtocol(config)
	if err != nil {
		log.Printf("创建协议 %s 失败: %v", protocolType, err)
		return nil, fmt.Errorf("failed to create protocol %s: %v", protocolType, err)
	}

	// 将协议添加到管理器中
	pm.protocols[name] = protocol

	// 添加日志以调试协议创建过程
	log.Printf("成功创建并注册协议: name=%s, type=%s", name, protocolType)

	return protocol, nil
}

// GetProtocol 获取协议实例
func (pm *ProtocolManager) GetProtocol(name string) ProxyProtocol {
	log.Printf("获取协议: name=%s", name)
	return pm.protocols[name]
}

// RemoveProtocol 移除协议实例
func (pm *ProtocolManager) RemoveProtocol(name string) {
	log.Printf("移除协议: name=%s", name)
	delete(pm.protocols, name)
}

// GetAllProtocols 获取所有协议实例
func (pm *ProtocolManager) GetAllProtocols() map[string]ProxyProtocol {
	log.Printf("获取所有协议，数量: %d", len(pm.protocols))
	return pm.protocols
}

// Connect 通过指定协议连接到目标地址
func (pm *ProtocolManager) Connect(protocolName, targetAddr string) (net.Conn, error) {
	log.Printf("协议管理器尝试通过协议 %s 连接到目标 %s", protocolName, targetAddr)

	protocol, exists := pm.protocols[protocolName]
	if !exists {
		// 尝试查找相似名称的协议
		log.Printf("协议 %s 未找到，尝试查找相似名称的协议", protocolName)
		for name, p := range pm.protocols {
			log.Printf("可用协议: %s (%s)", name, p.Type())
		}
		return nil, fmt.Errorf("protocol %s not found", protocolName)
	}

	conn, err := protocol.Connect(targetAddr)
	if err != nil {
		log.Printf("协议 %s 连接到目标 %s 失败: %v", protocolName, targetAddr, err)
		return nil, err
	}

	log.Printf("协议 %s 成功连接到目标 %s", protocolName, targetAddr)
	return conn, nil
}
