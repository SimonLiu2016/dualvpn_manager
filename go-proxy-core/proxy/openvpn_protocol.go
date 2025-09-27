package proxy

import (
	"fmt"
	"log"
	"net"
	"sync"
	"time"

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
	socksPort  int
}

// 用于跟踪已使用的SOCKS端口
var (
	socksPortMutex sync.Mutex
	socksPortPool  = make(map[int]bool)
	nextSocksPort  = 1080 // 从1080开始分配端口
)

// 获取可用的SOCKS端口
func getAvailableSocksPort() int {
	socksPortMutex.Lock()
	defer socksPortMutex.Unlock()

	// 查找可用的端口
	for {
		// 检查端口是否已被使用
		if !socksPortPool[nextSocksPort] {
			// 检查端口是否真的可用
			addr := fmt.Sprintf("127.0.0.1:%d", nextSocksPort)
			if listener, err := net.Listen("tcp", addr); err == nil {
				listener.Close()
				socksPortPool[nextSocksPort] = true
				port := nextSocksPort
				nextSocksPort++
				if nextSocksPort > 65535 {
					nextSocksPort = 1080 // 重新从1080开始
				}
				return port
			}
		}
		nextSocksPort++
		if nextSocksPort > 65535 {
			nextSocksPort = 1080 // 重新从1080开始
		}
	}
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

	if name == "" {
		name = fmt.Sprintf("openvpn-%s:%d", server, port)
	}

	// 使用动态分配的SOCKS端口
	socksPort := getAvailableSocksPort()

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
		socksPort:  socksPort,
	}

	return protocol, nil
}

// Connect 连接到目标地址（通过OpenVPN）
func (op *OpenVPNProtocol) Connect(targetAddr string) (net.Conn, error) {
	log.Printf("OpenVPN协议开始连接: targetAddr=%s, server=%s, port=%d, configPath=%s, socksPort=%d", targetAddr, op.server, op.port, op.configPath, op.socksPort)

	// 如果OpenVPN客户端尚未启动，则启动它
	if op.client == nil {
		log.Printf("创建并启动OpenVPN客户端: configPath=%s, server=%s, port=%d, socksPort=%d", op.configPath, op.server, op.port, op.socksPort)
		// 创建并启动OpenVPN客户端
		op.client = openvpn.NewOpenVPNClient(op.configPath, op.server, op.port, op.socksPort)
		// 设置凭据
		op.client.SetCredentials(op.username, op.password)

		if err := op.client.Start(); err != nil {
			log.Printf("启动OpenVPN客户端失败: %v", err)
			return nil, fmt.Errorf("failed to start OpenVPN client: %v", err)
		}
		log.Printf("OpenVPN客户端启动成功")
	} else {
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
	}

	// 确保OpenVPN客户端已完全初始化
	if op.client == nil {
		log.Printf("OpenVPN客户端未正确初始化")
		return nil, fmt.Errorf("OpenVPN客户端未正确初始化")
	}

	// 通过OpenVPN客户端连接到目标地址
	// 这里会通过SOCKS代理连接，确保流量通过OpenVPN隧道传输
	log.Printf("通过OpenVPN客户端连接到目标: %s", targetAddr)

	// 增加重试机制，确保连接成功
	var conn net.Conn
	var err error
	for i := 0; i < 3; i++ {
		log.Printf("第%d次尝试通过OpenVPN连接到目标: %s", i+1, targetAddr)
		// 设置连接超时时间
		conn, err = op.client.ConnectToTarget(targetAddr)
		if err == nil {
			log.Printf("第%d次尝试通过OpenVPN连接到目标成功", i+1)
			break
		}
		log.Printf("第%d次尝试通过OpenVPN连接到目标失败: %v，等待1秒后重试", i+1, err)
		time.Sleep(1 * time.Second)
	}

	if err != nil {
		log.Printf("通过OpenVPN连接到目标失败: %v", err)
		return nil, fmt.Errorf("failed to connect to target %s through OpenVPN: %v", targetAddr, err)
	}

	log.Printf("成功通过OpenVPN连接到目标: %s", targetAddr)
	return conn, nil
}

// Close 关闭连接
func (op *OpenVPNProtocol) Close() error {
	// 关闭OpenVPN客户端
	if op.client != nil {
		// 释放SOCKS端口
		socksPortMutex.Lock()
		delete(socksPortPool, op.socksPort)
		socksPortMutex.Unlock()

		return op.client.Stop()
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
