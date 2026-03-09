#ifndef _SESSION_TYPES_H_
#define _SESSION_TYPES_H_

#include <cstdint>
#include <string>
#include <string_view>

enum class InboundMode {
    EmbeddedTls,
    ExternalFront,
    QuicIngress,
    Unknown
};

struct SessionContext {
    std::string source_ip;
    uint16_t source_port{0};
    std::string selected_alpn;
    bool tls_handshake_completed{false};
    InboundMode inbound_mode{InboundMode::Unknown};
};

struct ConnectTarget {
    std::string host;
    uint16_t port{0};
    bool is_fallback{false};
};

struct SessionGateInput {
    SessionContext context;
    std::string_view initial_data;
};

#endif // _SESSION_TYPES_H_
