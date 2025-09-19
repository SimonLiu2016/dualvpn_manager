package proxy

import (
	"net"
	"sync/atomic"
)

// StatsCollector 统计信息收集器接口
type StatsCollector interface {
	AddUpload(bytes uint64)
	AddDownload(bytes uint64)
}

// StatsConn 带统计信息的连接包装器
type StatsConn struct {
	net.Conn
	collector StatsCollector
}

// Read 读取数据并统计
func (sc *StatsConn) Read(b []byte) (n int, err error) {
	n, err = sc.Conn.Read(b)
	if n > 0 {
		sc.collector.AddDownload(uint64(n))
	}
	return n, err
}

// Write 写入数据并统计
func (sc *StatsConn) Write(b []byte) (n int, err error) {
	n, err = sc.Conn.Write(b)
	if n > 0 {
		sc.collector.AddUpload(uint64(n))
	}
	return n, err
}

// HTTPServerStats HTTP服务器统计信息实现
type HTTPServerStats struct {
	server *HTTPServer
}

// AddUpload 增加上传字节数
func (hss *HTTPServerStats) AddUpload(bytes uint64) {
	atomic.AddUint64(&hss.server.totalUpload, bytes)
}

// AddDownload 增加下载字节数
func (hss *HTTPServerStats) AddDownload(bytes uint64) {
	atomic.AddUint64(&hss.server.totalDownload, bytes)
}

// SOCKS5ServerStats SOCKS5服务器统计信息实现
type SOCKS5ServerStats struct {
	server *SOCKS5Server
}

// AddUpload 增加上传字节数
func (sss *SOCKS5ServerStats) AddUpload(bytes uint64) {
	atomic.AddUint64(&sss.server.totalUpload, bytes)
}

// AddDownload 增加下载字节数
func (sss *SOCKS5ServerStats) AddDownload(bytes uint64) {
	atomic.AddUint64(&sss.server.totalDownload, bytes)
}
