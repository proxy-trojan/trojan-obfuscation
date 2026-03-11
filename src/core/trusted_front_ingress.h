#ifndef _TRUSTED_FRONT_INGRESS_H_
#define _TRUSTED_FRONT_INGRESS_H_

#include <optional>
#include <string>
#include <string_view>
#include "external_front_handoff_builder.h"
#include "session_types.h"
#include "trusted_front_envelope.h"

enum class TrustedFrontIngressParseStatus {
    Parsed,
    RejectedIncompleteFrame,
    RejectedInvalidLength,
    RejectedInvalidEnvelope,
    RejectedMissingPayload
};

std::string trusted_front_ingress_parse_status_name(TrustedFrontIngressParseStatus status);

struct TrustedFrontIngressParseResult {
    TrustedFrontIngressParseStatus status{TrustedFrontIngressParseStatus::RejectedIncompleteFrame};
    std::string reason;
    std::optional<ExternalFrontHandoff> handoff;
    std::string downstream_payload;

    bool parsed() const {
        return status == TrustedFrontIngressParseStatus::Parsed && handoff.has_value();
    }
};

class TrustedFrontIngressParser {
public:
    TrustedFrontIngressParseResult parse(std::string_view payload) const;
};

#endif // _TRUSTED_FRONT_INGRESS_H_
