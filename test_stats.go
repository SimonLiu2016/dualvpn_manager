package main

import (
	"fmt"
	"io"
	"net/http"
	"time"
)

func main() {
	// 启动一个简单的HTTP服务器来模拟流量
	go func() {
		http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			// 模拟一些数据传输
			for i := 0; i < 100; i++ {
				w.Write([]byte("Hello, World! "))
			}
		})
		http.ListenAndServe(":8080", nil)
	}()

	// 等待服务器启动
	time.Sleep(1 * time.Second)

	// 发送一些请求来生成流量
	for i := 0; i < 10; i++ {
		resp, err := http.Get("http://localhost:8080")
		if err != nil {
			fmt.Printf("请求失败: %v\n", err)
			continue
		}
		// 读取响应体
		io.ReadAll(resp.Body)
		resp.Body.Close()
		time.Sleep(500 * time.Millisecond)
	}

	fmt.Println("测试完成")
}
