package config

import (
	"os"

	"gopkg.in/yaml.v3"
)

// Config 代理核心配置
type Config struct {
	HTTPPort    int    `yaml:"http_port"`
	Socks5Port  int    `yaml:"socks5_port"`
	APIPort     int    `yaml:"api_port"`
	OpenVPNPort int    `yaml:"openvpn_port"`
	DNSPort     int    `yaml:"dns_port"`
	DNSType     string `yaml:"dns_type"` // "fakeip" or "doh"
	DoHServer   string `yaml:"doh_server"`
	// 移除Clash相关的端口配置，因为不再需要特定的Clash实现
	// 移除RulesFile字段，因为规则将通过API动态配置
	LogLevel string `yaml:"log_level"`
}

// LoadConfig 从文件加载配置
func LoadConfig(filename string) (*Config, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}

// DefaultConfig 返回默认配置
func DefaultConfig() *Config {
	return &Config{
		HTTPPort:    6160,
		Socks5Port:  6161,
		APIPort:     6162,
		OpenVPNPort: 1080,
		DNSPort:     53,
		DNSType:     "fakeip",
		DoHServer:   "https://1.1.1.1/dns-query",
		// 移除Clash相关的端口配置
		// 移除RulesFile字段
		LogLevel: "info",
	}
}
