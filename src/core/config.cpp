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

#include "config.h"
#include <cstdlib>
#include <sstream>
#include <stdexcept>
#include <boost/property_tree/json_parser.hpp>
#include <openssl/evp.h>
using namespace std;
using namespace boost::property_tree;

void Config::load(const string &filename) {
    ptree tree;
    read_json(filename, tree);
    populate(tree);
}

void Config::populate(const string &JSON) {
    istringstream s(JSON);
    ptree tree;
    read_json(s, tree);
    populate(tree);
}

void Config::populate(const ptree &tree) {
    string rt = tree.get("run_type", string("client"));
    if (rt == "server") {
        run_type = SERVER;
    } else if (rt == "forward") {
        run_type = FORWARD;
    } else if (rt == "nat") {
        run_type = NAT;
    } else if (rt == "client") {
        run_type = CLIENT;
    } else {
        throw runtime_error("wrong run_type in config file");
    }
    local_addr = tree.get("local_addr", string());
    local_port = tree.get("local_port", uint16_t());
    remote_addr = tree.get("remote_addr", string());
    remote_port = tree.get("remote_port", uint16_t());
    target_addr = tree.get("target_addr", string());
    target_port = tree.get("target_port", uint16_t());
    map<string, string>().swap(password);
    if (tree.get_child_optional("password")) {
        for (auto& item: tree.get_child("password")) {
            string p = item.second.get_value<string>();
            password[SHA224(p)] = p;
        }
    }
    udp_timeout = tree.get("udp_timeout", 60);
    log_level = static_cast<Log::Level>(tree.get("log_level", 1));
    ssl.verify = tree.get("ssl.verify", true);
    ssl.verify_hostname = tree.get("ssl.verify_hostname", true);
    ssl.cert = tree.get("ssl.cert", string());
    ssl.key = tree.get("ssl.key", string());
    ssl.key_password = tree.get("ssl.key_password", string());
    ssl.cipher = tree.get("ssl.cipher", string());
    ssl.cipher_tls13 = tree.get("ssl.cipher_tls13", string());
    ssl.prefer_server_cipher = tree.get("ssl.prefer_server_cipher", true);
    ssl.sni = tree.get("ssl.sni", string());
    ssl.alpn = "";
    if (tree.get_child_optional("ssl.alpn")) {
        for (auto& item: tree.get_child("ssl.alpn")) {
            string proto = item.second.get_value<string>();
            ssl.alpn += (char)((unsigned char)(proto.length()));
            ssl.alpn += proto;
        }
    }
    map<string, uint16_t>().swap(ssl.alpn_port_override);
    if (tree.get_child_optional("ssl.alpn_port_override")) {
        for (auto& item: tree.get_child("ssl.alpn_port_override")) {
            ssl.alpn_port_override[item.first] = item.second.get_value<uint16_t>();
        }
    }
    ssl.reuse_session = tree.get("ssl.reuse_session", true);
    ssl.session_ticket = tree.get("ssl.session_ticket", false);
    ssl.session_timeout = tree.get("ssl.session_timeout", long(600));
    ssl.plain_http_response = tree.get("ssl.plain_http_response", string());
    ssl.curves = tree.get("ssl.curves", string());
    ssl.dhparam = tree.get("ssl.dhparam", string());
    tcp.prefer_ipv4 = tree.get("tcp.prefer_ipv4", false);
    tcp.no_delay = tree.get("tcp.no_delay", true);
    tcp.keep_alive = tree.get("tcp.keep_alive", true);
    tcp.reuse_port = tree.get("tcp.reuse_port", false);
    tcp.fast_open = tree.get("tcp.fast_open", false);
    tcp.fast_open_qlen = tree.get("tcp.fast_open_qlen", 20);
    mysql.enabled = tree.get("mysql.enabled", false);
    mysql.server_addr = tree.get("mysql.server_addr", string("127.0.0.1"));
    mysql.server_port = tree.get("mysql.server_port", uint16_t(3306));
    mysql.database = tree.get("mysql.database", string("trojan"));
    mysql.username = tree.get("mysql.username", string("trojan"));
    mysql.password = tree.get("mysql.password", string());
    mysql.key = tree.get("mysql.key", string());
    mysql.cert = tree.get("mysql.cert", string());
    mysql.ca = tree.get("mysql.ca", string());
    
    // Obfuscation config (client-side only)
    obfuscation.enabled = tree.get("obfuscation.enabled", false);
    obfuscation.fingerprint.enabled = tree.get("obfuscation.fingerprint.enabled", true);
    obfuscation.fingerprint.type = tree.get("obfuscation.fingerprint.type", string("random"));
    obfuscation.fingerprint.grease = tree.get("obfuscation.fingerprint.grease", true);
    obfuscation.handshake.enabled = tree.get("obfuscation.handshake_mimicry.enabled", true);
    obfuscation.handshake.cache_file = tree.get("obfuscation.handshake_mimicry.cache_file", string());
    obfuscation.handshake.prefetch = tree.get("obfuscation.handshake_mimicry.prefetch", true);
    vector<string>().swap(obfuscation.handshake.prefetch_domains);
    if (tree.get_child_optional("obfuscation.handshake_mimicry.prefetch_domains")) {
        for (auto& item : tree.get_child("obfuscation.handshake_mimicry.prefetch_domains")) {
            obfuscation.handshake.prefetch_domains.push_back(item.second.get_value<string>());
        }
    }
    obfuscation.timing.profile = tree.get("obfuscation.timing.profile", string("aggressive"));
    obfuscation.timing.min_delay_ms = tree.get("obfuscation.timing.min_delay_ms", uint32_t(0));
    obfuscation.timing.max_delay_ms = tree.get("obfuscation.timing.max_delay_ms", uint32_t(5));
    obfuscation.timing.jitter_ms = tree.get("obfuscation.timing.jitter_ms", uint32_t(2));
    obfuscation.padding.enabled = tree.get("obfuscation.padding.enabled", false);
    obfuscation.padding.min_bytes = tree.get("obfuscation.padding.min_bytes", uint16_t(0));
    obfuscation.padding.max_bytes = tree.get("obfuscation.padding.max_bytes", uint16_t(64));
    obfuscation.record_splitting.enabled = tree.get("obfuscation.record_splitting.enabled", false);
    obfuscation.record_splitting.min_fragment = tree.get("obfuscation.record_splitting.min_fragment", uint16_t(64));
    obfuscation.record_splitting.max_fragment = tree.get("obfuscation.record_splitting.max_fragment", uint16_t(256));
    obfuscation.cache.enabled = tree.get("obfuscation.cache.enabled", true);
    obfuscation.cache.directory = tree.get("obfuscation.cache.directory", string());
    obfuscation.tls.enforce_tls13 = tree.get("obfuscation.tls.enforce_tls13", false);
    obfuscation.tls.min_version = tree.get("obfuscation.tls.min_version", uint16_t(0x0303));  // 默认 TLS 1.2
    
    // Routing config (client-side only)
    routing.enabled = tree.get("routing.enabled", true);  // 默认启用分流
    routing.mode = tree.get("routing.mode", string("rule"));  // rule, global, direct
    routing.rules_file = tree.get("routing.rules_file", string());  // 自定义规则文件
}

bool Config::sip003() {
    char *JSON = getenv("SS_PLUGIN_OPTIONS");
    if (JSON == nullptr) {
        return false;
    }
    populate(JSON);
    switch (run_type) {
        case SERVER:
            local_addr = getenv("SS_REMOTE_HOST");
            local_port = atoi(getenv("SS_REMOTE_PORT"));
            break;
        case CLIENT:
        case NAT:
            throw runtime_error("SIP003 with wrong run_type");
        case FORWARD:
            remote_addr = getenv("SS_REMOTE_HOST");
            remote_port = atoi(getenv("SS_REMOTE_PORT"));
            local_addr = getenv("SS_LOCAL_HOST");
            local_port = atoi(getenv("SS_LOCAL_PORT"));
            break;
    }
    return true;
}

string Config::SHA224(const string &message) {
    uint8_t digest[EVP_MAX_MD_SIZE];
    char mdString[(EVP_MAX_MD_SIZE << 1) + 1];
    unsigned int digest_len;
    EVP_MD_CTX *ctx;
    if ((ctx = EVP_MD_CTX_new()) == nullptr) {
        throw runtime_error("could not create hash context");
    }
    if (!EVP_DigestInit_ex(ctx, EVP_sha224(), nullptr)) {
        EVP_MD_CTX_free(ctx);
        throw runtime_error("could not initialize hash context");
    }
    if (!EVP_DigestUpdate(ctx, message.c_str(), message.length())) {
        EVP_MD_CTX_free(ctx);
        throw runtime_error("could not update hash");
    }
    if (!EVP_DigestFinal_ex(ctx, digest, &digest_len)) {
        EVP_MD_CTX_free(ctx);
        throw runtime_error("could not output hash");
    }

    for (unsigned int i = 0; i < digest_len; ++i) {
        sprintf(mdString + (i << 1), "%02x", (unsigned int)digest[i]);
    }
    mdString[digest_len << 1] = '\0';
    EVP_MD_CTX_free(ctx);
    return string(mdString);
}
