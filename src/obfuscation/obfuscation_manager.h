/*
 * Obfuscation Manager
 * 统一管理所有混淆功能，提供简洁的 API
 */

#ifndef _OBFUSCATION_MANAGER_H_
#define _OBFUSCATION_MANAGER_H_

#include <string>
#include <memory>
#include <chrono>
#include <functional>
#include <openssl/ssl.h>
#include "fingerprint.h"
#include "handshake_mimicker.h"
#include "ja3_tool.h"

// 前向声明
class Config;

// 混淆配置 (从 Config 类读取)
struct ObfuscationSettings {
    bool enabled = false;
    
    // 指纹混淆
    bool fingerprint_enabled = true;
    std::string fingerprint_type = "random";
    bool grease_enabled = true;
    
    // 握手混淆
    bool handshake_enabled = true;
    std::string handshake_cache_file;
    bool prefetch = true;
    std::vector<std::string> prefetch_domains;
    
    // 时序混淆
    std::string timing_profile = "aggressive";
    uint32_t min_delay_ms = 0;
    uint32_t max_delay_ms = 5;
    uint32_t jitter_ms = 2;
    
    // 协议混淆
    bool padding_enabled = false;
    uint16_t padding_min = 0;
    uint16_t padding_max = 64;
    
    // 记录分片
    bool record_splitting_enabled = false;
    uint16_t split_min = 64;
    uint16_t split_max = 256;
    
    // 缓存
    bool cache_enabled = true;
    std::string cache_directory;
    
    // TLS 版本控制
    bool enforce_tls13 = false;
    uint16_t tls_min_version = 0x0303;  // TLS 1.2
};

class ObfuscationManager {
public:
    ObfuscationManager();
    ~ObfuscationManager();
    
    // 从 Config 初始化
    bool initialize(const Config& config);
    
    // 直接使用 settings 初始化
    bool initialize(const ObfuscationSettings& settings);
    
    // 应用混淆到 SSL 连接 (客户端)
    bool apply_client_obfuscation(SSL* ssl);
    
    // 应用混淆到 SSL 上下文 (服务端)
    bool apply_server_obfuscation(SSL_CTX* ctx);
    
    // 生成混淆后的协议数据
    std::string obfuscate_payload(const std::string& payload);
    std::string deobfuscate_payload(const std::string& data);
    
    // 获取随机延迟 (毫秒)
    uint32_t get_random_delay();
    
    // 预取握手数据 (后台异步)
    void prefetch_handshakes_async();
    
    // 保存/加载缓存
    bool save_caches();
    bool load_caches();
    
    // JA3 工具访问
    JA3Tool& get_ja3_tool();
    std::string get_current_ja3_hash() const;
    
    // 获取统计信息
    struct Stats {
        uint64_t connections_obfuscated = 0;
        uint64_t bytes_padded = 0;
        uint64_t cache_hits = 0;
        uint64_t cache_misses = 0;
        std::chrono::milliseconds avg_delay{0};
    };
    Stats get_stats() const;
    
    // 设置回调
    using DelayCallback = std::function<void(uint32_t)>;
    void set_delay_callback(DelayCallback cb);
    
    // 检查是否启用
    bool is_enabled() const { return settings_.enabled; }

private:
    ObfuscationSettings settings_;
    std::unique_ptr<FingerprintRandomizer> fingerprint_randomizer_;
    std::unique_ptr<HandshakeMimicker> handshake_mimicker_;
    std::unique_ptr<JA3Tool> ja3_tool_;
    TimingProfile timing_profile_;
    Stats stats_;
    DelayCallback delay_callback_;
    std::mt19937 rng_;
    std::string current_ja3_hash_;
    
    void apply_timing_obfuscation(SSL* ssl);
    std::string generate_padding();
    TimingProfile get_timing_profile_from_name(const std::string& name);
};

// 全局单例访问
ObfuscationManager& get_obfuscation_manager();

#endif // _OBFUSCATION_MANAGER_H_
