package config

// Rule 路由规则
type Rule struct {
	Type        string `yaml:"type" json:"type"`                 // "DOMAIN", "IP-CIDR", "MATCH"
	Pattern     string `yaml:"pattern" json:"pattern"`           // 匹配模式
	ProxySource string `yaml:"proxy_source" json:"proxy_source"` // 代理源: "clash", "openvpn", "DIRECT"
	Enabled     bool   `yaml:"enabled" json:"enabled"`           // 是否启用
}

// RulesConfig 规则配置
type RulesConfig struct {
	Rules []Rule `yaml:"rules" json:"rules"`
}

// DefaultRules 返回默认路由规则
func DefaultRules() *RulesConfig {
	return &RulesConfig{
		Rules: []Rule{
			// 优先匹配特定域名到OpenVPN代理源
			{Type: "DOMAIN", Pattern: "pingcode.ctf.com.cn", ProxySource: "openvpn-source", Enabled: true},
			// 其他规则...
			{Type: "MATCH", Pattern: "", ProxySource: "DIRECT", Enabled: true},
		},
	}
}
