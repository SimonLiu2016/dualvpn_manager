package main

import (
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
)

func main() {
	// 创建Unix域套接字监听器
	socketPath := "/var/run/dualvpn_openvpn_helper.sock"

	// 删除已存在的套接字文件
	if err := os.RemoveAll(socketPath); err != nil {
		log.Printf("警告: 无法删除已存在的套接字文件: %v", err)
	}

	// 创建Unix域套接字监听器
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		log.Fatalf("无法创建Unix域套接字监听器: %v", err)
	}
	defer listener.Close()

	// 设置套接字权限，允许所有用户连接
	if err := os.Chmod(socketPath, 0666); err != nil {
		log.Printf("警告: 无法设置套接字权限: %v", err)
	}

	log.Printf("特权助手工具已启动，监听套接字: %s", socketPath)

	// 接受连接
	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("接受连接时出错: %v", err)
			continue
		}

		// 处理连接
		go handleConnection(conn)
	}
}

func handleConnection(conn net.Conn) {
	defer conn.Close()

	log.Printf("新连接建立: %s", conn.RemoteAddr())

	// 读取命令
	buffer := make([]byte, 1024)
	n, err := conn.Read(buffer)
	if err != nil {
		log.Printf("读取命令时出错: %v", err)
		return
	}

	command := string(buffer[:n])
	log.Printf("收到命令: %s", command)

	// 解析命令
	switch command {
	case "create_tun":
		// 创建TUN设备
		err := createTUNDevice()
		if err != nil {
			log.Printf("创建TUN设备失败: %v", err)
			conn.Write([]byte(fmt.Sprintf("error: %v", err)))
		} else {
			log.Printf("TUN设备创建成功")
			conn.Write([]byte("success"))
		}
	default:
		log.Printf("未知命令: %s", command)
		conn.Write([]byte("error: unknown command"))
	}
}

func createTUNDevice() error {
	// 在macOS上，我们可以通过尝试创建TUN设备来验证权限
	// 这里我们简单地检查是否有权限执行ifconfig命令
	cmd := exec.Command("ifconfig", "-l")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("无法执行ifconfig命令: %v", err)
	}

	log.Printf("成功验证网络接口权限")
	return nil
}
