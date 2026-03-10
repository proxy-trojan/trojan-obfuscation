#ifndef _SESSION_TYPES_H_
#define _SESSION_TYPES_H_

#include <cstdint>
#include <optional>
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

struct ExternalFrontContext {
    std::string trusted_front_id;
    std::string original_client_ip;
    uint16_t original_client_port{0};
    std::string server_name;
    std::string negotiated_alpn;
    std::string ingress_mode;
    bool tls_terminated_by_front{false};
    bool metadata_verified{false};
};

enum class ExternalFrontHandoffSourceKind {
    Unknown,
    TestInjected,
    TrustedInternalHandoff
};

struct ExternalFrontHandoff {
    ExternalFrontHandoffSourceKind source_kind{ExternalFrontHandoffSourceKind::Unknown};
    std::string source_name;
    std::optional<ExternalFrontContext> context;

    bool has_context() const {
        return context.has_value();
    }
};

enum class RelayMode {
    StartTcpForward,
    StartUdpForward,
    RejectAndClose
};

struct RelayExecutionPlan {
    RelayMode mode{RelayMode::RejectAndClose};
    ConnectTarget target;
    std::string initial_outbound_payload;
    std::string log_message;
    bool log_as_warning{false};
    bool requires_fallback_slot{false};
};

#endif // _SESSION_TYPES_H_
