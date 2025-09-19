package main

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

func main() {
	// 设置HTTP客户端使用代理
	proxyURL, _ := url.Parse("http://127.0.0.1:6160")
	client := &http.Client{
		Transport: &http.Transport{
			Proxy: http.ProxyURL(proxyURL), // 使用HTTP代理
		},
		Timeout: 30 * time.Second,
	}

	// 持续发送HTTP请求以产生流量
	for i := 0; i < 20; i++ {
		fmt.Printf("发送第 %d 个请求...\n", i+1)

		resp, err := client.Get("http://httpbin.org/get")
		if err != nil {
			fmt.Printf("请求失败: %v\n", err)
			continue
		}

		// 读取响应内容
		_, err = io.ReadAll(resp.Body)
		resp.Body.Close()

		if err != nil {
			fmt.Printf("读取响应失败: %v\n", err)
			continue
		}

		fmt.Printf("请求成功\n")
		time.Sleep(2 * time.Second)
	}

	fmt.Println("测试完成")
}
