#include "trusted_front_envelope.h"

#include <sstream>
#include <boost/property_tree/json_parser.hpp>
#include <boost/property_tree/ptree.hpp>

using boost::property_tree::ptree;

std::string trusted_front_envelope_parse_status_name(TrustedFrontEnvelopeParseStatus status) {
    switch (status) {
    case TrustedFrontEnvelopeParseStatus::Parsed:
        return "parsed_trusted_front_envelope";
    case TrustedFrontEnvelopeParseStatus::RejectedInvalidJson:
        return "rejected_invalid_trusted_front_envelope_json";
    case TrustedFrontEnvelopeParseStatus::RejectedInvalidEnvelope:
        return "rejected_invalid_trusted_front_envelope";
    }
    return "rejected_invalid_trusted_front_envelope_json";
}

TrustedFrontEnvelopeParseResult TrustedFrontEnvelopeParser::parse_json(std::string_view payload) const {
    ptree tree;
    try {
        std::istringstream input_stream{std::string(payload)};
        boost::property_tree::read_json(input_stream, tree);
    } catch (const boost::property_tree::json_parser::json_parser_error &) {
        return {TrustedFrontEnvelopeParseStatus::RejectedInvalidJson,
                trusted_front_envelope_parse_status_name(TrustedFrontEnvelopeParseStatus::RejectedInvalidJson),
                std::nullopt};
    }

    TrustedInternalHandoffInput input;
    input.source_name = tree.get("source_name", std::string());
    input.trusted_front_id = tree.get("trusted_front_id", std::string());
    input.original_client_ip = tree.get("original_client_ip", std::string());
    input.original_client_port = tree.get("original_client_port", 0);
    input.server_name = tree.get("server_name", std::string());
    input.negotiated_alpn = tree.get("negotiated_alpn", std::string());
    input.tls_terminated_by_front = tree.get("tls_terminated_by_front", false);
    input.metadata_verified = tree.get("metadata_verified", false);

    TrustedInternalHandoffInputContract contract;
    auto decision = contract.evaluate(input);
    if (!decision.accepted()) {
        return {TrustedFrontEnvelopeParseStatus::RejectedInvalidEnvelope,
                decision.reason,
                std::nullopt};
    }

    return {TrustedFrontEnvelopeParseStatus::Parsed,
            trusted_front_envelope_parse_status_name(TrustedFrontEnvelopeParseStatus::Parsed),
            std::move(input)};
}
