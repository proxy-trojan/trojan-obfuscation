/*
 * Rule Engine for traffic routing
 * Supports domain suffix, domain keyword, IP CIDR, and GeoIP rules
 */

#ifndef _RULE_ENGINE_H_
#define _RULE_ENGINE_H_

#include <string>
#include <vector>
#include <memory>
#include <unordered_set>
#include <mutex>

// Rule action
enum class RuleAction {
    PROXY,   // Route through trojan proxy
    DIRECT,  // Direct connection
    REJECT   // Block the connection
};

// Rule type
enum class RuleType {
    DOMAIN_EXACT,    // Exact domain match
    DOMAIN_SUFFIX,   // Domain suffix match (e.g., google.com matches www.google.com)
    DOMAIN_KEYWORD,  // Domain contains keyword
    IP_CIDR,         // IP range match
    GEOIP,           // GeoIP country code
    MATCH            // Default rule (matches everything)
};

// Single rule
struct Rule {
    RuleType type;
    std::string value;
    RuleAction action;
    
    Rule(RuleType t, const std::string& v, RuleAction a)
        : type(t), value(v), action(a) {}
};

// Proxy mode
enum class ProxyMode {
    RULE,    // Use rules for routing
    GLOBAL,  // All traffic through proxy
    DIRECT   // All traffic direct
};

class RuleEngine {
public:
    static RuleEngine& instance();
    
    // Load rules from JSON config
    bool load_rules(const std::string& json_config);
    
    // Load rules from file
    bool load_rules_file(const std::string& filename);
    
    // Match a request and return the action
    RuleAction match(const std::string& host, uint16_t port);
    
    // Set proxy mode
    void set_mode(ProxyMode mode);
    ProxyMode get_mode() const;
    
    // Add/remove rules dynamically
    void add_rule(const Rule& rule);
    void clear_rules();
    
    // Load default rules (China direct, foreign proxy)
    void load_default_rules();
    
    // Get rule count
    size_t rule_count() const;
    
    // Check if enabled
    bool is_enabled() const { return enabled_; }
    void set_enabled(bool enabled) { enabled_ = enabled; }

private:
    RuleEngine();
    ~RuleEngine() = default;
    RuleEngine(const RuleEngine&) = delete;
    RuleEngine& operator=(const RuleEngine&) = delete;
    
    // Match helpers
    bool match_domain(const std::string& host, const std::string& pattern) const;
    bool match_domain_suffix(const std::string& host, const std::string& suffix) const;
    bool match_domain_keyword(const std::string& host, const std::string& keyword) const;
    bool match_ip_cidr(const std::string& ip, const std::string& cidr) const;
    bool match_geoip(const std::string& ip, const std::string& country_code) const;
    
    // Check if string is IP address
    bool is_ip_address(const std::string& host) const;
    
    // Convert IP string to uint32
    uint32_t ip_to_uint32(const std::string& ip) const;
    
    std::vector<Rule> rules_;
    ProxyMode mode_;
    bool enabled_;
    mutable std::mutex mutex_;
    
    // Optimized lookup sets for common rules
    void rebuild_suffix_vectors_unlocked_();

    std::unordered_set<std::string> direct_domains_;
    std::unordered_set<std::string> proxy_domains_;
    std::unordered_set<std::string> direct_suffixes_;
    std::unordered_set<std::string> proxy_suffixes_;

    // Precomputed for faster iteration (sorted by suffix length desc)
    std::vector<std::string> direct_suffixes_vec_;
    std::vector<std::string> proxy_suffixes_vec_;
};

// Helper function to get rule engine instance
inline RuleEngine& get_rule_engine() {
    return RuleEngine::instance();
}

#endif // _RULE_ENGINE_H_
