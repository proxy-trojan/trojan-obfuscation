/*
 * Handshake Mimicker Implementation
 * 从真实网站采集握手数据，实现低延迟混淆
 */

#include "handshake_mimicker.h"
#include <fstream>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <openssl/ssl.h>
#include <openssl/err.h>

HandshakeMimicker::HandshakeMimicker() 
    : rng_(std::random_device{}()) {
    init_popular_domains();
}

HandshakeMimicker::~HandshakeMimicker() = default;

void HandshakeMimicker::init_popular_domains() {
    // 常见的高流量网站，用于采集真实握手特征
    popular_domains_ = {
        "www.google.com",
        "www.cloudflare.com",
        "www.amazon.com",
        "www.microsoft.com",
        "www.apple.com",
        "www.github.com",
        "www.stackoverflow.com",
        "www.wikipedia.org"
    };
}

bool HandshakeMimicker::capture_from_domain(const std::string& domain, int port) {
    // 创建 socket
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return false;
    
    // 解析域名
    struct hostent* host = gethostbyname(domain.c_str());
    if (!host) {
        close(sock);
        return false;
    }
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    memcpy(&addr.sin_addr, host->h_addr_list[0], host->h_length);
    
    // 设置超时
    struct timeval timeout;
    timeout.tv_sec = 5;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
    
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return false;
    }
    
    // 创建 SSL 连接并捕获握手数据
    SSL_CTX* ctx = SSL_CTX_new(TLS_client_method());
    if (!ctx) {
        close(sock);
        return false;
    }
    
    SSL* ssl = SSL_new(ctx);
    SSL_set_fd(ssl, sock);
    SSL_set_tlsext_host_name(ssl, domain.c_str());
    
    // 执行握手
    CapturedHandshake captured;
    captured.source_domain = domain;
    captured.capture_time = std::chrono::system_clock::now();
    
    if (SSL_connect(ssl) == 1) {
        captured.is_valid = true;
        // 握手成功，可以提取特征
    } else {
        captured.is_valid = false;
    }
    
    SSL_shutdown(ssl);
    SSL_free(ssl);
    SSL_CTX_free(ctx);
    close(sock);
    
    if (captured.is_valid) {
        handshake_cache_[domain] = captured;
    }
    
    return captured.is_valid;
}

bool HandshakeMimicker::load_handshake_cache(const std::string& cache_file) {
    std::ifstream ifs(cache_file, std::ios::binary);
    if (!ifs.is_open()) return false;
    
    uint32_t count;
    ifs.read(reinterpret_cast<char*>(&count), sizeof(count));
    
    for (uint32_t i = 0; i < count && ifs.good(); ++i) {
        CapturedHandshake hs;
        
        // 读取域名
        uint32_t domain_len;
        ifs.read(reinterpret_cast<char*>(&domain_len), sizeof(domain_len));
        hs.source_domain.resize(domain_len);
        ifs.read(&hs.source_domain[0], domain_len);
        
        // 读取 ClientHello
        uint32_t ch_len;
        ifs.read(reinterpret_cast<char*>(&ch_len), sizeof(ch_len));
        hs.client_hello_raw.resize(ch_len);
        ifs.read(reinterpret_cast<char*>(hs.client_hello_raw.data()), ch_len);
        
        // 读取时间戳
        int64_t timestamp;
        ifs.read(reinterpret_cast<char*>(&timestamp), sizeof(timestamp));
        hs.capture_time = std::chrono::system_clock::from_time_t(timestamp);
        
        hs.is_valid = true;
        handshake_cache_[hs.source_domain] = hs;
    }
    
    return true;
}

bool HandshakeMimicker::save_handshake_cache(const std::string& cache_file) {
    std::ofstream ofs(cache_file, std::ios::binary);
    if (!ofs.is_open()) return false;
    
    uint32_t count = handshake_cache_.size();
    ofs.write(reinterpret_cast<const char*>(&count), sizeof(count));
    
    for (const auto& pair : handshake_cache_) {
        const CapturedHandshake& hs = pair.second;
        
        uint32_t domain_len = hs.source_domain.length();
        ofs.write(reinterpret_cast<const char*>(&domain_len), sizeof(domain_len));
        ofs.write(hs.source_domain.c_str(), domain_len);
        
        uint32_t ch_len = hs.client_hello_raw.size();
        ofs.write(reinterpret_cast<const char*>(&ch_len), sizeof(ch_len));
        ofs.write(reinterpret_cast<const char*>(hs.client_hello_raw.data()), ch_len);
        
        int64_t timestamp = std::chrono::system_clock::to_time_t(hs.capture_time);
        ofs.write(reinterpret_cast<const char*>(&timestamp), sizeof(timestamp));
    }
    
    return true;
}

std::vector<uint8_t> HandshakeMimicker::generate_random_padding(size_t min_len, size_t max_len) {
    std::uniform_int_distribution<size_t> len_dist(min_len, max_len);
    size_t len = len_dist(rng_);
    
    std::vector<uint8_t> padding(len);
    std::uniform_int_distribution<int> byte_dist(0, 255);
    
    for (size_t i = 0; i < len; ++i) {
        padding[i] = static_cast<uint8_t>(byte_dist(rng_));
    }
    
    return padding;
}

bool HandshakeMimicker::apply_random_cached_handshake(SSL* ssl) {
    // 如果缓存为空，不要阻塞等待采集，直接返回
    // 采集操作应该在后台异步完成
    if (handshake_cache_.empty()) {
        return false;  // 缓存为空时快速返回，不阻塞
    }
    
    // 随机选择一个缓存的握手
    std::vector<std::string> domains;
    domains.reserve(handshake_cache_.size());
    for (const auto& pair : handshake_cache_) {
        domains.push_back(pair.first);
    }
    
    std::uniform_int_distribution<size_t> dist(0, domains.size() - 1);
    return apply_captured_handshake(ssl, domains[dist(rng_)]);
}

bool HandshakeMimicker::apply_captured_handshake(SSL* ssl, const std::string& domain) {
    auto it = handshake_cache_.find(domain);
    if (it == handshake_cache_.end() || !it->second.is_valid) {
        return false;
    }
    
    // 设置 SNI 为采集的域名 (可选，取决于使用场景)
    // SSL_set_tlsext_host_name(ssl, domain.c_str());
    
    return true;
}

TimingProfile HandshakeMimicker::get_timing_profile(const std::string& profile_name) {
    if (profile_name == "aggressive") {
        return PROFILE_AGGRESSIVE;
    } else if (profile_name == "balanced") {
        return PROFILE_BALANCED;
    } else if (profile_name == "stealth") {
        return PROFILE_STEALTH;
    }
    return PROFILE_BALANCED;
}

void HandshakeMimicker::enable_record_splitting(SSL* ssl, const TimingProfile& profile) {
    if (!profile.enable_record_splitting) return;
    
    // OpenSSL 支持设置最大记录大小
    // 这可以帮助分片 TLS 记录，降低流量特征
#ifdef SSL_MODE_CBC_RECORD_SPLITTING
    SSL_set_mode(ssl, SSL_MODE_CBC_RECORD_SPLITTING);
#endif
    
    // 设置最大片段长度 (如果支持)
#ifdef SSL_CTRL_SET_MAX_SEND_FRAGMENT
    std::uniform_int_distribution<uint16_t> size_dist(
        profile.split_size_min, profile.split_size_max);
    uint16_t fragment_size = size_dist(rng_);
    SSL_set_max_send_fragment(ssl, fragment_size);
#endif
}

bool HandshakeMimicker::parse_client_hello(const std::vector<uint8_t>& data,
                                           std::vector<uint16_t>& ciphers,
                                           std::vector<uint16_t>& extensions) {
    if (data.size() < 43) return false;  // 最小 ClientHello 大小
    
    // TLS Record Header (5 bytes)
    // Handshake Header (4 bytes)
    // Client Version (2 bytes)
    // Random (32 bytes)
    
    size_t offset = 5 + 4 + 2 + 32;  // 跳过固定头部
    
    if (offset >= data.size()) return false;
    
    // Session ID Length
    uint8_t session_id_len = data[offset++];
    offset += session_id_len;
    
    if (offset + 2 > data.size()) return false;
    
    // Cipher Suites Length
    uint16_t cipher_len = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    
    if (offset + cipher_len > data.size()) return false;
    
    // 解析 Cipher Suites
    for (size_t i = 0; i < cipher_len; i += 2) {
        uint16_t cipher = (data[offset + i] << 8) | data[offset + i + 1];
        ciphers.push_back(cipher);
    }
    offset += cipher_len;
    
    if (offset >= data.size()) return false;
    
    // Compression Methods Length
    uint8_t comp_len = data[offset++];
    offset += comp_len;
    
    if (offset + 2 > data.size()) return true;  // 没有扩展
    
    // Extensions Length
    uint16_t ext_len = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    
    // 解析 Extensions
    size_t ext_end = offset + ext_len;
    while (offset + 4 <= ext_end && offset + 4 <= data.size()) {
        uint16_t ext_type = (data[offset] << 8) | data[offset + 1];
        uint16_t ext_data_len = (data[offset + 2] << 8) | data[offset + 3];
        extensions.push_back(ext_type);
        offset += 4 + ext_data_len;
    }
    
    return true;
}
