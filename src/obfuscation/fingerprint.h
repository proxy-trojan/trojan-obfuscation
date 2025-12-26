/*
 * TLS Fingerprint Randomization Module
 * 模拟真实浏览器的 ClientHello 指纹
 */

#ifndef _FINGERPRINT_H_
#define _FINGERPRINT_H_

#include <string>
#include <vector>
#include <random>
#include <openssl/ssl.h>

// 预定义的浏览器指纹配置
struct BrowserFingerprint {
    std::string name;
    std::string ja3_hash;  // JA3 指纹哈希
    std::vector<uint16_t> cipher_suites;
    std::vector<uint16_t> extensions;
    std::vector<uint16_t> supported_groups;
    std::vector<uint8_t> ec_point_formats;
    std::vector<uint16_t> sig_algorithms;
    std::vector<uint16_t> supported_versions;  // TLS 1.3 supported_versions 扩展
    std::string alpn;
    bool grease_enabled;  // GREASE (RFC 8701) 支持
    uint16_t tls_version;  // ClientHello 中的版本 (TLS 1.3 仍为 0x0303)
    uint16_t max_tls_version;  // 实际支持的最高版本 (0x0304 = TLS 1.3)
    
    // 预计算的字符串缓存 (性能优化)
    mutable std::string cached_cipher_str;
    mutable std::string cached_tls13_str;
    mutable std::string cached_groups_str;
    mutable bool cache_valid = false;
};

class FingerprintRandomizer {
public:
    // 预定义指纹类型
    enum class FingerprintType {
        CHROME_120,
        CHROME_121,
        FIREFOX_121,
        FIREFOX_122,
        SAFARI_17,
        EDGE_120,
        EDGE_121,
        OPERA_106,
        BRAVE_1_61,
        RANDOM_BROWSER,
        CUSTOM
    };

    FingerprintRandomizer();
    ~FingerprintRandomizer();

    // 应用指纹到 SSL 连接
    bool apply_fingerprint(SSL* ssl, FingerprintType type);
    bool apply_fingerprint_by_name(SSL* ssl, const std::string& name);
    bool apply_random_fingerprint(SSL* ssl);
    
    // 强制 TLS 1.3
    bool enforce_tls13(SSL* ssl);
    bool enforce_tls13_only(SSL_CTX* ctx);
    
    // ECH (Encrypted Client Hello) 支持 - 预留接口
    // 注意: 需要 BoringSSL 或未来版本的 OpenSSL
    struct ECHConfig {
        std::string public_name;      // 外层 SNI (如 cloudflare-ech.com)
        std::vector<uint8_t> ech_config_list;  // ECH 配置
        bool enabled = false;
    };
    bool set_ech_config(SSL* ssl, const ECHConfig& config);
    bool is_ech_supported();
    
    // 从真实网站采集指纹 (预计算缓存)
    bool load_fingerprint_from_cache(const std::string& cache_file);
    bool save_fingerprint_to_cache(const std::string& cache_file);
    
    // GREASE 值生成 (RFC 8701)
    static uint16_t generate_grease_value();
    
    // 随机化扩展顺序
    void shuffle_extensions(SSL* ssl);
    
    // 获取当前指纹的 JA3 哈希
    std::string get_current_ja3_hash() const;
    
    // 获取所有可用的指纹类型
    std::vector<std::string> get_available_fingerprints() const;
    
    // 设置 GREASE 启用状态
    void set_grease_enabled(bool enabled);

private:
    std::vector<BrowserFingerprint> fingerprint_pool_;
    std::mt19937 rng_;
    std::string current_ja3_hash_;
    bool grease_enabled_;
    
    void init_fingerprint_pool();
    BrowserFingerprint get_chrome_120_fingerprint();
    BrowserFingerprint get_chrome_121_fingerprint();
    BrowserFingerprint get_firefox_121_fingerprint();
    BrowserFingerprint get_firefox_122_fingerprint();
    BrowserFingerprint get_safari_17_fingerprint();
    BrowserFingerprint get_edge_120_fingerprint();
    BrowserFingerprint get_edge_121_fingerprint();
    BrowserFingerprint get_opera_106_fingerprint();
    BrowserFingerprint get_brave_fingerprint();
    
    // 设置 cipher suites (需要特定顺序)
    bool set_cipher_suites(SSL* ssl, const std::vector<uint16_t>& suites);
    
    // 设置 supported groups/curves
    bool set_supported_groups(SSL* ssl, const std::vector<uint16_t>& groups);
    
    // 设置 TLS 版本
    bool set_tls_version(SSL* ssl, uint16_t min_version, uint16_t max_version);
    
    // 添加 GREASE 值到列表
    void inject_grease(std::vector<uint16_t>& list, int count);
    
    // 计算 JA3 哈希
    std::string calculate_ja3_hash(const BrowserFingerprint& fp);
};

// Chrome 120 的真实 cipher suite 顺序
const std::vector<uint16_t> CHROME_120_CIPHERS = {
    0x1301,  // TLS_AES_128_GCM_SHA256
    0x1302,  // TLS_AES_256_GCM_SHA384
    0x1303,  // TLS_CHACHA20_POLY1305_SHA256
    0xc02b,  // TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    0xc02f,  // TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    0xc02c,  // TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    0xc030,  // TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    0xcca9,  // TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
    0xcca8,  // TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
    0xc013,  // TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
    0xc014,  // TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
    0x009c,  // TLS_RSA_WITH_AES_128_GCM_SHA256
    0x009d,  // TLS_RSA_WITH_AES_256_GCM_SHA384
    0x002f,  // TLS_RSA_WITH_AES_128_CBC_SHA
    0x0035,  // TLS_RSA_WITH_AES_256_CBC_SHA
};

// Chrome 120 的 supported groups
const std::vector<uint16_t> CHROME_120_GROUPS = {
    0x001d,  // x25519
    0x0017,  // secp256r1
    0x0018,  // secp384r1
};

// Firefox 121 的 cipher suites
const std::vector<uint16_t> FIREFOX_121_CIPHERS = {
    0x1301,  // TLS_AES_128_GCM_SHA256
    0x1303,  // TLS_CHACHA20_POLY1305_SHA256
    0x1302,  // TLS_AES_256_GCM_SHA384
    0xc02b,  // TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    0xc02f,  // TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    0xcca9,  // TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
    0xcca8,  // TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
    0xc02c,  // TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    0xc030,  // TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    0xc013,  // TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
    0xc014,  // TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
};

// Edge 120 的 cipher suites (基于 Chromium)
const std::vector<uint16_t> EDGE_120_CIPHERS = {
    0x1301,  // TLS_AES_128_GCM_SHA256
    0x1302,  // TLS_AES_256_GCM_SHA384
    0x1303,  // TLS_CHACHA20_POLY1305_SHA256
    0xc02b,  // TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    0xc02f,  // TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    0xc02c,  // TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    0xc030,  // TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    0xcca9,  // TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
    0xcca8,  // TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
    0xc013,  // TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
    0xc014,  // TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
    0x009c,  // TLS_RSA_WITH_AES_128_GCM_SHA256
    0x009d,  // TLS_RSA_WITH_AES_256_GCM_SHA384
};

// Opera 106 的 cipher suites (基于 Chromium)
const std::vector<uint16_t> OPERA_106_CIPHERS = {
    0x1301,  // TLS_AES_128_GCM_SHA256
    0x1302,  // TLS_AES_256_GCM_SHA384
    0x1303,  // TLS_CHACHA20_POLY1305_SHA256
    0xc02b,  // TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    0xc02f,  // TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    0xc02c,  // TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    0xc030,  // TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    0xcca9,  // TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
    0xcca8,  // TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
};

// Safari 17 的 cipher suites
const std::vector<uint16_t> SAFARI_17_CIPHERS = {
    0x1301,  // TLS_AES_128_GCM_SHA256
    0x1302,  // TLS_AES_256_GCM_SHA384
    0x1303,  // TLS_CHACHA20_POLY1305_SHA256
    0xc02c,  // TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    0xc02b,  // TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    0xcca9,  // TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
    0xc030,  // TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    0xc02f,  // TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    0xcca8,  // TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
    0xc024,  // TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384
    0xc023,  // TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256
    0xc00a,  // TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
    0xc009,  // TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA
};

// Brave 1.61 的 cipher suites (基于 Chromium，但有细微差异)
const std::vector<uint16_t> BRAVE_CIPHERS = {
    0x1301,  // TLS_AES_128_GCM_SHA256
    0x1302,  // TLS_AES_256_GCM_SHA384
    0x1303,  // TLS_CHACHA20_POLY1305_SHA256
    0xc02b,  // TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    0xc02f,  // TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    0xc02c,  // TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    0xc030,  // TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    0xcca9,  // TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
    0xcca8,  // TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
};

#endif // _FINGERPRINT_H_
