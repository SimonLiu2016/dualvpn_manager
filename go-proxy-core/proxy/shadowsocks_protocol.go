package proxy

import (
	"fmt"
	"log"
	"net"
	"strconv"
	"time"

	"github.com/shadowsocks/go-shadowsocks2/core"
	"github.com/shadowsocks/go-shadowsocks2/socks"
)

// ShadowsocksProtocol Shadowsocks协议实现
type ShadowsocksProtocol struct {
	BaseProtocol
	server   string
	port     int
	password string
	method   string // 加密方法
	cipher   core.Cipher
}

// ShadowsocksProtocolFactory Shadowsocks协议工厂
type ShadowsocksProtocolFactory struct{}

// CreateProtocol 创建Shadowsocks协议实例
func (f *ShadowsocksProtocolFactory) CreateProtocol(config map[string]interface{}) (ProxyProtocol, error) {
	server, ok := config["server"].(string)
	if !ok {
		return nil, fmt.Errorf("missing server in config")
	}

	var port int
	switch v := config["port"].(type) {
	case int:
		port = v
	case float64:
		port = int(v)
	case string:
		var err error
		port, err = strconv.Atoi(v)
		if err != nil {
			return nil, fmt.Errorf("invalid port format: %v", err)
		}
	default:
		return nil, fmt.Errorf("missing or invalid port in config")
	}

	password, _ := config["password"].(string)
	method, _ := config["method"].(string)
	cipherStr, _ := config["cipher"].(string)
	name, _ := config["name"].(string)

	if name == "" {
		name = fmt.Sprintf("shadowsocks-%s:%d", server, port)
	}

	// 优先使用method，如果没有则使用cipher
	if method == "" && cipherStr != "" {
		method = cipherStr
	}

	// 如果method仍然为空，使用默认值
	if method == "" {
		method = "CHACHA20-IETF-POLY1305" // 默认加密方法
	}

	// 创建加密器
	cipher, err := core.PickCipher(method, nil, password)
	if err != nil {
		return nil, fmt.Errorf("failed to create cipher with method '%s' and password '%s': %v", method, password, err)
	}

	protocol := &ShadowsocksProtocol{
		BaseProtocol: BaseProtocol{
			name:         name,
			protocolType: ProtocolShadowsocks,
		},
		server:   server,
		port:     port,
		password: password,
		method:   method,
		cipher:   cipher,
	}

	// 添加日志以调试Shadowsocks协议创建
	log.Printf("创建Shadowsocks协议: server=%s, port=%d, method=%s, password=%s", server, port, method, password)

	return protocol, nil
}

// Connect 连接到目标地址（通过Shadowsocks）
func (sp *ShadowsocksProtocol) Connect(targetAddr string) (net.Conn, error) {
	// 添加详细的连接日志
	log.Printf("Shadowsocks协议开始连接: targetAddr=%s, server=%s, port=%d, method=%s",
		targetAddr, sp.server, sp.port, sp.method)

	// 连接到Shadowsocks服务器
	ssAddr := fmt.Sprintf("%s:%d", sp.server, sp.port)
	log.Printf("连接到Shadowsocks服务器地址: %s", ssAddr)

	conn, err := net.DialTimeout("tcp", ssAddr, 5*time.Second)
	if err != nil {
		log.Printf("连接Shadowsocks服务器失败: %v", err)
		return nil, fmt.Errorf("failed to connect to Shadowsocks server %s: %v", ssAddr, err)
	}

	// 使用加密器包装连接
	log.Printf("使用加密器包装连接")
	conn = sp.cipher.StreamConn(conn)

	// 解析目标地址
	log.Printf("解析目标地址: %s", targetAddr)
	addr := socks.ParseAddr(targetAddr)
	if addr == nil {
		conn.Close()
		log.Printf("解析目标地址失败: %s", targetAddr)
		return nil, fmt.Errorf("failed to parse target address: %s", targetAddr)
	}

	// 发送目标地址信息
	log.Printf("发送目标地址信息到Shadowsocks服务器")
	if _, err := conn.Write(addr); err != nil {
		conn.Close()
		log.Printf("发送目标地址信息失败: %v", err)
		return nil, fmt.Errorf("failed to send target address: %v", err)
	}

	// 添加日志以调试连接过程
	log.Printf("Shadowsocks协议成功连接到目标: %s 通过服务器: %s:%d", targetAddr, sp.server, sp.port)

	return conn, nil
}

// Close 关闭连接
func (sp *ShadowsocksProtocol) Close() error {
	// Shadowsocks协议关闭逻辑
	return nil
}

// IsRunning 检查协议是否正在运行
func (sp *ShadowsocksProtocol) IsRunning() bool {
	// Shadowsocks协议运行状态检查
	return true
}
