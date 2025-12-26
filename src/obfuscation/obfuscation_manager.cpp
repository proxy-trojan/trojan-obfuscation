/*
 * Obfuscation Manager Implementation
 */

#include "obfuscation_manager.h"
#include "../core/config.h"
#include <thread>
#include <algorithm>
#include <cstring>

ObfuscationManager& get_obfuscation_manager() {
    // 使用C++11标准保证的线程安全的局部静态变量初始化
    // 这比双重检查锁定更安全，并且在C++11及以上版本中是线程安全的
    static ObfuscationManager instance;
    return instance;
}

ObfuscationManager::ObfuscationManager()
    : rng_(std::random_device{}()) {
    ja3_tool_ = std::make_unique<JA3Tool>();
}

ObfuscationManager::~ObfuscationManager() {
    save_caches();
}

bool ObfuscationManager::initialize(const Config& config) {
    ObfuscationSettings settings;
    
    settings.enabled = config.obfuscation.enabled;
    settings.fingerprint_enabled = config.obfuscation.fingerprint.enabled;
    settings.fingerprint_type = config.obfuscation.fingerprint.type;
    settings.grease_enabled = config.obfuscation.fingerprint.grease;
    settings.handshake_enabled = config.obfuscation.handshake.enabled;
    settings.handshake_cache_file = config.obfuscation.handshake.cache_file;
    settings.prefetch = config.obfuscation.handshake.prefetch;
    settings.prefetch_domains = config.obfuscation.handshake.prefetch_domains;
    settings.timing_profile = config.obfuscation.timing.profile;
    settings.min_delay_ms = config.obfuscation.timing.min_delay_ms;
    settings.max_delay_ms = config.obfuscation.timing.max_delay_ms;
    settings.jitter_ms = config.obfuscation.timing.jitter_ms;
    settings.padding_enabled = config.obfuscation.padding.enabled;
    settings.padding_min = config.obfuscation.padding.min_bytes;
    settings.padding_max = config.obfuscation.padding.max_bytes;
    settings.record_splitting_enabled = config.obfuscation.record_splitting.enabled;
    settings.split_min = config.obfuscation.record_splitting.min_fragment;
    settings.split_max = config.obfuscation.record_splitting.max_fragment;
    settings.cache_enabled = config.obfuscation.cache.enabled;
    settings.cache_directory = config.obfuscation.cache.directory;
    settings.enforce_tls13 = config.obfuscation.tls.enforce_tls13;
    settings.tls_min_version = config.obfuscation.tls.min_version;
    
    return initialize(settings);
}


bool ObfuscationManager::initialize(const ObfuscationSettings& settings) {
    settings_ = settings;
    
    if (!settings_.enabled) {
        return true;  // 未启用，直接返回
    }
    
    // 初始化指纹随机化器
    if (settings_.fingerprint_enabled) {
        fingerprint_randomizer_ = std::make_unique<FingerprintRandomizer>();
        fingerprint_randomizer_->set_grease_enabled(settings_.grease_enabled);
        
        // 尝试加载缓存
        if (settings_.cache_enabled && !settings_.cache_directory.empty()) {
            std::string cache_file = settings_.cache_directory + "/fingerprint.bin";
            fingerprint_randomizer_->load_fingerprint_from_cache(cache_file);
        }
    }
    
    // 初始化握手模拟器
    if (settings_.handshake_enabled) {
        handshake_mimicker_ = std::make_unique<HandshakeMimicker>();
        
        // 尝试加载缓存
        if (!settings_.handshake_cache_file.empty()) {
            handshake_mimicker_->load_handshake_cache(settings_.handshake_cache_file);
        }
        
        // 异步预取
        if (settings_.prefetch) {
            prefetch_handshakes_async();
        }
    }
    
    // 设置时序配置
    timing_profile_ = get_timing_profile_from_name(settings_.timing_profile);
    
    // 如果有自定义时序设置，覆盖预设
    if (settings_.min_delay_ms > 0 || settings_.max_delay_ms > 0) {
        timing_profile_.min_delay_ms = settings_.min_delay_ms;
        timing_profile_.max_delay_ms = settings_.max_delay_ms;
        timing_profile_.jitter_ms = settings_.jitter_ms;
    }
    
    return true;
}

TimingProfile ObfuscationManager::get_timing_profile_from_name(const std::string& name) {
    if (name == "aggressive") {
        return HandshakeMimicker::PROFILE_AGGRESSIVE;
    } else if (name == "stealth") {
        return HandshakeMimicker::PROFILE_STEALTH;
    }
    return HandshakeMimicker::PROFILE_BALANCED;
}

bool ObfuscationManager::apply_client_obfuscation(SSL* ssl) {
    if (!ssl || !settings_.enabled) return false;
    
    bool success = true;
    
    // 0. 强制 TLS 1.3 (如果配置)
    if (settings_.enforce_tls13 && fingerprint_randomizer_) {
        fingerprint_randomizer_->enforce_tls13(ssl);
    }
    
    // 1. 应用指纹随机化
    if (settings_.fingerprint_enabled && fingerprint_randomizer_) {
        success &= fingerprint_randomizer_->apply_fingerprint_by_name(
            ssl, settings_.fingerprint_type);
        
        fingerprint_randomizer_->shuffle_extensions(ssl);
        current_ja3_hash_ = fingerprint_randomizer_->get_current_ja3_hash();
    }
    
    // 2. 应用握手模拟
    if (settings_.handshake_enabled && handshake_mimicker_) {
        handshake_mimicker_->apply_random_cached_handshake(ssl);
        
        if (settings_.record_splitting_enabled) {
            TimingProfile split_profile = timing_profile_;
            split_profile.enable_record_splitting = true;
            split_profile.split_size_min = settings_.split_min;
            split_profile.split_size_max = settings_.split_max;
            handshake_mimicker_->enable_record_splitting(ssl, split_profile);
        }
    }
    
    // 3. 应用时序混淆
    apply_timing_obfuscation(ssl);
    
    if (success) {
        stats_.connections_obfuscated++;
    }
    
    return success;
}


bool ObfuscationManager::apply_server_obfuscation(SSL_CTX* ctx) {
    if (!ctx) return false;
    
    // 服务端配置会话管理
    SSL_CTX_set_session_cache_mode(ctx, SSL_SESS_CACHE_SERVER);
    SSL_CTX_set_timeout(ctx, 3600);
    
    return true;
}

std::string ObfuscationManager::obfuscate_payload(const std::string& payload) {
    if (!settings_.padding_enabled) {
        return payload;
    }
    
    std::string padding = generate_padding();
    stats_.bytes_padded += padding.size();
    
    // 格式: [padding_len:2][padding][payload]
    std::string result;
    uint16_t padding_len = padding.size();
    result.push_back(static_cast<char>(padding_len >> 8));
    result.push_back(static_cast<char>(padding_len & 0xFF));
    result += padding;
    result += payload;
    
    return result;
}

std::string ObfuscationManager::deobfuscate_payload(const std::string& data) {
    if (!settings_.padding_enabled || data.size() < 2) {
        return data;
    }
    
    uint16_t padding_len = (static_cast<uint8_t>(data[0]) << 8) | 
                           static_cast<uint8_t>(data[1]);
    
    if (data.size() < 2 + padding_len) {
        return data;
    }
    
    return data.substr(2 + padding_len);
}

uint32_t ObfuscationManager::get_random_delay() {
    std::uniform_int_distribution<uint32_t> dist(
        timing_profile_.min_delay_ms,
        timing_profile_.max_delay_ms);
    
    uint32_t base_delay = dist(rng_);
    
    if (timing_profile_.jitter_ms > 0) {
        std::uniform_int_distribution<int32_t> jitter_dist(
            -static_cast<int32_t>(timing_profile_.jitter_ms),
            static_cast<int32_t>(timing_profile_.jitter_ms));
        int32_t jitter = jitter_dist(rng_);
        base_delay = std::max(0, static_cast<int32_t>(base_delay) + jitter);
    }
    
    if (delay_callback_) {
        delay_callback_(base_delay);
    }
    
    return base_delay;
}

void ObfuscationManager::prefetch_handshakes_async() {
    if (!handshake_mimicker_) return;
    
    std::vector<std::string> domains = settings_.prefetch_domains;
    if (domains.empty()) {
        domains = {"www.google.com", "www.cloudflare.com", "www.microsoft.com"};
    }
    
    std::thread([this, domains]() {
        for (const auto& domain : domains) {
            handshake_mimicker_->capture_from_domain(domain);
        }
        
        if (!settings_.handshake_cache_file.empty()) {
            handshake_mimicker_->save_handshake_cache(settings_.handshake_cache_file);
        }
    }).detach();
}


bool ObfuscationManager::save_caches() {
    bool success = true;
    
    if (fingerprint_randomizer_ && settings_.cache_enabled && 
        !settings_.cache_directory.empty()) {
        std::string cache_file = settings_.cache_directory + "/fingerprint.bin";
        success &= fingerprint_randomizer_->save_fingerprint_to_cache(cache_file);
    }
    
    if (handshake_mimicker_ && !settings_.handshake_cache_file.empty()) {
        success &= handshake_mimicker_->save_handshake_cache(
            settings_.handshake_cache_file);
    }
    
    return success;
}

bool ObfuscationManager::load_caches() {
    bool success = true;
    
    if (fingerprint_randomizer_ && settings_.cache_enabled && 
        !settings_.cache_directory.empty()) {
        std::string cache_file = settings_.cache_directory + "/fingerprint.bin";
        if (fingerprint_randomizer_->load_fingerprint_from_cache(cache_file)) {
            stats_.cache_hits++;
        } else {
            stats_.cache_misses++;
        }
    }
    
    if (handshake_mimicker_ && !settings_.handshake_cache_file.empty()) {
        if (handshake_mimicker_->load_handshake_cache(settings_.handshake_cache_file)) {
            stats_.cache_hits++;
        } else {
            stats_.cache_misses++;
        }
    }
    
    return success;
}

JA3Tool& ObfuscationManager::get_ja3_tool() {
    return *ja3_tool_;
}

std::string ObfuscationManager::get_current_ja3_hash() const {
    return current_ja3_hash_;
}

ObfuscationManager::Stats ObfuscationManager::get_stats() const {
    return stats_;
}

void ObfuscationManager::set_delay_callback(DelayCallback cb) {
    delay_callback_ = std::move(cb);
}

void ObfuscationManager::apply_timing_obfuscation(SSL* ssl) {
#ifdef SSL_MODE_CBC_RECORD_SPLITTING
    SSL_set_mode(ssl, SSL_MODE_CBC_RECORD_SPLITTING);
#endif
    
    if (settings_.record_splitting_enabled) {
        std::uniform_int_distribution<uint16_t> size_dist(
            settings_.split_min, settings_.split_max);
#ifdef SSL_CTRL_SET_MAX_SEND_FRAGMENT
        SSL_set_max_send_fragment(ssl, size_dist(rng_));
#endif
    }
}

std::string ObfuscationManager::generate_padding() {
    std::uniform_int_distribution<uint16_t> len_dist(
        settings_.padding_min, settings_.padding_max);
    uint16_t len = len_dist(rng_);
    
    if (len == 0) return "";
    
    // 使用更高效的随机填充方式
    std::string padding(len, '\0');
    
    // 每次生成 8 字节随机数据，减少随机数生成次数
    uint64_t* ptr = reinterpret_cast<uint64_t*>(&padding[0]);
    size_t full_blocks = len / 8;
    for (size_t i = 0; i < full_blocks; ++i) {
        ptr[i] = rng_();
    }
    
    // 处理剩余字节
    size_t remaining = len % 8;
    if (remaining > 0) {
        uint64_t last = rng_();
        std::memcpy(&padding[full_blocks * 8], &last, remaining);
    }
    
    return padding;
}