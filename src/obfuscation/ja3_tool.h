/*
 * JA3 Fingerprint Verification Tool
 * 用于验证和分析 TLS ClientHello 指纹
 */

#ifndef _JA3_TOOL_H_
#define _JA3_TOOL_H_

#include <string>
#include <vector>
#include <cstdint>
#include <map>

// JA3 指纹结构
struct JA3Fingerprint {
    uint16_t tls_version;
    std::vector<uint16_t> cipher_suites;
    std::vector<uint16_t> extensions;
    std::vector<uint16_t> elliptic_curves;
    std::vector<uint8_t> ec_point_formats;
    
    std::string ja3_string;
    std::string ja3_hash;
};

// 已知的 JA3 指纹数据库
struct KnownFingerprint {
    std::string ja3_hash;
    std::string description;
    std::string browser;
    std::string os;
    bool is_suspicious;
};

class JA3Tool {
public:
    JA3Tool();
    ~JA3Tool();
    
    // 从原始 ClientHello 数据解析 JA3
    bool parse_client_hello(const std::vector<uint8_t>& data, JA3Fingerprint& fp);
    
    // 计算 JA3 字符串和哈希
    std::string calculate_ja3_string(const JA3Fingerprint& fp);
    std::string calculate_ja3_hash(const std::string& ja3_string);
    std::string calculate_ja3_hash(const JA3Fingerprint& fp);
    
    // 验证指纹
    bool verify_fingerprint(const std::string& ja3_hash, std::string& description);
    bool is_known_browser(const std::string& ja3_hash);
    bool is_suspicious(const std::string& ja3_hash);
    
    // 指纹数据库管理
    void add_known_fingerprint(const KnownFingerprint& fp);
    bool load_fingerprint_database(const std::string& filename);
    bool save_fingerprint_database(const std::string& filename);
    
    // 获取指纹信息
    std::string get_fingerprint_info(const std::string& ja3_hash);
    std::vector<KnownFingerprint> get_all_known_fingerprints() const;
    
    // 比较两个指纹的相似度 (0.0 - 1.0)
    double compare_fingerprints(const JA3Fingerprint& fp1, const JA3Fingerprint& fp2);
    
    // 生成报告
    std::string generate_report(const JA3Fingerprint& fp);

private:
    std::map<std::string, KnownFingerprint> fingerprint_db_;
    
    void init_default_database();
    
    // 解析辅助函数
    bool parse_cipher_suites(const uint8_t* data, size_t len, std::vector<uint16_t>& ciphers);
    bool parse_extensions(const uint8_t* data, size_t len, JA3Fingerprint& fp);
    bool parse_supported_groups(const uint8_t* data, size_t len, std::vector<uint16_t>& groups);
    bool parse_ec_point_formats(const uint8_t* data, size_t len, std::vector<uint8_t>& formats);
    
    // 过滤 GREASE 值
    std::vector<uint16_t> filter_grease(const std::vector<uint16_t>& values);
    bool is_grease_value(uint16_t value);
};

#endif // _JA3_TOOL_H_