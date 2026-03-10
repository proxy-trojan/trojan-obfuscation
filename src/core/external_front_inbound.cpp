#include "external_front_inbound.h"
#include <stdexcept>

ExternalFrontInbound::ExternalFrontInbound(const Config &config, Authenticator *auth)
    : session_gate(std::make_unique<SessionGate>(config, auth)) {}

SessionContext ExternalFrontInbound::build_context(const ExternalFrontContext &front_context) const {
    SessionContext context;
    context.inbound_mode = InboundMode::ExternalFront;

    auto result = validation_result(front_context);
    if (should_apply_client_identity(result)) {
        context.source_ip = front_context.original_client_ip;
        context.source_port = front_context.original_client_port;
    }
    if (should_apply_transport_context(result)) {
        context.selected_alpn = front_context.negotiated_alpn;
        context.tls_handshake_completed = true;
    }
    return context;
}

SessionGateInput ExternalFrontInbound::build_gate_input(const ExternalFrontContext &front_context,
                                                        std::string_view initial_data) const {
    return SessionGateInput{build_context(front_context), initial_data};
}

bool ExternalFrontInbound::should_apply_client_identity(const ExternalFrontValidationResult &validation_result) const {
    return validation_result.trusted();
}

bool ExternalFrontInbound::should_apply_transport_context(const ExternalFrontValidationResult &validation_result) const {
    return validation_result.trusted();
}

ExternalFrontValidationResult ExternalFrontInbound::validation_result(const ExternalFrontContext &front_context) const {
    return trust_policy.validate(front_context);
}

bool ExternalFrontInbound::is_trusted_metadata(const ExternalFrontContext &front_context) const {
    return validation_result(front_context).trusted();
}

SessionGate::SessionDecision ExternalFrontInbound::evaluate_initial_data(const ExternalFrontContext &front_context,
                                                                         std::string_view initial_data) const {
    if (!session_gate) {
        throw std::logic_error("ExternalFrontInbound requires configured SessionGate");
    }
    return session_gate->evaluate(build_gate_input(front_context, initial_data));
}
