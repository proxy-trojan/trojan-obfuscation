/*
 * Handshake Mimicker Module
 * 从真实网站采集握手数据，或生成随机化握手
 */

#ifndef _HANDSHAKE_MIMICKER_H_
#define _HANDSHAKE_MIMICKER_H_

#include <string>
#include <vector>
#include <map>
#include <chrono>
#include <random>
#include <openssl/ssl.h>

// 采集的真实握手数据
struct CapturedHandshake {
    std::string source_domain;
    std::vector<uint8_t> client_hello_raw;
    std::vector<uint8_t> server_hello_raw;
    std::chrono::system_clock::time_point capture_time;
    bool is_valid;
};

// 握手时序配置
struct TimingProfile {
    uint32_t min_delay_ms;
    uint32_t max_delay_ms;
    uint32_t jitter_ms;
    bool enable_record_splitting;
    uint16_t split_size_min;
    uint16_t split_size_max;
};

class HandshakeMimicker {
public:
    HandshakeMimicker();
    ~HandshakeMimicker();

    // 从真实网站采集握手数据 (异步预取)
    bool capture_from_domain(const std::string& domain, int port = 443);
    
    // 加载/保存握手缓存
    bool load_handshake_cache(const std::string& cache_file);
    bool save_handshake_cache(const std::string& cache_file);
    
    // 应用采集的握手特征
    bool apply_captured_handshake(SSL* ssl, const std::string& domain);
    
    // 随机选择一个缓存的握手特征
    bool apply_random_cached_handshake(SSL* ssl);
    
    // 生成随机化的 ClientHello 扩展
    std::vector<uint8_t> generate_random_padding(size_t min_len, size_t max_len);
    
    // TLS Record 分片 (降低特征)
    void enable_record_splitting(SSL* ssl, const TimingProfile& profile);
    
    // 获取时序配置
    TimingProfile get_timing_profile(const std::string& profile_name);
    
    // 预定义的时序配置
    static const TimingProfile PROFILE_AGGRESSIVE;  // 最低延迟
    static const TimingProfile PROFILE_BALANCED;    // 平衡
    static const TimingProfile PROFILE_STEALTH;     // 最高隐蔽

private:
    std::map<std::string, CapturedHandshake> handshake_cache_;
    std::vector<std::string> popular_domains_;
    std::mt19937 rng_;
    
    void init_popular_domains();
    
    // 解析 ClientHello 提取特征
    bool parse_client_hello(const std::vector<uint8_t>& data, 
                           std::vector<uint16_t>& ciphers,
                           std::vector<uint16_t>& extensions);
    
    // 生成符合特征的 ClientHello
    std::vector<uint8_t> generate_mimicked_client_hello(
        const CapturedHandshake& template_handshake);
};

// 预定义时序配置
inline const TimingProfile HandshakeMimicker::PROFILE_AGGRESSIVE = {
    .min_delay_ms = 0,
    .max_delay_ms = 5,
    .jitter_ms = 2,
    .enable_record_splitting = false,
    .split_size_min = 0,
    .split_size_max = 0
};

inline const TimingProfile HandshakeMimicker::PROFILE_BALANCED = {
    .min_delay_ms = 5,
    .max_delay_ms = 50,
    .jitter_ms = 10,
    .enable_record_splitting = true,
    .split_size_min = 64,
    .split_size_max = 256
};

inline const TimingProfile HandshakeMimicker::PROFILE_STEALTH = {
    .min_delay_ms = 20,
    .max_delay_ms = 200,
    .jitter_ms = 50,
    .enable_record_splitting = true,
    .split_size_min = 32,
    .split_size_max = 128
};

#endif // _HANDSHAKE_MIMICKER_H_
