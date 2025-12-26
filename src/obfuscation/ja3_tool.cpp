/*
 * JA3 Fingerprint Verification Tool Implementation
 */

#include "ja3_tool.h"
#include <sstream>
#include <iomanip>
#include <fstream>
#include <algorithm>
#include <cstring>
#include <openssl/md5.h>

JA3Tool::JA3Tool() {
    init_default_database();
}

JA3Tool::~JA3Tool() = default;

void JA3Tool::init_default_database() {
    // Chrome 指纹
    fingerprint_db_["cd08e31494f9531f560d64c695473da9"] = {
        "cd08e31494f9531f560d64c695473da9", "Chrome 120 on Windows", "Chrome", "Windows", false
    };
    fingerprint_db_["b32309a26951912be7dba376398abc3b"] = {
        "b32309a26951912be7dba376398abc3b", "Chrome 120 on macOS", "Chrome", "macOS", false
    };
    
    // Firefox 指纹
    fingerprint_db_["579ccef312d18482fc42e2b822ca2430"] = {
        "579ccef312d18482fc42e2b822ca2430", "Firefox 121 on Windows", "Firefox", "Windows", false
    };
    fingerprint_db_["9e10692f1b7f78228b2d4e424db3a98c"] = {
        "9e10692f1b7f78228b2d4e424db3a98c", "Firefox 121 on Linux", "Firefox", "Linux", false
    };
    
    // Safari 指纹
    fingerprint_db_["773906b0efdefa24a7f2b8eb6985bf37"] = {
        "773906b0efdefa24a7f2b8eb6985bf37", "Safari 17 on macOS", "Safari", "macOS", false
    };
    
    // Edge 指纹
    fingerprint_db_["2d110c1e3925c9e5aa3a3c5a0c7e3a8f"] = {
        "2d110c1e3925c9e5aa3a3c5a0c7e3a8f", "Edge 120 on Windows", "Edge", "Windows", false
    };
    
    // 可疑指纹
    fingerprint_db_["e7d705a3286e19ea42f587b344ee6865"] = {
        "e7d705a3286e19ea42f587b344ee6865", "Known scanner/bot", "Scanner", "Unknown", true
    };
}


bool JA3Tool::is_grease_value(uint16_t value) {
    return (value & 0x0f0f) == 0x0a0a;
}

std::vector<uint16_t> JA3Tool::filter_grease(const std::vector<uint16_t>& values) {
    std::vector<uint16_t> filtered;
    for (uint16_t v : values) {
        if (!is_grease_value(v)) {
            filtered.push_back(v);
        }
    }
    return filtered;
}

bool JA3Tool::parse_client_hello(const std::vector<uint8_t>& data, JA3Fingerprint& fp) {
    if (data.size() < 43) return false;  // 最小 ClientHello 大小
    
    size_t offset = 0;
    
    // TLS Record Header (5 bytes)
    if (data[0] != 0x16) return false;  // Handshake
    offset += 5;
    
    // Handshake Header (4 bytes)
    if (data[offset] != 0x01) return false;  // ClientHello
    offset += 4;
    
    // Client Version (2 bytes)
    fp.tls_version = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    
    // Random (32 bytes)
    offset += 32;
    
    // Session ID
    if (offset >= data.size()) return false;
    uint8_t session_id_len = data[offset++];
    offset += session_id_len;
    
    // Cipher Suites
    if (offset + 2 > data.size()) return false;
    uint16_t cipher_len = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    
    if (offset + cipher_len > data.size()) return false;
    if (!parse_cipher_suites(&data[offset], cipher_len, fp.cipher_suites)) return false;
    offset += cipher_len;
    
    // Compression Methods
    if (offset >= data.size()) return false;
    uint8_t comp_len = data[offset++];
    offset += comp_len;
    
    // Extensions
    if (offset + 2 > data.size()) return true;  // 没有扩展也是有效的
    uint16_t ext_len = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    
    if (offset + ext_len > data.size()) return false;
    if (!parse_extensions(&data[offset], ext_len, fp)) return false;
    
    return true;
}

bool JA3Tool::parse_cipher_suites(const uint8_t* data, size_t len, std::vector<uint16_t>& ciphers) {
    ciphers.clear();
    for (size_t i = 0; i + 1 < len; i += 2) {
        uint16_t cipher = (data[i] << 8) | data[i + 1];
        ciphers.push_back(cipher);
    }
    return true;
}


bool JA3Tool::parse_extensions(const uint8_t* data, size_t len, JA3Fingerprint& fp) {
    fp.extensions.clear();
    size_t offset = 0;
    
    while (offset + 4 <= len) {
        uint16_t ext_type = (data[offset] << 8) | data[offset + 1];
        uint16_t ext_len = (data[offset + 2] << 8) | data[offset + 3];
        offset += 4;
        
        if (offset + ext_len > len) break;
        
        fp.extensions.push_back(ext_type);
        
        // 解析特定扩展
        switch (ext_type) {
            case 10:  // supported_groups
                parse_supported_groups(&data[offset], ext_len, fp.elliptic_curves);
                break;
            case 11:  // ec_point_formats
                parse_ec_point_formats(&data[offset], ext_len, fp.ec_point_formats);
                break;
        }
        
        offset += ext_len;
    }
    
    return true;
}

bool JA3Tool::parse_supported_groups(const uint8_t* data, size_t len, std::vector<uint16_t>& groups) {
    groups.clear();
    if (len < 2) return false;
    
    uint16_t groups_len = (data[0] << 8) | data[1];
    for (size_t i = 2; i + 1 < len && i < groups_len + 2; i += 2) {
        uint16_t group = (data[i] << 8) | data[i + 1];
        groups.push_back(group);
    }
    return true;
}

bool JA3Tool::parse_ec_point_formats(const uint8_t* data, size_t len, std::vector<uint8_t>& formats) {
    formats.clear();
    if (len < 1) return false;
    
    uint8_t formats_len = data[0];
    for (size_t i = 1; i < len && i <= formats_len; ++i) {
        formats.push_back(data[i]);
    }
    return true;
}

std::string JA3Tool::calculate_ja3_string(const JA3Fingerprint& fp) {
    std::ostringstream ja3;
    
    // TLS Version
    ja3 << fp.tls_version << ",";
    
    // Cipher Suites (过滤 GREASE)
    auto ciphers = filter_grease(fp.cipher_suites);
    for (size_t i = 0; i < ciphers.size(); ++i) {
        if (i > 0) ja3 << "-";
        ja3 << ciphers[i];
    }
    ja3 << ",";
    
    // Extensions (过滤 GREASE)
    auto extensions = filter_grease(fp.extensions);
    for (size_t i = 0; i < extensions.size(); ++i) {
        if (i > 0) ja3 << "-";
        ja3 << extensions[i];
    }
    ja3 << ",";
    
    // Elliptic Curves (过滤 GREASE)
    auto curves = filter_grease(fp.elliptic_curves);
    for (size_t i = 0; i < curves.size(); ++i) {
        if (i > 0) ja3 << "-";
        ja3 << curves[i];
    }
    ja3 << ",";
    
    // EC Point Formats
    for (size_t i = 0; i < fp.ec_point_formats.size(); ++i) {
        if (i > 0) ja3 << "-";
        ja3 << (int)fp.ec_point_formats[i];
    }
    
    return ja3.str();
}


std::string JA3Tool::calculate_ja3_hash(const std::string& ja3_string) {
    unsigned char md5_result[MD5_DIGEST_LENGTH];
    MD5(reinterpret_cast<const unsigned char*>(ja3_string.c_str()), 
        ja3_string.length(), md5_result);
    
    std::ostringstream hash;
    for (int i = 0; i < MD5_DIGEST_LENGTH; ++i) {
        hash << std::hex << std::setfill('0') << std::setw(2) << (int)md5_result[i];
    }
    
    return hash.str();
}

std::string JA3Tool::calculate_ja3_hash(const JA3Fingerprint& fp) {
    return calculate_ja3_hash(calculate_ja3_string(fp));
}

bool JA3Tool::verify_fingerprint(const std::string& ja3_hash, std::string& description) {
    auto it = fingerprint_db_.find(ja3_hash);
    if (it != fingerprint_db_.end()) {
        description = it->second.description;
        return true;
    }
    description = "Unknown fingerprint";
    return false;
}

bool JA3Tool::is_known_browser(const std::string& ja3_hash) {
    auto it = fingerprint_db_.find(ja3_hash);
    if (it != fingerprint_db_.end()) {
        return !it->second.is_suspicious;
    }
    return false;
}

bool JA3Tool::is_suspicious(const std::string& ja3_hash) {
    auto it = fingerprint_db_.find(ja3_hash);
    if (it != fingerprint_db_.end()) {
        return it->second.is_suspicious;
    }
    return false;  // 未知指纹不一定可疑
}

void JA3Tool::add_known_fingerprint(const KnownFingerprint& fp) {
    fingerprint_db_[fp.ja3_hash] = fp;
}

std::string JA3Tool::get_fingerprint_info(const std::string& ja3_hash) {
    auto it = fingerprint_db_.find(ja3_hash);
    if (it != fingerprint_db_.end()) {
        std::ostringstream info;
        info << "JA3: " << ja3_hash << "\n"
             << "Description: " << it->second.description << "\n"
             << "Browser: " << it->second.browser << "\n"
             << "OS: " << it->second.os << "\n"
             << "Suspicious: " << (it->second.is_suspicious ? "Yes" : "No");
        return info.str();
    }
    return "Unknown fingerprint: " + ja3_hash;
}

std::vector<KnownFingerprint> JA3Tool::get_all_known_fingerprints() const {
    std::vector<KnownFingerprint> result;
    for (const auto& pair : fingerprint_db_) {
        result.push_back(pair.second);
    }
    return result;
}


double JA3Tool::compare_fingerprints(const JA3Fingerprint& fp1, const JA3Fingerprint& fp2) {
    double score = 0.0;
    double total_weight = 0.0;
    
    // TLS Version (权重 0.1)
    if (fp1.tls_version == fp2.tls_version) {
        score += 0.1;
    }
    total_weight += 0.1;
    
    // Cipher Suites (权重 0.4)
    auto c1 = filter_grease(fp1.cipher_suites);
    auto c2 = filter_grease(fp2.cipher_suites);
    if (!c1.empty() && !c2.empty()) {
        size_t common = 0;
        for (uint16_t c : c1) {
            if (std::find(c2.begin(), c2.end(), c) != c2.end()) {
                common++;
            }
        }
        score += 0.4 * (double)common / std::max(c1.size(), c2.size());
    }
    total_weight += 0.4;
    
    // Extensions (权重 0.2)
    auto e1 = filter_grease(fp1.extensions);
    auto e2 = filter_grease(fp2.extensions);
    if (!e1.empty() && !e2.empty()) {
        size_t common = 0;
        for (uint16_t e : e1) {
            if (std::find(e2.begin(), e2.end(), e) != e2.end()) {
                common++;
            }
        }
        score += 0.2 * (double)common / std::max(e1.size(), e2.size());
    }
    total_weight += 0.2;
    
    // Elliptic Curves (权重 0.2)
    auto g1 = filter_grease(fp1.elliptic_curves);
    auto g2 = filter_grease(fp2.elliptic_curves);
    if (!g1.empty() && !g2.empty()) {
        size_t common = 0;
        for (uint16_t g : g1) {
            if (std::find(g2.begin(), g2.end(), g) != g2.end()) {
                common++;
            }
        }
        score += 0.2 * (double)common / std::max(g1.size(), g2.size());
    }
    total_weight += 0.2;
    
    // EC Point Formats (权重 0.1)
    if (!fp1.ec_point_formats.empty() && !fp2.ec_point_formats.empty()) {
        size_t common = 0;
        for (uint8_t f : fp1.ec_point_formats) {
            if (std::find(fp2.ec_point_formats.begin(), fp2.ec_point_formats.end(), f) 
                != fp2.ec_point_formats.end()) {
                common++;
            }
        }
        score += 0.1 * (double)common / 
                 std::max(fp1.ec_point_formats.size(), fp2.ec_point_formats.size());
    }
    total_weight += 0.1;
    
    return score / total_weight;
}

std::string JA3Tool::generate_report(const JA3Fingerprint& fp) {
    std::ostringstream report;
    
    report << "=== JA3 Fingerprint Report ===\n\n";
    
    // JA3 String and Hash
    std::string ja3_str = calculate_ja3_string(fp);
    std::string ja3_hash = calculate_ja3_hash(ja3_str);
    
    report << "JA3 String: " << ja3_str << "\n";
    report << "JA3 Hash: " << ja3_hash << "\n\n";
    
    // TLS Version
    report << "TLS Version: 0x" << std::hex << std::setfill('0') << std::setw(4) 
           << fp.tls_version << std::dec << "\n\n";
    
    // Cipher Suites
    report << "Cipher Suites (" << fp.cipher_suites.size() << "):\n";
    for (uint16_t c : fp.cipher_suites) {
        report << "  0x" << std::hex << std::setfill('0') << std::setw(4) << c;
        if (is_grease_value(c)) report << " (GREASE)";
        report << std::dec << "\n";
    }
    report << "\n";
    
    // Extensions
    report << "Extensions (" << fp.extensions.size() << "):\n";
    for (uint16_t e : fp.extensions) {
        report << "  " << e;
        if (is_grease_value(e)) report << " (GREASE)";
        report << "\n";
    }
    report << "\n";
    
    // Elliptic Curves
    report << "Elliptic Curves (" << fp.elliptic_curves.size() << "):\n";
    for (uint16_t g : fp.elliptic_curves) {
        report << "  0x" << std::hex << std::setfill('0') << std::setw(4) << g;
        if (is_grease_value(g)) report << " (GREASE)";
        report << std::dec << "\n";
    }
    report << "\n";
    
    // EC Point Formats
    report << "EC Point Formats (" << fp.ec_point_formats.size() << "):\n";
    for (uint8_t f : fp.ec_point_formats) {
        report << "  " << (int)f << "\n";
    }
    report << "\n";
    
    // Database lookup
    std::string description;
    if (verify_fingerprint(ja3_hash, description)) {
        report << "Database Match: " << description << "\n";
        report << "Suspicious: " << (is_suspicious(ja3_hash) ? "Yes" : "No") << "\n";
    } else {
        report << "Database Match: Not found\n";
    }
    
    return report.str();
}


bool JA3Tool::load_fingerprint_database(const std::string& filename) {
    std::ifstream ifs(filename, std::ios::binary);
    if (!ifs.is_open()) return false;
    
    uint32_t count;
    ifs.read(reinterpret_cast<char*>(&count), sizeof(count));
    
    for (uint32_t i = 0; i < count && ifs.good(); ++i) {
        KnownFingerprint fp;
        
        // Read ja3_hash
        uint32_t len;
        ifs.read(reinterpret_cast<char*>(&len), sizeof(len));
        fp.ja3_hash.resize(len);
        ifs.read(&fp.ja3_hash[0], len);
        
        // Read description
        ifs.read(reinterpret_cast<char*>(&len), sizeof(len));
        fp.description.resize(len);
        ifs.read(&fp.description[0], len);
        
        // Read browser
        ifs.read(reinterpret_cast<char*>(&len), sizeof(len));
        fp.browser.resize(len);
        ifs.read(&fp.browser[0], len);
        
        // Read os
        ifs.read(reinterpret_cast<char*>(&len), sizeof(len));
        fp.os.resize(len);
        ifs.read(&fp.os[0], len);
        
        // Read is_suspicious
        uint8_t suspicious;
        ifs.read(reinterpret_cast<char*>(&suspicious), sizeof(suspicious));
        fp.is_suspicious = suspicious != 0;
        
        fingerprint_db_[fp.ja3_hash] = fp;
    }
    
    return true;
}

bool JA3Tool::save_fingerprint_database(const std::string& filename) {
    std::ofstream ofs(filename, std::ios::binary);
    if (!ofs.is_open()) return false;
    
    uint32_t count = fingerprint_db_.size();
    ofs.write(reinterpret_cast<const char*>(&count), sizeof(count));
    
    for (const auto& pair : fingerprint_db_) {
        const KnownFingerprint& fp = pair.second;
        
        // Write ja3_hash
        uint32_t len = fp.ja3_hash.length();
        ofs.write(reinterpret_cast<const char*>(&len), sizeof(len));
        ofs.write(fp.ja3_hash.c_str(), len);
        
        // Write description
        len = fp.description.length();
        ofs.write(reinterpret_cast<const char*>(&len), sizeof(len));
        ofs.write(fp.description.c_str(), len);
        
        // Write browser
        len = fp.browser.length();
        ofs.write(reinterpret_cast<const char*>(&len), sizeof(len));
        ofs.write(fp.browser.c_str(), len);
        
        // Write os
        len = fp.os.length();
        ofs.write(reinterpret_cast<const char*>(&len), sizeof(len));
        ofs.write(fp.os.c_str(), len);
        
        // Write is_suspicious
        uint8_t suspicious = fp.is_suspicious ? 1 : 0;
        ofs.write(reinterpret_cast<const char*>(&suspicious), sizeof(suspicious));
    }
    
    return true;
}