#include "external_front_handoff_builder.h"

std::optional<ExternalFrontHandoff> ExternalFrontHandoffBuilder::maybe_build_test_injected_handoff(
    const ExternalFrontMetadataProvider::InjectionResult &injection) const {
    if (!injection.context.has_value()) {
        return std::nullopt;
    }

    ExternalFrontHandoff handoff;
    handoff.source_kind = ExternalFrontHandoffSourceKind::TestInjected;
    handoff.source_name = injection.mode;
    handoff.context = injection.context;
    return handoff;
}

std::optional<ExternalFrontHandoff> ExternalFrontHandoffBuilder::maybe_build_trusted_internal_handoff(
    const TrustedInternalHandoffInput &input) const {
    TrustedInternalHandoffInputContract contract;
    auto decision = contract.evaluate(input);
    if (!decision.accepted()) {
        return std::nullopt;
    }

    ExternalFrontContext context;
    context.trusted_front_id = input.trusted_front_id;
    context.original_client_ip = input.original_client_ip;
    context.original_client_port = input.original_client_port;
    context.server_name = input.server_name;
    context.negotiated_alpn = input.negotiated_alpn;
    context.ingress_mode = "trusted_internal_handoff";
    context.tls_terminated_by_front = input.tls_terminated_by_front;
    context.metadata_verified = input.metadata_verified;

    ExternalFrontHandoff handoff;
    handoff.source_kind = ExternalFrontHandoffSourceKind::TrustedInternalHandoff;
    handoff.source_name = input.source_name;
    handoff.context = std::move(context);
    return handoff;
}
