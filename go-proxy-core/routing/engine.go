package routing

import (
	"log"
	"net"
	"strconv"
	"strings"
	"sync"

	"github.com/dualvpn/go-proxy-core/config"
)

// RulesEngine 路由规则引擎
type RulesEngine struct {
	rules []config.Rule
	mu    sync.RWMutex
}

// NewRulesEngine 创建新的路由规则引擎
func NewRulesEngine() *RulesEngine {
	return &RulesEngine{
		rules: []config.Rule{},
	}
}

// UpdateRules 更新路由规则
func (re *RulesEngine) UpdateRules(rules []config.Rule) {
	re.mu.Lock()
	defer re.mu.Unlock()

	// 添加调试日志
	log.Printf("规则引擎更新规则，新规则数量: %d", len(rules))
	for i, rule := range rules {
		log.Printf("更新规则 %d: Type=%s, Pattern=%s, ProxySource=%s, Enabled=%t",
			i, rule.Type, rule.Pattern, rule.ProxySource, rule.Enabled)
	}

	re.rules = rules
}

// Match 匹配路由规则
func (re *RulesEngine) Match(destination string) string {
	re.mu.RLock()
	defer re.mu.RUnlock()

	log.Printf("开始匹配路由规则，目标地址: %s", destination)

	// 提取主机名部分（去除端口号）
	host := destination
	if colonIndex := strings.LastIndex(destination, ":"); colonIndex != -1 {
		// 确保冒号后面是端口号而不是IPv6地址的一部分
		if colonIndex < len(destination)-1 {
			// 检查冒号后面是否是数字（端口号）
			portPart := destination[colonIndex+1:]
			if _, err := strconv.Atoi(portPart); err == nil {
				host = destination[:colonIndex]
			}
		}
	}

	log.Printf("提取主机名: %s", host)

	// 添加更详细的规则匹配日志
	log.Printf("当前规则数量: %d", len(re.rules))
	for i, rule := range re.rules {
		log.Printf("规则 %d: Type=%s, Pattern=%s, ProxySource=%s, Enabled=%t",
			i, rule.Type, rule.Pattern, rule.ProxySource, rule.Enabled)
	}

	for i, rule := range re.rules {
		if !rule.Enabled {
			log.Printf("跳过禁用规则 %d", i)
			continue
		}

		log.Printf("检查规则 %d: Type=%s, Pattern=%s, ProxySource=%s, Enabled=%t",
			i, rule.Type, rule.Pattern, rule.ProxySource, rule.Enabled)

		switch rule.Type {
		case "DOMAIN":
			if host == rule.Pattern {
				log.Printf("DOMAIN规则匹配成功: %s -> %s", host, rule.ProxySource)
				return rule.ProxySource
			}
		case "DOMAIN-SUFFIX":
			log.Printf("检查DOMAIN-SUFFIX匹配: host=%s, pattern=%s", host, rule.Pattern)
			if strings.HasSuffix(host, rule.Pattern) {
				log.Printf("DOMAIN-SUFFIX规则匹配成功: %s -> %s", host, rule.ProxySource)
				return rule.ProxySource
			}
		case "IP-CIDR":
			log.Printf("检查IP-CIDR匹配: destination=%s, pattern=%s", destination, rule.Pattern)
			if re.matchCIDR(destination, rule.Pattern) {
				log.Printf("IP-CIDR规则匹配成功: %s -> %s", destination, rule.ProxySource)
				return rule.ProxySource
			}
		case "MATCH":
			// MATCH规则匹配所有流量
			log.Printf("MATCH规则匹配: %s -> %s", destination, rule.ProxySource)
			return rule.ProxySource
		default:
			log.Printf("未知规则类型: %s", rule.Type)
		}
	}

	// 默认直连
	log.Printf("无规则匹配，使用默认直连: %s -> DIRECT", destination)
	return "DIRECT"
}

// matchCIDR 匹配CIDR IP段
func (re *RulesEngine) matchCIDR(destination, pattern string) bool {
	// 解析目标地址
	host, _, err := net.SplitHostPort(destination)
	if err != nil {
		host = destination
	}

	// 解析CIDR
	_, ipnet, err := net.ParseCIDR(pattern)
	if err != nil {
		log.Printf("Invalid CIDR pattern: %s", pattern)
		return false
	}

	// 解析目标IP
	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}

	return ipnet.Contains(ip)
}

// GetRules 获取当前规则
func (re *RulesEngine) GetRules() []config.Rule {
	re.mu.RLock()
	defer re.mu.RUnlock()

	// 返回规则的副本以避免并发问题
	rules := make([]config.Rule, len(re.rules))
	copy(rules, re.rules)

	log.Printf("规则引擎返回规则数量: %d", len(rules))
	for i, rule := range rules {
		log.Printf("返回规则 %d: Type=%s, Pattern=%s, ProxySource=%s, Enabled=%t",
			i, rule.Type, rule.Pattern, rule.ProxySource, rule.Enabled)
	}

	return rules
}
