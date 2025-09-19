package dns

import (
	"fmt"
	"log"
	"net"

	"github.com/miekg/dns"
)

// DNSServer DNS服务器
type DNSServer struct {
	port    int
	dnsType string // "fakeip" or "doh"
	dohURL  string
	server  *dns.Server
	running bool
}

// NewDNSServer 创建新的DNS服务器
func NewDNSServer(port int, dnsType, dohURL string) *DNSServer {
	return &DNSServer{
		port:    port,
		dnsType: dnsType,
		dohURL:  dohURL,
	}
}

// Start 启动DNS服务器
func (ds *DNSServer) Start() error {
	if ds.running {
		return nil
	}

	// 注册DNS处理器
	dns.HandleFunc(".", ds.handleDNSRequest)

	// 创建DNS服务器
	addr := fmt.Sprintf("127.0.0.1:%d", ds.port)
	server := &dns.Server{
		Addr: addr,
		Net:  "udp",
	}

	ds.server = server
	ds.running = true

	log.Printf("DNS server listening on %s", addr)

	// 启动服务器
	go func() {
		if err := server.ListenAndServe(); err != nil {
			log.Printf("DNS server error: %v", err)
		}
	}()

	return nil
}

// Stop 停止DNS服务器
func (ds *DNSServer) Stop() error {
	if !ds.running || ds.server == nil {
		return nil
	}

	if err := ds.server.Shutdown(); err != nil {
		return fmt.Errorf("failed to shutdown DNS server: %v", err)
	}

	ds.running = false
	log.Println("DNS server stopped")

	return nil
}

// handleDNSRequest 处理DNS请求
func (ds *DNSServer) handleDNSRequest(w dns.ResponseWriter, r *dns.Msg) {
	// 创建响应消息
	msg := new(dns.Msg)
	msg.SetReply(r)
	msg.Authoritative = true

	// 处理每个问题
	for _, question := range r.Question {
		switch question.Qtype {
		case dns.TypeA:
			// A记录查询
			record := new(dns.A)
			record.Hdr = dns.RR_Header{
				Name:   question.Name,
				Rrtype: dns.TypeA,
				Class:  dns.ClassINET,
				Ttl:    300, // 5分钟TTL
			}

			// 根据DNS类型返回不同结果
			if ds.dnsType == "fakeip" {
				// Fake-IP模式：返回虚假IP地址
				record.A = net.ParseIP("198.18.0.1")
			} else {
				// DoH模式：实际解析（简化实现）
				record.A = net.ParseIP("127.0.0.1")
			}

			msg.Answer = append(msg.Answer, record)
		}
	}

	// 发送响应
	if err := w.WriteMsg(msg); err != nil {
		log.Printf("Failed to write DNS response: %v", err)
	}
}

// IsRunning 检查DNS服务器是否正在运行
func (ds *DNSServer) IsRunning() bool {
	return ds.running
}
