package proxy

import (
	"fmt"
	"log"
	"runtime"

	"github.com/songgao/water"
)

// TUNDevice TUN设备
type TUNDevice struct {
	device *water.Interface
	config *water.Config
}

// NewTUNDevice 创建新的TUN设备
func NewTUNDevice() (*TUNDevice, error) {
	// 配置TUN设备
	config := water.Config{
		DeviceType: water.TUN,
	}

	// 根据操作系统设置特定配置
	switch runtime.GOOS {
	case "darwin":
		// macOS使用utun设备
		// water库会自动选择可用的utun设备
	case "windows":
		// Windows需要Wintun驱动
		// 这里需要实现Wintun集成
		log.Println("Warning: Windows TUN implementation requires Wintun driver")
	case "linux":
		// Linux使用默认TUN设备
	default:
		return nil, fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}

	// 创建TUN接口
	device, err := water.New(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create TUN device: %v", err)
	}

	return &TUNDevice{
		device: device,
		config: &config,
	}, nil
}

// Start 启动TUN设备
func (tun *TUNDevice) Start() error {
	if tun.device == nil {
		return fmt.Errorf("TUN device not initialized")
	}

	log.Printf("TUN device started: %s", tun.device.Name())

	// 启动数据包处理循环
	go tun.packetHandler()

	return nil
}

// Stop 停止TUN设备
func (tun *TUNDevice) Stop() error {
	if tun.device != nil {
		if err := tun.device.Close(); err != nil {
			return fmt.Errorf("failed to close TUN device: %v", err)
		}
		log.Println("TUN device stopped")
	}

	return nil
}

// packetHandler 处理数据包
func (tun *TUNDevice) packetHandler() {
	buffer := make([]byte, 65535)

	for {
		// 读取数据包
		n, err := tun.device.Read(buffer)
		if err != nil {
			log.Printf("Error reading from TUN device: %v", err)
			break
		}

		// 处理数据包
		tun.handlePacket(buffer[:n])
	}
}

// handlePacket 处理单个数据包
func (tun *TUNDevice) handlePacket(packet []byte) {
	// 这里需要实现数据包解析和路由逻辑
	// 简化实现，只记录日志
	log.Printf("Received packet of %d bytes", len(packet))

	// TODO: 实现完整的数据包解析和路由逻辑
	// 1. 解析IP头部
	// 2. 提取目标地址
	// 3. 根据路由规则决定转发目标
	// 4. 转发到相应的代理（Clash、OpenVPN或直连）
}

// GetDeviceName 获取设备名称
func (tun *TUNDevice) GetDeviceName() string {
	if tun.device != nil {
		return tun.device.Name()
	}
	return ""
}
