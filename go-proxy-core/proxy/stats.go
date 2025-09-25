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

// DirectionalStatsConn 自定义流量统计连接，正确区分上传和下载
type DirectionalStatsConn struct {
	net.Conn
	collector *ProxySourceStatsCollector
	// isClientSide=true表示这是客户端侧的连接
	// isClientSide=false表示这是目标服务器侧的连接
	isClientSide bool
}

// Read 读取数据并统计
func (sc *DirectionalStatsConn) Read(b []byte) (n int, err error) {
	n, err = sc.Conn.Read(b)
	if n > 0 {
		// 从连接读取数据：
		// 如果这是客户端侧连接，读取的是客户端发送的数据，应计为上传
		// 如果这是目标服务器侧连接，读取的是目标服务器发送的数据，应计为下载
		if sc.isClientSide {
			sc.collector.AddUpload(uint64(n))
		} else {
			sc.collector.AddDownload(uint64(n))
		}
	}
	return n, err
}

// Write 写入数据并统计
func (sc *DirectionalStatsConn) Write(b []byte) (n int, err error) {
	n, err = sc.Conn.Write(b)
	if n > 0 {
		// 向连接写入数据：
		// 如果这是客户端侧连接，写入的是客户端接收的数据，应计为下载
		// 如果这是目标服务器侧连接，写入的是目标服务器接收的数据，应计为上传
		if sc.isClientSide {
			sc.collector.AddDownload(uint64(n))
		} else {
			sc.collector.AddUpload(uint64(n))
		}
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

// ProxySourceStatsCollector 按代理源维度的统计信息收集器
type ProxySourceStatsCollector struct {
	proxySourceId string
	core          *ProxyCore
	upload        uint64
	download      uint64
}

// NewProxySourceStatsCollector 创建新的代理源统计信息收集器
func NewProxySourceStatsCollector(proxySourceId string, core *ProxyCore) *ProxySourceStatsCollector {
	return &ProxySourceStatsCollector{
		proxySourceId: proxySourceId,
		core:          core,
	}
}

// AddUpload 增加上传字节数
func (pssc *ProxySourceStatsCollector) AddUpload(bytes uint64) {
	atomic.AddUint64(&pssc.upload, bytes)

	// 更新对应代理源的当前代理的统计信息
	pssc.core.proxySourceMu.Lock()
	if proxyInfo, exists := pssc.core.currentProxies[pssc.proxySourceId]; exists && proxyInfo.Stats != nil {
		atomic.AddUint64(&proxyInfo.Stats.Upload, bytes)
	}
	pssc.core.proxySourceMu.Unlock()

	// 同时更新服务器总统计
	if pssc.core.httpServer != nil {
		atomic.AddUint64(&pssc.core.httpServer.totalUpload, bytes)
	}
	if pssc.core.socks5Server != nil {
		atomic.AddUint64(&pssc.core.socks5Server.totalUpload, bytes)
	}
}

// AddDownload 增加下载字节数
func (pssc *ProxySourceStatsCollector) AddDownload(bytes uint64) {
	atomic.AddUint64(&pssc.download, bytes)

	// 更新对应代理源的当前代理的统计信息
	pssc.core.proxySourceMu.Lock()
	if proxyInfo, exists := pssc.core.currentProxies[pssc.proxySourceId]; exists && proxyInfo.Stats != nil {
		atomic.AddUint64(&proxyInfo.Stats.Download, bytes)
	}
	pssc.core.proxySourceMu.Unlock()

	// 同时更新服务器总统计
	if pssc.core.httpServer != nil {
		atomic.AddUint64(&pssc.core.httpServer.totalDownload, bytes)
	}
	if pssc.core.socks5Server != nil {
		atomic.AddUint64(&pssc.core.socks5Server.totalDownload, bytes)
	}
}

// GetUpload 获取上传字节数
func (pssc *ProxySourceStatsCollector) GetUpload() uint64 {
	return atomic.LoadUint64(&pssc.upload)
}

// GetDownload 获取下载字节数
func (pssc *ProxySourceStatsCollector) GetDownload() uint64 {
	return atomic.LoadUint64(&pssc.download)
}
