package proxy

import (
	"fmt"
	"log"
	"net"

	"github.com/dualvpn/go-proxy-core/openvpn"
)

// OpenVPNProtocol OpenVPN协议实现
type OpenVPNProtocol struct {
	BaseProtocol
	server     string
	port       int
	username   string
	password   string
	configPath string                 // OpenVPN配置文件路径
	client     *openvpn.OpenVPNClient // 使用内部OpenVPN客户端
}

// OpenVPNProtocolFactory OpenVPN协议工厂
type OpenVPNProtocolFactory struct{}

// CreateProtocol 创建OpenVPN协议实例
func (f *OpenVPNProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
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
	configPath, _ := config["config_path"].(string)
	name, _ := config["name"].(string)

	// 检查是否有特权助手处理后的配置文件路径
	processedConfigPath, _ := config["processed_config_path"].(string)

	if name == "" {
		name = fmt.Sprintf("openvpn-%s:%d", server, port)
	}

	// 创建OpenVPN客户端
	var client *openvpn.OpenVPNClient
	if processedConfigPath != "" {
		// 使用特权助手处理后的配置文件路径
		client = openvpn.NewOpenVPNClient(processedConfigPath, server, port, 0)
		// 设置特权助手处理后的配置文件路径
		client.SetHelperConfigPath(processedConfigPath)
		log.Printf("使用特权助手处理后的配置文件: %s", processedConfigPath)
	} else {
		// 使用原始配置文件路径
		client = openvpn.NewOpenVPNClient(configPath, server, port, 0)
		log.Printf("使用原始配置文件: %s", configPath)
	}

	protocol := &OpenVPNProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolOpenVPN,
		},
		server:     server,
		port:       port,
		username:   username,
		password:   password,
		configPath: configPath,
		client:     client,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过OpenVPN）
func (op *OpenVPNProtocol) Connect(targetAddr string) (net.Conn, error) {
	log.Printf("OpenVPN协议开始连接: targetAddr=%s, server=%s, port=%d, configPath=%s", targetAddr, op.server, op.port, op.configPath)

	// 如果OpenVPN客户端尚未启动，则启动它
	if op.client == nil {
		log.Printf("OpenVPN客户端未正确初始化")
		return nil, fmt.Errorf("OpenVPN客户端未正确初始化")
	}

	log.Printf("OpenVPN客户端已存在，检查是否正在运行")
	// 检查OpenVPN客户端是否正在运行
	if !op.client.IsRunning() {
		log.Printf("OpenVPN客户端未运行，重新启动")
		// 重新设置凭据
		op.client.SetCredentials(op.username, op.password)

		if err := op.client.Start(); err != nil {
			log.Printf("重新启动OpenVPN客户端失败: %v", err)
			return nil, fmt.Errorf("failed to restart OpenVPN client: %v", err)
		}
		log.Printf("OpenVPN客户端重新启动成功")
	} else {
		log.Printf("OpenVPN客户端已在运行")
	}

	// 确保OpenVPN客户端已完全初始化
	if op.client == nil {
		log.Printf("OpenVPN客户端未正确初始化")
		return nil, fmt.Errorf("OpenVPN客户端未正确初始化")
	}

	// 通过OpenVPN客户端连接到目标地址
	// 这会检查隧道是否就绪并正确处理连接
	log.Printf("通过OpenVPN客户端连接到目标: %s", targetAddr)
	conn, err := op.client.ConnectToTarget(targetAddr)
	if err != nil {
		log.Printf("通过OpenVPN客户端连接到目标失败: %v", err)
		return nil, fmt.Errorf("failed to connect to target %s through OpenVPN client: %v", targetAddr, err)
	}

	log.Printf("成功通过OpenVPN客户端连接到目标: %s", targetAddr)
	return conn, nil
}

// Close 关闭连接
func (op *OpenVPNProtocol) Close() error {
	log.Printf("关闭OpenVPN协议: %s", op.Name())
	// 关闭OpenVPN客户端
	if op.client != nil {
		log.Printf("停止OpenVPN客户端")
		if err := op.client.Stop(); err != nil {
			log.Printf("停止OpenVPN客户端时出错: %v", err)
			return err
		}
		log.Printf("OpenVPN客户端已停止")
		return nil
	}
	return nil
}

// IsRunning 检查协议是否正在运行
func (op *OpenVPNProtocol) IsRunning() bool {
	if op.client != nil {
		return op.client.IsRunning()
	}
	return false
}
