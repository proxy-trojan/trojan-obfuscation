#include "trusted_front_ingress.h"

#include <charconv>

std::string trusted_front_ingress_parse_status_name(TrustedFrontIngressParseStatus status) {
    switch (status) {
    case TrustedFrontIngressParseStatus::Parsed:
        return "parsed_trusted_front_ingress";
    case TrustedFrontIngressParseStatus::RejectedIncompleteFrame:
        return "rejected_incomplete_trusted_front_ingress_frame";
    case TrustedFrontIngressParseStatus::RejectedInvalidLength:
        return "rejected_invalid_trusted_front_ingress_length";
    case TrustedFrontIngressParseStatus::RejectedInvalidEnvelope:
        return "rejected_invalid_trusted_front_ingress_envelope";
    case TrustedFrontIngressParseStatus::RejectedMissingPayload:
        return "rejected_missing_trusted_front_downstream_payload";
    }
    return "rejected_incomplete_trusted_front_ingress_frame";
}

TrustedFrontIngressParseResult TrustedFrontIngressParser::parse(std::string_view payload) const {
    auto newline = payload.find('\n');
    if (newline == std::string_view::npos) {
        return {TrustedFrontIngressParseStatus::RejectedIncompleteFrame,
                trusted_front_ingress_parse_status_name(TrustedFrontIngressParseStatus::RejectedIncompleteFrame),
                std::nullopt,
                ""};
    }

    size_t envelope_length = 0;
    auto length_view = payload.substr(0, newline);
    auto parse_result = std::from_chars(length_view.data(), length_view.data() + length_view.size(), envelope_length);
    if (parse_result.ec != std::errc() || parse_result.ptr != length_view.data() + length_view.size()) {
        return {TrustedFrontIngressParseStatus::RejectedInvalidLength,
                trusted_front_ingress_parse_status_name(TrustedFrontIngressParseStatus::RejectedInvalidLength),
                std::nullopt,
                ""};
    }

    auto remaining = payload.substr(newline + 1);
    if (remaining.size() < envelope_length) {
        return {TrustedFrontIngressParseStatus::RejectedIncompleteFrame,
                trusted_front_ingress_parse_status_name(TrustedFrontIngressParseStatus::RejectedIncompleteFrame),
                std::nullopt,
                ""};
    }

    auto envelope_payload = remaining.substr(0, envelope_length);
    auto downstream_payload = remaining.substr(envelope_length);
    if (downstream_payload.empty()) {
        return {TrustedFrontIngressParseStatus::RejectedMissingPayload,
                trusted_front_ingress_parse_status_name(TrustedFrontIngressParseStatus::RejectedMissingPayload),
                std::nullopt,
                ""};
    }

    TrustedFrontEnvelopeParser envelope_parser;
    auto envelope_result = envelope_parser.parse_json(envelope_payload);
    if (!envelope_result.parsed()) {
        return {TrustedFrontIngressParseStatus::RejectedInvalidEnvelope,
                envelope_result.reason,
                std::nullopt,
                ""};
    }

    ExternalFrontHandoffBuilder builder;
    auto build_result = builder.build_trusted_internal_handoff(*envelope_result.input);
    if (!build_result.built()) {
        return {TrustedFrontIngressParseStatus::RejectedInvalidEnvelope,
                build_result.reason,
                std::nullopt,
                ""};
    }

    return {TrustedFrontIngressParseStatus::Parsed,
            trusted_front_ingress_parse_status_name(TrustedFrontIngressParseStatus::Parsed),
            std::move(build_result.handoff),
            std::string(downstream_payload)};
}
