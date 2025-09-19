package main

import (
	"fmt"
	"net/http"
	"time"
)

func main() {
	// 测试API端点
	endpoints := []string{
		"http://127.0.0.1:6162/protocols",
		"http://127.0.0.1:6162/stats",
		"http://127.0.0.1:6162/status",
		"http://127.0.0.1:6162/rules",
	}

	// 等待服务器启动
	time.Sleep(2 * time.Second)

	for _, endpoint := range endpoints {
		fmt.Printf("Testing %s...\n", endpoint)
		resp, err := http.Get(endpoint)
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			continue
		}
		fmt.Printf("Status: %s\n", resp.Status)
		resp.Body.Close()
	}
}
