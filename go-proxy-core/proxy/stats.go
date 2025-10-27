package proxy

import (
	"net"
	"sync/atomic"
	"time"
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
	// 实时速率跟踪
	lastUpload   uint64
	lastDownload uint64
	uploadRate   uint64
	downloadRate uint64
	lastUpdate   time.Time
}

// NewProxySourceStatsCollector 创建新的代理源统计信息收集器
func NewProxySourceStatsCollector(proxySourceId string, core *ProxyCore) *ProxySourceStatsCollector {
	collector := &ProxySourceStatsCollector{
		proxySourceId: proxySourceId,
		core:          core,
		lastUpdate:    time.Now(),
	}

	// 启动速率更新协程
	go collector.updateRates()

	return collector
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
	if httpServer := pssc.core.GetHTTPServer(); httpServer != nil {
		atomic.AddUint64(&httpServer.totalUpload, bytes)
	}
	if socks5Server := pssc.core.GetSOCKS5Server(); socks5Server != nil {
		atomic.AddUint64(&socks5Server.totalUpload, bytes)
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
	if httpServer := pssc.core.GetHTTPServer(); httpServer != nil {
		atomic.AddUint64(&httpServer.totalDownload, bytes)
	}
	if socks5Server := pssc.core.GetSOCKS5Server(); socks5Server != nil {
		atomic.AddUint64(&socks5Server.totalDownload, bytes)
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

// GetUploadRate 获取上传速率（字节/秒）
func (pssc *ProxySourceStatsCollector) GetUploadRate() uint64 {
	return atomic.LoadUint64(&pssc.uploadRate)
}

// GetDownloadRate 获取下载速率（字节/秒）
func (pssc *ProxySourceStatsCollector) GetDownloadRate() uint64 {
	return atomic.LoadUint64(&pssc.downloadRate)
}

// updateRates 定期更新速率计算
func (pssc *ProxySourceStatsCollector) updateRates() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			currentUpload := atomic.LoadUint64(&pssc.upload)
			currentDownload := atomic.LoadUint64(&pssc.download)

			// 原子地获取并更新lastUpload和lastDownload
			oldLastUpload := atomic.LoadUint64(&pssc.lastUpload)
			oldLastDownload := atomic.LoadUint64(&pssc.lastDownload)

			// 尝试原子更新lastUpload和lastDownload
			if !atomic.CompareAndSwapUint64(&pssc.lastUpload, oldLastUpload, currentUpload) {
				// 如果更新失败，重新获取当前值
				oldLastUpload = atomic.LoadUint64(&pssc.lastUpload)
			}

			if !atomic.CompareAndSwapUint64(&pssc.lastDownload, oldLastDownload, currentDownload) {
				// 如果更新失败，重新获取当前值
				oldLastDownload = atomic.LoadUint64(&pssc.lastDownload)
			}

			// 计算每秒速率
			uploadDiff := currentUpload - oldLastUpload
			downloadDiff := currentDownload - oldLastDownload

			atomic.StoreUint64(&pssc.uploadRate, uploadDiff)
			atomic.StoreUint64(&pssc.downloadRate, downloadDiff)

			pssc.lastUpdate = time.Now()
		}
	}
}
