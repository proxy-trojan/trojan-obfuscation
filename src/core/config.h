/*
 * This file is part of the trojan project.
 * Trojan is an unidentifiable mechanism that helps you bypass GFW.
 * Copyright (C) 2017-2020  The Trojan Authors.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _CONFIG_H_
#define _CONFIG_H_

#include <cstdint>
#include <map>
#include <vector>
#include <boost/property_tree/ptree.hpp>
#include "log.h"

class Config {
public:
    enum RunType {
        SERVER,
        CLIENT,
        FORWARD,
        NAT
    } run_type;
    std::string local_addr;
    uint16_t local_port;
    std::string remote_addr;
    uint16_t remote_port;
    std::string target_addr;
    uint16_t target_port;
    std::map<std::string, std::string> password;
    int udp_timeout;
    Log::Level log_level;
    class SSLConfig {
    public:
        bool verify;
        bool verify_hostname;
        std::string cert;
        std::string key;
        std::string key_password;
        std::string cipher;
        std::string cipher_tls13;
        bool prefer_server_cipher;
        std::string sni;
        std::string alpn;
        std::map<std::string, uint16_t> alpn_port_override;
        bool reuse_session;
        bool session_ticket;
        long session_timeout;
        std::string plain_http_response;
        std::string curves;
        std::string dhparam;
    } ssl;
    class TCPConfig {
    public:
        bool prefer_ipv4;
        bool no_delay;
        bool keep_alive;
        bool reuse_port;
        bool fast_open;
        int fast_open_qlen;
    } tcp;
    class MySQLConfig {
    public:
        bool enabled;
        std::string server_addr;
        uint16_t server_port;
        std::string database;
        std::string username;
        std::string password;
        std::string key;
        std::string cert;
        std::string ca;
    } mysql;
    class ObfuscationConfig {
    public:
        bool enabled;
        // Fingerprint randomization
        struct Fingerprint {
            bool enabled;
            std::string type;  // chrome, firefox, safari, edge, opera, random
            bool grease;       // Enable GREASE (RFC 8701)
        } fingerprint;
        // Handshake mimicry
        struct Handshake {
            bool enabled;
            std::string cache_file;
            bool prefetch;
            std::vector<std::string> prefetch_domains;
        } handshake;
        // Timing obfuscation
        struct Timing {
            std::string profile;  // aggressive, balanced, stealth
            uint32_t min_delay_ms;
            uint32_t max_delay_ms;
            uint32_t jitter_ms;
        } timing;
        // Padding
        struct Padding {
            bool enabled;
            uint16_t min_bytes;
            uint16_t max_bytes;
        } padding;
        // Record splitting
        struct RecordSplitting {
            bool enabled;
            uint16_t min_fragment;
            uint16_t max_fragment;
        } record_splitting;
        // Cache
        struct Cache {
            bool enabled;
            std::string directory;
        } cache;
        // TLS version control
        struct TLS {
            bool enforce_tls13;  // 强制使用 TLS 1.3
            uint16_t min_version;  // 最低版本 (0x0303=TLS1.2, 0x0304=TLS1.3)
        } tls;
    } obfuscation;
    class RoutingConfig {
    public:
        bool enabled;
        std::string mode;  // rule, global, direct
        std::string rules_file;  // Path to rules JSON file
    } routing;
    void load(const std::string &filename);
    void populate(const std::string &JSON);
    bool sip003();
    static std::string SHA224(const std::string &message);
private:
    void populate(const boost::property_tree::ptree &tree);
};

#endif // _CONFIG_H_
