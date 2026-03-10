#include "external_front_inbound.h"

SessionContext ExternalFrontInbound::build_context(const ExternalFrontContext &front_context) const {
    SessionContext context;
    context.source_ip = front_context.original_client_ip;
    context.source_port = front_context.original_client_port;
    context.selected_alpn = front_context.negotiated_alpn;
    context.tls_handshake_completed = front_context.tls_terminated_by_front && front_context.metadata_verified;
    context.inbound_mode = InboundMode::ExternalFront;
    return context;
}

SessionGateInput ExternalFrontInbound::build_gate_input(const ExternalFrontContext &front_context,
                                                        std::string_view initial_data) const {
    return SessionGateInput{build_context(front_context), initial_data};
}

bool ExternalFrontInbound::is_trusted_metadata(const ExternalFrontContext &front_context) const {
    return front_context.metadata_verified &&
           front_context.tls_terminated_by_front &&
           !front_context.trusted_front_id.empty() &&
           !front_context.original_client_ip.empty();
}
