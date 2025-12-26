/*
 * TLS Fingerprint Randomization Implementation
 * 支持 Chrome, Firefox, Safari, Edge, Opera, Brave 等浏览器指纹
 */

#include "fingerprint.h"
#include <algorithm>
#include <fstream>
#include <cstring>
#include <sstream>
#include <iomanip>
#include <unordered_map>
#include <openssl/ssl.h>
#include <openssl/md5.h>

FingerprintRandomizer::FingerprintRandomizer() 
    : rng_(std::random_device{}()), grease_enabled_(true) {
    init_fingerprint_pool();
}

FingerprintRandomizer::~FingerprintRandomizer() = default;

void FingerprintRandomizer::init_fingerprint_pool() {
    fingerprint_pool_.push_back(get_chrome_120_fingerprint());
    fingerprint_pool_.push_back(get_chrome_121_fingerprint());
    fingerprint_pool_.push_back(get_firefox_121_fingerprint());
    fingerprint_pool_.push_back(get_firefox_122_fingerprint());
    fingerprint_pool_.push_back(get_safari_17_fingerprint());
    fingerprint_pool_.push_back(get_edge_120_fingerprint());
    fingerprint_pool_.push_back(get_edge_121_fingerprint());
    fingerprint_pool_.push_back(get_opera_106_fingerprint());
    fingerprint_pool_.push_back(get_brave_fingerprint());
}

BrowserFingerprint FingerprintRandomizer::get_chrome_120_fingerprint() {
    BrowserFingerprint fp;
    fp.name = "Chrome/120";
    fp.cipher_suites = CHROME_120_CIPHERS;
    fp.supported_groups = CHROME_120_GROUPS;
    fp.ec_point_formats = {0x00};
    fp.sig_algorithms = {0x0403, 0x0804, 0x0401, 0x0503, 0x0805, 0x0501, 0x0806, 0x0601, 0x0201};
    fp.supported_versions = {0x0304, 0x0303};  // TLS 1.3, TLS 1.2
    fp.alpn = "\x02h2\x08http/1.1";
    fp.grease_enabled = true;
    fp.tls_version = 0x0303;  // ClientHello legacy_version (TLS 1.3 仍用 0x0303)
    fp.max_tls_version = 0x0304;  // 实际最高支持 TLS 1.3
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}

BrowserFingerprint FingerprintRandomizer::get_chrome_121_fingerprint() {
    BrowserFingerprint fp = get_chrome_120_fingerprint();
    fp.name = "Chrome/121";
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}


BrowserFingerprint FingerprintRandomizer::get_firefox_121_fingerprint() {
    BrowserFingerprint fp;
    fp.name = "Firefox/121";
    fp.cipher_suites = FIREFOX_121_CIPHERS;
    fp.supported_groups = {0x001d, 0x0017, 0x0018, 0x0019, 0x0100};
    fp.ec_point_formats = {0x00};
    fp.sig_algorithms = {0x0403, 0x0503, 0x0603, 0x0804, 0x0805, 0x0806, 0x0401, 0x0501, 0x0601, 0x0201};
    fp.supported_versions = {0x0304, 0x0303};  // TLS 1.3, TLS 1.2
    fp.alpn = "\x02h2\x08http/1.1";
    fp.grease_enabled = false;
    fp.tls_version = 0x0303;
    fp.max_tls_version = 0x0304;
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}

BrowserFingerprint FingerprintRandomizer::get_firefox_122_fingerprint() {
    BrowserFingerprint fp = get_firefox_121_fingerprint();
    fp.name = "Firefox/122";
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}

BrowserFingerprint FingerprintRandomizer::get_safari_17_fingerprint() {
    BrowserFingerprint fp;
    fp.name = "Safari/17";
    fp.cipher_suites = SAFARI_17_CIPHERS;
    fp.supported_groups = {0x001d, 0x0017, 0x0018, 0x0019};
    fp.ec_point_formats = {0x00};
    fp.sig_algorithms = {0x0403, 0x0804, 0x0401, 0x0503, 0x0203, 0x0805, 0x0501, 0x0806, 0x0601, 0x0201};
    fp.supported_versions = {0x0304, 0x0303};  // TLS 1.3, TLS 1.2
    fp.alpn = "\x02h2\x08http/1.1";
    fp.grease_enabled = false;
    fp.tls_version = 0x0303;
    fp.max_tls_version = 0x0304;
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}

BrowserFingerprint FingerprintRandomizer::get_edge_120_fingerprint() {
    BrowserFingerprint fp;
    fp.name = "Edge/120";
    fp.cipher_suites = EDGE_120_CIPHERS;
    fp.supported_groups = {0x001d, 0x0017, 0x0018};
    fp.ec_point_formats = {0x00};
    fp.sig_algorithms = {0x0403, 0x0804, 0x0401, 0x0503, 0x0805, 0x0501, 0x0806, 0x0601, 0x0201};
    fp.supported_versions = {0x0304, 0x0303};  // TLS 1.3, TLS 1.2
    fp.alpn = "\x02h2\x08http/1.1";
    fp.grease_enabled = true;
    fp.tls_version = 0x0303;
    fp.max_tls_version = 0x0304;
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}

BrowserFingerprint FingerprintRandomizer::get_edge_121_fingerprint() {
    BrowserFingerprint fp = get_edge_120_fingerprint();
    fp.name = "Edge/121";
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}


BrowserFingerprint FingerprintRandomizer::get_opera_106_fingerprint() {
    BrowserFingerprint fp;
    fp.name = "Opera/106";
    fp.cipher_suites = OPERA_106_CIPHERS;
    fp.supported_groups = {0x001d, 0x0017, 0x0018};
    fp.ec_point_formats = {0x00};
    fp.sig_algorithms = {0x0403, 0x0804, 0x0401, 0x0503, 0x0805, 0x0501, 0x0806, 0x0601};
    fp.supported_versions = {0x0304, 0x0303};  // TLS 1.3, TLS 1.2
    fp.alpn = "\x02h2\x08http/1.1";
    fp.grease_enabled = true;
    fp.tls_version = 0x0303;
    fp.max_tls_version = 0x0304;
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}

BrowserFingerprint FingerprintRandomizer::get_brave_fingerprint() {
    BrowserFingerprint fp;
    fp.name = "Brave/1.61";
    fp.cipher_suites = BRAVE_CIPHERS;
    fp.supported_groups = {0x001d, 0x0017, 0x0018};
    fp.ec_point_formats = {0x00};
    fp.sig_algorithms = {0x0403, 0x0804, 0x0401, 0x0503, 0x0805, 0x0501, 0x0806, 0x0601, 0x0201};
    fp.supported_versions = {0x0304, 0x0303};  // TLS 1.3, TLS 1.2
    fp.alpn = "\x02h2\x08http/1.1";
    fp.grease_enabled = true;
    fp.tls_version = 0x0303;
    fp.max_tls_version = 0x0304;
    fp.ja3_hash = calculate_ja3_hash(fp);
    return fp;
}

uint16_t FingerprintRandomizer::generate_grease_value() {
    // 使用静态线程局部随机数生成器，避免每次调用都创建新的
    static thread_local std::mt19937 gen(std::random_device{}());
    static const uint16_t grease_values[] = {
        0x0a0a, 0x1a1a, 0x2a2a, 0x3a3a, 0x4a4a, 0x5a5a,
        0x6a6a, 0x7a7a, 0x8a8a, 0x9a9a, 0xaaaa, 0xbaba,
        0xcaca, 0xdada, 0xeaea, 0xfafa
    };
    return grease_values[gen() & 0x0F];  // 位运算比取模更快
}

void FingerprintRandomizer::inject_grease(std::vector<uint16_t>& list, int count) {
    for (int i = 0; i < count; ++i) {
        std::uniform_int_distribution<size_t> pos_dist(0, list.size());
        size_t pos = pos_dist(rng_);
        list.insert(list.begin() + pos, generate_grease_value());
    }
}

void FingerprintRandomizer::set_grease_enabled(bool enabled) {
    grease_enabled_ = enabled;
}


std::string FingerprintRandomizer::calculate_ja3_hash(const BrowserFingerprint& fp) {
    // JA3 格式: TLSVersion,Ciphers,Extensions,EllipticCurves,EllipticCurvePointFormats
    std::ostringstream ja3;
    
    // TLS Version
    ja3 << fp.tls_version << ",";
    
    // Cipher Suites (排除 GREASE)
    bool first = true;
    for (uint16_t cipher : fp.cipher_suites) {
        if ((cipher & 0x0f0f) == 0x0a0a) continue;  // Skip GREASE
        if (!first) ja3 << "-";
        ja3 << cipher;
        first = false;
    }
    ja3 << ",";
    
    // Extensions (简化版，实际应包含所有扩展)
    ja3 << "0-5-10-11-13-16-18-23-27-35-43-45-51" << ",";
    
    // Supported Groups
    first = true;
    for (uint16_t group : fp.supported_groups) {
        if ((group & 0x0f0f) == 0x0a0a) continue;  // Skip GREASE
        if (!first) ja3 << "-";
        ja3 << group;
        first = false;
    }
    ja3 << ",";
    
    // EC Point Formats
    first = true;
    for (uint8_t fmt : fp.ec_point_formats) {
        if (!first) ja3 << "-";
        ja3 << (int)fmt;
        first = false;
    }
    
    // 计算 MD5 哈希
    std::string ja3_str = ja3.str();
    unsigned char md5_result[MD5_DIGEST_LENGTH];
    MD5(reinterpret_cast<const unsigned char*>(ja3_str.c_str()), ja3_str.length(), md5_result);
    
    std::ostringstream hash;
    for (int i = 0; i < MD5_DIGEST_LENGTH; ++i) {
        hash << std::hex << std::setfill('0') << std::setw(2) << (int)md5_result[i];
    }
    
    return hash.str();
}

std::string FingerprintRandomizer::get_current_ja3_hash() const {
    return current_ja3_hash_;
}

std::vector<std::string> FingerprintRandomizer::get_available_fingerprints() const {
    std::vector<std::string> names;
    for (const auto& fp : fingerprint_pool_) {
        names.push_back(fp.name);
    }
    return names;
}


bool FingerprintRandomizer::set_cipher_suites(SSL* ssl, const std::vector<uint16_t>& suites) {
    // 预分配字符串容量，避免多次重新分配
    std::string cipher_str;
    std::string tls13_str;
    cipher_str.reserve(512);
    tls13_str.reserve(128);
    
    // 使用静态查找表替代 switch，提高性能
    static const std::pair<uint16_t, const char*> cipher_map[] = {
        {0xc02b, "ECDHE-ECDSA-AES128-GCM-SHA256:"},
        {0xc02f, "ECDHE-RSA-AES128-GCM-SHA256:"},
        {0xc02c, "ECDHE-ECDSA-AES256-GCM-SHA384:"},
        {0xc030, "ECDHE-RSA-AES256-GCM-SHA384:"},
        {0xcca9, "ECDHE-ECDSA-CHACHA20-POLY1305:"},
        {0xcca8, "ECDHE-RSA-CHACHA20-POLY1305:"},
        {0xc013, "ECDHE-RSA-AES128-SHA:"},
        {0xc014, "ECDHE-RSA-AES256-SHA:"},
        {0xc009, "ECDHE-ECDSA-AES128-SHA:"},
        {0xc00a, "ECDHE-ECDSA-AES256-SHA:"},
        {0xc023, "ECDHE-ECDSA-AES128-SHA256:"},
        {0xc024, "ECDHE-ECDSA-AES256-SHA384:"},
        {0x009c, "AES128-GCM-SHA256:"},
        {0x009d, "AES256-GCM-SHA384:"},
        {0x002f, "AES128-SHA:"},
        {0x0035, "AES256-SHA:"},
    };
    static const std::pair<uint16_t, const char*> tls13_map[] = {
        {0x1301, "TLS_AES_128_GCM_SHA256:"},
        {0x1302, "TLS_AES_256_GCM_SHA384:"},
        {0x1303, "TLS_CHACHA20_POLY1305_SHA256:"},
    };
    
    for (uint16_t suite : suites) {
        if ((suite & 0x0f0f) == 0x0a0a) continue;  // Skip GREASE
        
        if ((suite & 0xFF00) == 0x1300) {
            for (const auto& p : tls13_map) {
                if (p.first == suite) { tls13_str += p.second; break; }
            }
        } else {
            for (const auto& p : cipher_map) {
                if (p.first == suite) { cipher_str += p.second; break; }
            }
        }
    }
    
    if (!cipher_str.empty() && cipher_str.back() == ':') cipher_str.pop_back();
    if (!tls13_str.empty() && tls13_str.back() == ':') tls13_str.pop_back();
    
    SSL_CTX* ctx = SSL_get_SSL_CTX(ssl);
    if (!cipher_str.empty()) {
        if (SSL_CTX_set_cipher_list(ctx, cipher_str.c_str()) != 1) return false;
    }
    
#ifdef TLS1_3_VERSION
    if (!tls13_str.empty()) {
        if (SSL_CTX_set_ciphersuites(ctx, tls13_str.c_str()) != 1) return false;
    }
#endif
    
    return true;
}


bool FingerprintRandomizer::set_supported_groups(SSL* ssl, const std::vector<uint16_t>& groups) {
    std::string groups_str;
    for (uint16_t group : groups) {
        if ((group & 0x0f0f) == 0x0a0a) continue;  // Skip GREASE
        switch (group) {
            case 0x001d: groups_str += "X25519:"; break;
            case 0x0017: groups_str += "P-256:"; break;
            case 0x0018: groups_str += "P-384:"; break;
            case 0x0019: groups_str += "P-521:"; break;
            case 0x001e: groups_str += "X448:"; break;
            case 0x0100: groups_str += "ffdhe2048:"; break;
        }
    }
    
    if (!groups_str.empty() && groups_str.back() == ':') groups_str.pop_back();
    
    SSL_CTX* ctx = SSL_get_SSL_CTX(ssl);
    return SSL_CTX_set1_curves_list(ctx, groups_str.c_str()) == 1;
}

bool FingerprintRandomizer::set_tls_version(SSL* ssl, uint16_t min_version, uint16_t max_version) {
    SSL_CTX* ctx = SSL_get_SSL_CTX(ssl);
    
#ifdef TLS1_3_VERSION
    // 设置最小版本
    if (min_version >= 0x0304) {
        SSL_CTX_set_min_proto_version(ctx, TLS1_3_VERSION);
    } else if (min_version >= 0x0303) {
        SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION);
    }
    
    // 设置最大版本
    if (max_version >= 0x0304) {
        SSL_CTX_set_max_proto_version(ctx, TLS1_3_VERSION);
    } else if (max_version >= 0x0303) {
        SSL_CTX_set_max_proto_version(ctx, TLS1_2_VERSION);
    }
    
    return true;
#else
    // OpenSSL 版本不支持 TLS 1.3
    if (min_version >= 0x0303) {
        SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION);
    }
    return max_version < 0x0304;  // 如果要求 TLS 1.3 但不支持，返回 false
#endif
}

bool FingerprintRandomizer::enforce_tls13(SSL* ssl) {
#ifdef TLS1_3_VERSION
    SSL_CTX* ctx = SSL_get_SSL_CTX(ssl);
    SSL_CTX_set_min_proto_version(ctx, TLS1_3_VERSION);
    SSL_CTX_set_max_proto_version(ctx, TLS1_3_VERSION);
    return true;
#else
    return false;  // OpenSSL 版本不支持 TLS 1.3
#endif
}

bool FingerprintRandomizer::enforce_tls13_only(SSL_CTX* ctx) {
#ifdef TLS1_3_VERSION
    SSL_CTX_set_min_proto_version(ctx, TLS1_3_VERSION);
    SSL_CTX_set_max_proto_version(ctx, TLS1_3_VERSION);
    return true;
#else
    return false;
#endif
}

bool FingerprintRandomizer::is_ech_supported() {
    // ECH (Encrypted Client Hello) 支持状态检测
    // 
    // ============================================================
    // 重要: OpenSSL 3.5/3.6 并不支持 ECH!
    // ============================================================
    // 
    // 当前状态 (2024-12):
    // - OpenSSL 主线 (3.0 ~ 3.6): 不支持 ECH
    //   * sftcd/openssl ECH 分支存在，但未合并到主线
    //   * 预计 OpenSSL 4.0 (2026年4月) 可能包含 ECH
    //
    // - BoringSSL: 支持 ECH ✓
    //   * 使用 SSL_set_enable_ech_grease() 和 SSL_set_ech_config_list()
    //
    // - wolfSSL: 支持 ECH ✓
    //
    // 如果需要 ECH 功能，请使用 BoringSSL 编译本项目
    // 或使用 Cloudflare 等支持 ECH 的 CDN 作为前端
    //
    
#if defined(OPENSSL_IS_BORINGSSL)
    // BoringSSL 支持 ECH
    return true;
#elif defined(WOLFSSL_VERSION)
    // wolfSSL 支持 ECH
    return true;
#elif defined(SSL_ech_set1_echconfig)
    // 检测 OpenSSL ECH API 是否存在 (未来版本)
    return true;
#else
    // OpenSSL 主线目前不支持 ECH
    return false;
#endif
}

bool FingerprintRandomizer::set_ech_config(SSL* ssl, const ECHConfig& config) {
    if (!config.enabled) {
        return true;  // ECH 未启用，直接返回成功
    }
    
    if (!is_ech_supported()) {
        // ECH 不支持，记录警告但不失败
        // 连接仍然可以正常工作，只是没有 ECH 保护
        return false;
    }
    
#if defined(OPENSSL_IS_BORINGSSL)
    // BoringSSL ECH API
    if (config.ech_config_list.empty()) {
        // 启用 ECH GREASE (即使没有真实的 ECH 配置)
        SSL_set_enable_ech_grease(ssl, 1);
        return true;
    }
    
    // 设置 ECH 配置
    if (!SSL_set_ech_config_list(ssl, 
            config.ech_config_list.data(), 
            config.ech_config_list.size())) {
        return false;
    }
    return true;
    
#elif defined(SSL_ech_set1_echconfig)
    // 未来 OpenSSL ECH API (预留)
    // 
    // 预期 API (基于 sftcd/openssl 分支):
    // SSL_ech_set1_echconfig(ssl, config.ech_config_list.data(), 
    //                        config.ech_config_list.size());
    // SSL_ech_set_outer_server_name(ssl, config.public_name.c_str());
    //
    (void)ssl;
    (void)config;
    return false;
    
#else
    (void)ssl;
    (void)config;
    return false;
#endif
}

bool FingerprintRandomizer::apply_fingerprint(SSL* ssl, FingerprintType type) {
    size_t idx = 0;
    switch (type) {
        case FingerprintType::CHROME_120: idx = 0; break;
        case FingerprintType::CHROME_121: idx = 1; break;
        case FingerprintType::FIREFOX_121: idx = 2; break;
        case FingerprintType::FIREFOX_122: idx = 3; break;
        case FingerprintType::SAFARI_17: idx = 4; break;
        case FingerprintType::EDGE_120: idx = 5; break;
        case FingerprintType::EDGE_121: idx = 6; break;
        case FingerprintType::OPERA_106: idx = 7; break;
        case FingerprintType::BRAVE_1_61: idx = 8; break;
        case FingerprintType::RANDOM_BROWSER: return apply_random_fingerprint(ssl);
        default: return false;
    }
    
    if (idx >= fingerprint_pool_.size()) return false;
    
    const BrowserFingerprint& fp = fingerprint_pool_[idx];
    std::vector<uint16_t> ciphers = fp.cipher_suites;
    std::vector<uint16_t> groups = fp.supported_groups;
    
    if (grease_enabled_ && fp.grease_enabled) {
        inject_grease(ciphers, 2);
        inject_grease(groups, 1);
    }
    
    if (!set_cipher_suites(ssl, ciphers)) return false;
    if (!set_supported_groups(ssl, groups)) return false;
    
    // 设置 TLS 版本 (默认支持 TLS 1.3)
    set_tls_version(ssl, 0x0303, fp.max_tls_version);
    
    if (!fp.alpn.empty()) {
        SSL_CTX* ctx = SSL_get_SSL_CTX(ssl);
        SSL_CTX_set_alpn_protos(ctx, 
            reinterpret_cast<const unsigned char*>(fp.alpn.c_str()), fp.alpn.length());
    }
    
    current_ja3_hash_ = fp.ja3_hash;
    return true;
}


bool FingerprintRandomizer::apply_fingerprint_by_name(SSL* ssl, const std::string& name) {
    // 使用静态哈希表加速查找
    static const std::unordered_map<std::string, FingerprintType> name_map = {
        {"chrome", FingerprintType::CHROME_120},
        {"chrome120", FingerprintType::CHROME_120},
        {"chrome121", FingerprintType::CHROME_121},
        {"firefox", FingerprintType::FIREFOX_121},
        {"firefox121", FingerprintType::FIREFOX_121},
        {"firefox122", FingerprintType::FIREFOX_122},
        {"safari", FingerprintType::SAFARI_17},
        {"safari17", FingerprintType::SAFARI_17},
        {"edge", FingerprintType::EDGE_120},
        {"edge120", FingerprintType::EDGE_120},
        {"edge121", FingerprintType::EDGE_121},
        {"opera", FingerprintType::OPERA_106},
        {"opera106", FingerprintType::OPERA_106},
        {"brave", FingerprintType::BRAVE_1_61},
        {"random", FingerprintType::RANDOM_BROWSER},
    };
    
    std::string lower_name = name;
    std::transform(lower_name.begin(), lower_name.end(), lower_name.begin(), ::tolower);
    
    auto it = name_map.find(lower_name);
    if (it != name_map.end()) {
        return apply_fingerprint(ssl, it->second);
    }
    
    return apply_random_fingerprint(ssl);
}

bool FingerprintRandomizer::apply_random_fingerprint(SSL* ssl) {
    if (fingerprint_pool_.empty()) return false;
    
    std::uniform_int_distribution<size_t> dist(0, fingerprint_pool_.size() - 1);
    size_t idx = dist(rng_);
    
    const BrowserFingerprint& fp = fingerprint_pool_[idx];
    std::vector<uint16_t> ciphers = fp.cipher_suites;
    std::vector<uint16_t> groups = fp.supported_groups;
    
    std::uniform_int_distribution<int> grease_dist(0, 1);
    if (grease_enabled_ && grease_dist(rng_)) {
        inject_grease(ciphers, 1 + grease_dist(rng_));
        inject_grease(groups, 1);
    }
    
    if (!set_cipher_suites(ssl, ciphers)) return false;
    if (!set_supported_groups(ssl, groups)) return false;
    
    // 设置 TLS 版本 (默认支持 TLS 1.3)
    set_tls_version(ssl, 0x0303, fp.max_tls_version);
    
    if (!fp.alpn.empty()) {
        SSL_CTX* ctx = SSL_get_SSL_CTX(ssl);
        SSL_CTX_set_alpn_protos(ctx,
            reinterpret_cast<const unsigned char*>(fp.alpn.c_str()), fp.alpn.length());
    }
    
    current_ja3_hash_ = calculate_ja3_hash(fp);
    return true;
}

void FingerprintRandomizer::shuffle_extensions(SSL* ssl) {
    SSL_CTX* ctx = SSL_get_SSL_CTX(ssl);
    std::uniform_int_distribution<int> dist(0, 1);
    
    if (dist(rng_)) {
        SSL_CTX_set_options(ctx, SSL_OP_NO_TICKET);
    }
    if (dist(rng_)) {
        SSL_CTX_set_session_cache_mode(ctx, SSL_SESS_CACHE_CLIENT);
    }
}


bool FingerprintRandomizer::load_fingerprint_from_cache(const std::string& cache_file) {
    std::ifstream ifs(cache_file, std::ios::binary);
    if (!ifs.is_open()) return false;
    
    uint32_t count;
    ifs.read(reinterpret_cast<char*>(&count), sizeof(count));
    
    for (uint32_t i = 0; i < count && ifs.good(); ++i) {
        BrowserFingerprint fp;
        
        uint32_t name_len;
        ifs.read(reinterpret_cast<char*>(&name_len), sizeof(name_len));
        fp.name.resize(name_len);
        ifs.read(&fp.name[0], name_len);
        
        uint32_t cipher_count;
        ifs.read(reinterpret_cast<char*>(&cipher_count), sizeof(cipher_count));
        fp.cipher_suites.resize(cipher_count);
        ifs.read(reinterpret_cast<char*>(fp.cipher_suites.data()), cipher_count * sizeof(uint16_t));
        
        uint32_t group_count;
        ifs.read(reinterpret_cast<char*>(&group_count), sizeof(group_count));
        fp.supported_groups.resize(group_count);
        ifs.read(reinterpret_cast<char*>(fp.supported_groups.data()), group_count * sizeof(uint16_t));
        
        fp.ja3_hash = calculate_ja3_hash(fp);
        fingerprint_pool_.push_back(fp);
    }
    
    return true;
}

bool FingerprintRandomizer::save_fingerprint_to_cache(const std::string& cache_file) {
    std::ofstream ofs(cache_file, std::ios::binary);
    if (!ofs.is_open()) return false;
    
    uint32_t count = fingerprint_pool_.size();
    ofs.write(reinterpret_cast<const char*>(&count), sizeof(count));
    
    for (const auto& fp : fingerprint_pool_) {
        uint32_t name_len = fp.name.length();
        ofs.write(reinterpret_cast<const char*>(&name_len), sizeof(name_len));
        ofs.write(fp.name.c_str(), name_len);
        
        uint32_t cipher_count = fp.cipher_suites.size();
        ofs.write(reinterpret_cast<const char*>(&cipher_count), sizeof(cipher_count));
        ofs.write(reinterpret_cast<const char*>(fp.cipher_suites.data()), cipher_count * sizeof(uint16_t));
        
        uint32_t group_count = fp.supported_groups.size();
        ofs.write(reinterpret_cast<const char*>(&group_count), sizeof(group_count));
        ofs.write(reinterpret_cast<const char*>(fp.supported_groups.data()), group_count * sizeof(uint16_t));
    }
    
    return true;
}