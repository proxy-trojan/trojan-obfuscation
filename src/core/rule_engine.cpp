/*
 * Rule Engine implementation
 */

#include "rule_engine.h"
#include "log.h"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cctype>
#include <arpa/inet.h>
#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>

using namespace std;

RuleEngine& RuleEngine::instance() {
    static RuleEngine instance;
    return instance;
}

RuleEngine::RuleEngine() : mode_(ProxyMode::RULE), enabled_(true) {
    load_default_rules();
}

void RuleEngine::load_default_rules() {
    lock_guard<mutex> lock(mutex_);
    rules_.clear();
    direct_domains_.clear();
    proxy_domains_.clear();
    direct_suffixes_.clear();
    proxy_suffixes_.clear();
    direct_suffixes_vec_.clear();
    proxy_suffixes_vec_.clear();
    
    // === Direct rules (China & local) ===
    
    // Local addresses
    rules_.emplace_back(RuleType::DOMAIN_EXACT, "localhost", RuleAction::DIRECT);
    rules_.emplace_back(RuleType::DOMAIN_SUFFIX, "local", RuleAction::DIRECT);
    rules_.emplace_back(RuleType::IP_CIDR, "127.0.0.0/8", RuleAction::DIRECT);
    rules_.emplace_back(RuleType::IP_CIDR, "10.0.0.0/8", RuleAction::DIRECT);
    rules_.emplace_back(RuleType::IP_CIDR, "172.16.0.0/12", RuleAction::DIRECT);
    rules_.emplace_back(RuleType::IP_CIDR, "192.168.0.0/16", RuleAction::DIRECT);
    rules_.emplace_back(RuleType::IP_CIDR, "::1/128", RuleAction::DIRECT);
    rules_.emplace_back(RuleType::IP_CIDR, "fc00::/7", RuleAction::DIRECT);
    
    // China domains (direct)
    const vector<string> china_domains = {
        "cn", "baidu.com", "qq.com", "weixin.qq.com", "wechat.com",
        "taobao.com", "tmall.com", "jd.com", "alipay.com", "aliyun.com",
        "163.com", "126.com", "bilibili.com", "zhihu.com", "douyin.com",
        "toutiao.com", "weibo.com", "sina.com.cn", "sohu.com", "youku.com",
        "iqiyi.com", "meituan.com", "dianping.com", "ctrip.com", "csdn.net",
        "jianshu.com", "oschina.net", "gitee.com", "cnblogs.com"
    };
    for (const auto& domain : china_domains) {
        rules_.emplace_back(RuleType::DOMAIN_SUFFIX, domain, RuleAction::DIRECT);
        direct_suffixes_.insert(domain);
    }
    
    // China GeoIP
    rules_.emplace_back(RuleType::GEOIP, "CN", RuleAction::DIRECT);
    
    // === Proxy rules (foreign sites) ===
    
    // Google
    const vector<string> google_domains = {
        "google.com", "google.co.jp", "google.co.uk", "google.com.hk",
        "googleapis.com", "gstatic.com", "googleusercontent.com",
        "googlevideo.com", "youtube.com", "ytimg.com", "ggpht.com",
        "gmail.com", "googlemail.com", "google-analytics.com"
    };
    for (const auto& domain : google_domains) {
        rules_.emplace_back(RuleType::DOMAIN_SUFFIX, domain, RuleAction::PROXY);
        proxy_suffixes_.insert(domain);
    }
    
    // Social media
    const vector<string> social_domains = {
        "facebook.com", "fb.com", "fbcdn.net", "instagram.com", "cdninstagram.com",
        "twitter.com", "x.com", "twimg.com", "t.co",
        "whatsapp.com", "whatsapp.net",
        "telegram.org", "telegram.me", "t.me", "tg.dev",
        "discord.com", "discordapp.com", "discord.gg",
        "reddit.com", "redd.it", "redditstatic.com",
        "linkedin.com", "licdn.com",
        "pinterest.com", "pinimg.com",
        "tumblr.com", "snapchat.com"
    };
    for (const auto& domain : social_domains) {
        rules_.emplace_back(RuleType::DOMAIN_SUFFIX, domain, RuleAction::PROXY);
        proxy_suffixes_.insert(domain);
    }
    
    // Streaming
    const vector<string> streaming_domains = {
        "netflix.com", "nflxvideo.net", "nflximg.net", "nflxext.com",
        "spotify.com", "scdn.co", "spotifycdn.com",
        "twitch.tv", "twitchcdn.net", "jtvnw.net",
        "hulu.com", "hulustream.com",
        "disneyplus.com", "disney-plus.net",
        "hbomax.com", "hbonow.com",
        "primevideo.com", "amazonvideo.com"
    };
    for (const auto& domain : streaming_domains) {
        rules_.emplace_back(RuleType::DOMAIN_SUFFIX, domain, RuleAction::PROXY);
        proxy_suffixes_.insert(domain);
    }
    
    // Tech & Dev
    const vector<string> tech_domains = {
        "github.com", "githubusercontent.com", "github.io", "githubassets.com",
        "gitlab.com", "bitbucket.org",
        "stackoverflow.com", "stackexchange.com",
        "medium.com", "dev.to",
        "docker.com", "docker.io",
        "npmjs.com", "npmjs.org", "yarnpkg.com",
        "pypi.org", "pythonhosted.org",
        "rubygems.org", "crates.io",
        "aws.amazon.com", "amazonaws.com",
        "azure.com", "azure.microsoft.com",
        "cloud.google.com", "googleapis.com"
    };
    for (const auto& domain : tech_domains) {
        rules_.emplace_back(RuleType::DOMAIN_SUFFIX, domain, RuleAction::PROXY);
        proxy_suffixes_.insert(domain);
    }
    
    // AI services
    const vector<string> ai_domains = {
        "openai.com", "chatgpt.com", "chat.openai.com",
        "anthropic.com", "claude.ai",
        "bard.google.com", "gemini.google.com",
        "perplexity.ai", "poe.com",
        "midjourney.com", "stability.ai",
        "huggingface.co"
    };
    for (const auto& domain : ai_domains) {
        rules_.emplace_back(RuleType::DOMAIN_SUFFIX, domain, RuleAction::PROXY);
        proxy_suffixes_.insert(domain);
    }
    
    // News & Media
    const vector<string> news_domains = {
        "nytimes.com", "washingtonpost.com", "wsj.com",
        "bbc.com", "bbc.co.uk", "cnn.com",
        "theguardian.com", "reuters.com", "apnews.com",
        "wikipedia.org", "wikimedia.org", "wiktionary.org"
    };
    for (const auto& domain : news_domains) {
        rules_.emplace_back(RuleType::DOMAIN_SUFFIX, domain, RuleAction::PROXY);
        proxy_suffixes_.insert(domain);
    }
    
    // CDN & Cloud (often needed for foreign sites)
    const vector<string> cdn_domains = {
        "cloudflare.com", "cloudflare-dns.com",
        "akamai.net", "akamaized.net", "akamaihd.net",
        "fastly.net", "fastlylb.net",
        "cloudfront.net"
    };
    for (const auto& domain : cdn_domains) {
        rules_.emplace_back(RuleType::DOMAIN_SUFFIX, domain, RuleAction::PROXY);
        proxy_suffixes_.insert(domain);
    }
    
    // Default: proxy all other traffic
    rules_.emplace_back(RuleType::MATCH, "", RuleAction::PROXY);

    rebuild_suffix_vectors_unlocked_();
    Log::log("[RuleEngine] Loaded " + to_string(rules_.size()) + " default rules", Log::INFO);
}

void RuleEngine::rebuild_suffix_vectors_unlocked_() {
    direct_suffixes_vec_.assign(direct_suffixes_.begin(), direct_suffixes_.end());
    proxy_suffixes_vec_.assign(proxy_suffixes_.begin(), proxy_suffixes_.end());

    auto by_len_desc = [](const std::string& a, const std::string& b) {
        if (a.size() != b.size()) return a.size() > b.size();
        return a < b;
    };
    std::sort(direct_suffixes_vec_.begin(), direct_suffixes_vec_.end(), by_len_desc);
    std::sort(proxy_suffixes_vec_.begin(), proxy_suffixes_vec_.end(), by_len_desc);
}

bool RuleEngine::load_rules(const string& json_config) {
    try {
        boost::property_tree::ptree pt;
        istringstream iss(json_config);
        boost::property_tree::read_json(iss, pt);
        
        lock_guard<mutex> lock(mutex_);
        rules_.clear();
        direct_domains_.clear();
        proxy_domains_.clear();
        direct_suffixes_.clear();
        proxy_suffixes_.clear();
        direct_suffixes_vec_.clear();
        proxy_suffixes_vec_.clear();
        
        for (const auto& rule_node : pt.get_child("rules")) {
            string type_str = rule_node.second.get<string>("type");
            string value = rule_node.second.get<string>("value", "");
            string action_str = rule_node.second.get<string>("action");
            
            RuleType type;
            if (type_str == "DOMAIN" || type_str == "DOMAIN-EXACT") type = RuleType::DOMAIN_EXACT;
            else if (type_str == "DOMAIN-SUFFIX") type = RuleType::DOMAIN_SUFFIX;
            else if (type_str == "DOMAIN-KEYWORD") type = RuleType::DOMAIN_KEYWORD;
            else if (type_str == "IP-CIDR") type = RuleType::IP_CIDR;
            else if (type_str == "GEOIP") type = RuleType::GEOIP;
            else if (type_str == "MATCH") type = RuleType::MATCH;
            else continue;
            
            RuleAction action;
            if (action_str == "PROXY") action = RuleAction::PROXY;
            else if (action_str == "DIRECT") action = RuleAction::DIRECT;
            else if (action_str == "REJECT") action = RuleAction::REJECT;
            else continue;
            
            rules_.emplace_back(type, value, action);
            
            // Add to optimized sets
            if (type == RuleType::DOMAIN_SUFFIX) {
                if (action == RuleAction::DIRECT) direct_suffixes_.insert(value);
                else if (action == RuleAction::PROXY) proxy_suffixes_.insert(value);
            } else if (type == RuleType::DOMAIN_EXACT) {
                if (action == RuleAction::DIRECT) direct_domains_.insert(value);
                else if (action == RuleAction::PROXY) proxy_domains_.insert(value);
            }
        }
        
        rebuild_suffix_vectors_unlocked_();

        // Set mode if specified
        string mode_str = pt.get<string>("mode", "rule");
        if (mode_str == "global") mode_ = ProxyMode::GLOBAL;
        else if (mode_str == "direct") mode_ = ProxyMode::DIRECT;
        else mode_ = ProxyMode::RULE;
        
        Log::log("[RuleEngine] Loaded " + to_string(rules_.size()) + " rules from config", Log::INFO);
        return true;
    } catch (const exception& e) {
        Log::log("[RuleEngine] Failed to load rules: " + string(e.what()), Log::ERROR);
        return false;
    }
}

bool RuleEngine::load_rules_file(const string& filename) {
    try {
        ifstream file(filename);
        if (!file.is_open()) {
            Log::log("[RuleEngine] Cannot open rules file: " + filename, Log::ERROR);
            return false;
        }
        stringstream buffer;
        buffer << file.rdbuf();
        return load_rules(buffer.str());
    } catch (const exception& e) {
        Log::log("[RuleEngine] Failed to load rules file: " + string(e.what()), Log::ERROR);
        return false;
    }
}

RuleAction RuleEngine::match(const string& host, uint16_t port) {
    if (!enabled_) {
        return RuleAction::PROXY;
    }
    
    // Check mode first
    if (mode_ == ProxyMode::GLOBAL) {
        return RuleAction::PROXY;
    }
    if (mode_ == ProxyMode::DIRECT) {
        return RuleAction::DIRECT;
    }
    
    lock_guard<mutex> lock(mutex_);
    
    // Convert host to lowercase for matching
    string host_lower = host;
    transform(host_lower.begin(), host_lower.end(), host_lower.begin(), ::tolower);
    
    // Quick lookup in optimized sets first
    if (direct_domains_.count(host_lower)) {
        return RuleAction::DIRECT;
    }
    if (proxy_domains_.count(host_lower)) {
        return RuleAction::PROXY;
    }
    
    // Check suffixes (precomputed vectors are faster to iterate than unordered_set)
    for (const auto& suffix : direct_suffixes_vec_) {
        if (match_domain_suffix(host_lower, suffix)) {
            return RuleAction::DIRECT;
        }
    }
    for (const auto& suffix : proxy_suffixes_vec_) {
        if (match_domain_suffix(host_lower, suffix)) {
            return RuleAction::PROXY;
        }
    }
    
    // Full rule matching
    bool is_ip = is_ip_address(host);
    
    for (const auto& rule : rules_) {
        bool matched = false;
        
        switch (rule.type) {
            case RuleType::DOMAIN_EXACT:
                matched = match_domain(host_lower, rule.value);
                break;
            case RuleType::DOMAIN_SUFFIX:
                matched = match_domain_suffix(host_lower, rule.value);
                break;
            case RuleType::DOMAIN_KEYWORD:
                matched = match_domain_keyword(host_lower, rule.value);
                break;
            case RuleType::IP_CIDR:
                if (is_ip) {
                    matched = match_ip_cidr(host, rule.value);
                }
                break;
            case RuleType::GEOIP:
                if (is_ip) {
                    matched = match_geoip(host, rule.value);
                }
                break;
            case RuleType::MATCH:
                matched = true;
                break;
        }
        
        if (matched) {
            Log::log("[RuleEngine] " + host + " matched rule: " + 
                     (rule.type == RuleType::MATCH ? "MATCH" : rule.value) + 
                     " -> " + (rule.action == RuleAction::PROXY ? "PROXY" : 
                              rule.action == RuleAction::DIRECT ? "DIRECT" : "REJECT"), 
                     Log::ALL);
            return rule.action;
        }
    }
    
    // Default: proxy
    return RuleAction::PROXY;
}

void RuleEngine::set_mode(ProxyMode mode) {
    lock_guard<mutex> lock(mutex_);
    mode_ = mode;
    Log::log("[RuleEngine] Mode set to: " + 
             string(mode == ProxyMode::GLOBAL ? "GLOBAL" : 
                    mode == ProxyMode::DIRECT ? "DIRECT" : "RULE"), Log::INFO);
}

ProxyMode RuleEngine::get_mode() const {
    return mode_;
}

void RuleEngine::add_rule(const Rule& rule) {
    lock_guard<mutex> lock(mutex_);
    // Insert before the MATCH rule (if exists)
    auto it = find_if(rules_.begin(), rules_.end(),
                      [](const Rule& r) { return r.type == RuleType::MATCH; });
    rules_.insert(it, rule);

    // Keep optimized lookups in sync
    if (rule.type == RuleType::DOMAIN_SUFFIX) {
        if (rule.action == RuleAction::DIRECT) direct_suffixes_.insert(rule.value);
        else if (rule.action == RuleAction::PROXY) proxy_suffixes_.insert(rule.value);
        rebuild_suffix_vectors_unlocked_();
    } else if (rule.type == RuleType::DOMAIN_EXACT) {
        if (rule.action == RuleAction::DIRECT) direct_domains_.insert(rule.value);
        else if (rule.action == RuleAction::PROXY) proxy_domains_.insert(rule.value);
    }
}

void RuleEngine::clear_rules() {
    lock_guard<mutex> lock(mutex_);
    rules_.clear();
    direct_domains_.clear();
    proxy_domains_.clear();
    direct_suffixes_.clear();
    proxy_suffixes_.clear();
    direct_suffixes_vec_.clear();
    proxy_suffixes_vec_.clear();
}

size_t RuleEngine::rule_count() const {
    lock_guard<mutex> lock(mutex_);
    return rules_.size();
}

bool RuleEngine::match_domain(const string& host, const string& pattern) const {
    return host == pattern;
}

bool RuleEngine::match_domain_suffix(const string& host, const string& suffix) const {
    if (host == suffix) return true;
    if (host.length() > suffix.length()) {
        size_t pos = host.length() - suffix.length();
        if (host[pos - 1] == '.' && host.substr(pos) == suffix) {
            return true;
        }
    }
    return false;
}

bool RuleEngine::match_domain_keyword(const string& host, const string& keyword) const {
    return host.find(keyword) != string::npos;
}

bool RuleEngine::is_ip_address(const string& host) const {
    struct in_addr addr4;
    struct in6_addr addr6;
    return inet_pton(AF_INET, host.c_str(), &addr4) == 1 ||
           inet_pton(AF_INET6, host.c_str(), &addr6) == 1;
}

uint32_t RuleEngine::ip_to_uint32(const string& ip) const {
    struct in_addr addr;
    if (inet_pton(AF_INET, ip.c_str(), &addr) == 1) {
        return ntohl(addr.s_addr);
    }
    return 0;
}

bool RuleEngine::match_ip_cidr(const string& ip, const string& cidr) const {
    size_t slash_pos = cidr.find('/');
    if (slash_pos == string::npos) return false;
    
    string network = cidr.substr(0, slash_pos);
    int prefix_len = stoi(cidr.substr(slash_pos + 1));
    
    // IPv4
    struct in_addr ip_addr, net_addr;
    if (inet_pton(AF_INET, ip.c_str(), &ip_addr) == 1 &&
        inet_pton(AF_INET, network.c_str(), &net_addr) == 1) {
        uint32_t ip_val = ntohl(ip_addr.s_addr);
        uint32_t net_val = ntohl(net_addr.s_addr);
        uint32_t mask = prefix_len == 0 ? 0 : (~0U << (32 - prefix_len));
        return (ip_val & mask) == (net_val & mask);
    }
    
    // IPv6
    struct in6_addr ip6_addr, net6_addr;
    if (inet_pton(AF_INET6, ip.c_str(), &ip6_addr) == 1 &&
        inet_pton(AF_INET6, network.c_str(), &net6_addr) == 1) {
        int bytes = prefix_len / 8;
        int bits = prefix_len % 8;
        
        for (int i = 0; i < bytes; i++) {
            if (ip6_addr.s6_addr[i] != net6_addr.s6_addr[i]) return false;
        }
        if (bits > 0 && bytes < 16) {
            uint8_t mask = ~((1 << (8 - bits)) - 1);
            if ((ip6_addr.s6_addr[bytes] & mask) != (net6_addr.s6_addr[bytes] & mask)) {
                return false;
            }
        }
        return true;
    }
    
    return false;
}

bool RuleEngine::match_geoip(const string& ip, const string& country_code) const {
    // Simple implementation: check common China IP ranges
    // For production, integrate MaxMind GeoIP database
    if (country_code == "CN") {
        // Common China IP ranges (simplified)
        const vector<string> china_cidrs = {
            "1.0.1.0/24", "1.0.2.0/23", "1.0.8.0/21", "1.0.32.0/19",
            "14.0.0.0/8", "27.0.0.0/8", "36.0.0.0/8", "39.0.0.0/8",
            "42.0.0.0/8", "49.0.0.0/8", "58.0.0.0/8", "59.0.0.0/8",
            "60.0.0.0/8", "61.0.0.0/8", "101.0.0.0/8", "103.0.0.0/8",
            "106.0.0.0/8", "110.0.0.0/8", "111.0.0.0/8", "112.0.0.0/8",
            "113.0.0.0/8", "114.0.0.0/8", "115.0.0.0/8", "116.0.0.0/8",
            "117.0.0.0/8", "118.0.0.0/8", "119.0.0.0/8", "120.0.0.0/8",
            "121.0.0.0/8", "122.0.0.0/8", "123.0.0.0/8", "124.0.0.0/8",
            "125.0.0.0/8", "139.0.0.0/8", "140.0.0.0/8", "144.0.0.0/8",
            "150.0.0.0/8", "153.0.0.0/8", "157.0.0.0/8", "159.0.0.0/8",
            "163.0.0.0/8", "171.0.0.0/8", "175.0.0.0/8", "180.0.0.0/8",
            "182.0.0.0/8", "183.0.0.0/8", "202.0.0.0/8", "203.0.0.0/8",
            "210.0.0.0/8", "211.0.0.0/8", "218.0.0.0/8", "219.0.0.0/8",
            "220.0.0.0/8", "221.0.0.0/8", "222.0.0.0/8", "223.0.0.0/8"
        };
        for (const auto& cidr : china_cidrs) {
            if (match_ip_cidr(ip, cidr)) return true;
        }
    }
    return false;
}
