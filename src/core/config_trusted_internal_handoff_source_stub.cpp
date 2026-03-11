#include "config_trusted_internal_handoff_source_stub.h"

ConfigTrustedInternalHandoffSourceStub::ConfigTrustedInternalHandoffSourceStub(const Config &config)
    : config(config) {}

bool ConfigTrustedInternalHandoffSourceStub::active() const {
    return config.external_front.enabled && config.external_front.enable_trusted_internal_handoff_stub;
}

std::string ConfigTrustedInternalHandoffSourceStub::source_name() const {
    return config.external_front.trusted_internal_source_name;
}

std::optional<TrustedInternalHandoffInput> ConfigTrustedInternalHandoffSourceStub::maybe_build_input() const {
    if (!active()) {
        return std::nullopt;
    }

    if (!config.external_front.trusted_front_envelope_json.empty()) {
        TrustedFrontEnvelopeParser parser;
        auto parse_result = parser.parse_json(config.external_front.trusted_front_envelope_json);
        if (parse_result.parsed()) {
            return std::move(parse_result.input);
        }
        return std::nullopt;
    }

    TrustedInternalHandoffInput input;
    input.source_name = config.external_front.trusted_internal_source_name;
    input.trusted_front_id = config.external_front.trusted_internal_front_id;
    input.original_client_ip = config.external_front.trusted_internal_original_client_ip;
    input.original_client_port = config.external_front.trusted_internal_original_client_port;
    input.server_name = config.external_front.trusted_internal_server_name;
    input.negotiated_alpn = config.external_front.trusted_internal_negotiated_alpn;
    input.tls_terminated_by_front = config.external_front.trusted_internal_tls_terminated_by_front;
    input.metadata_verified = config.external_front.trusted_internal_metadata_verified;
    return input;
}

ConfigTrustedInternalHandoffSourceStub::EvaluationResult ConfigTrustedInternalHandoffSourceStub::evaluate() const {
    if (!active()) {
        return {Decision::Inactive, source_name(), "trusted_internal_source_inactive", std::nullopt};
    }

    if (!config.external_front.trusted_front_envelope_json.empty()) {
        TrustedFrontEnvelopeParser parser;
        auto parse_result = parser.parse_json(config.external_front.trusted_front_envelope_json);
        if (!parse_result.parsed()) {
            return {Decision::ActiveWithoutInput, source_name(), parse_result.reason, std::nullopt};
        }
        return {Decision::ActiveWithInput, parse_result.input->source_name, parse_result.reason, std::move(parse_result.input)};
    }

    auto input = maybe_build_input();
    if (!input.has_value()) {
        return {Decision::ActiveWithoutInput, source_name(), "missing_trusted_internal_stub_input", std::nullopt};
    }

    return {Decision::ActiveWithInput, source_name(), "built_trusted_internal_stub_input", std::move(input)};
}
