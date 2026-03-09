#ifndef _SESSION_TYPES_H_
#define _SESSION_TYPES_H_

#include <cstdint>
#include <string>

struct SessionContext {
    std::string source_ip;
    uint16_t source_port{0};
    std::string selected_alpn;
    bool tls_handshake_completed{false};
    bool is_from_embedded_tls_listener{true};
};

struct ConnectTarget {
    std::string host;
    uint16_t port{0};
    bool is_fallback{false};
};

#endif // _SESSION_TYPES_H_
