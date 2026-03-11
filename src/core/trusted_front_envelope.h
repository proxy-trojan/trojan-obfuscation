#ifndef _TRUSTED_FRONT_ENVELOPE_H_
#define _TRUSTED_FRONT_ENVELOPE_H_

#include <optional>
#include <string>
#include <string_view>
#include "trusted_internal_handoff_input.h"

enum class TrustedFrontEnvelopeParseStatus {
    Parsed,
    RejectedInvalidJson,
    RejectedInvalidEnvelope
};

std::string trusted_front_envelope_parse_status_name(TrustedFrontEnvelopeParseStatus status);

struct TrustedFrontEnvelopeParseResult {
    TrustedFrontEnvelopeParseStatus status{TrustedFrontEnvelopeParseStatus::RejectedInvalidJson};
    std::string reason;
    std::optional<TrustedInternalHandoffInput> input;

    bool parsed() const {
        return status == TrustedFrontEnvelopeParseStatus::Parsed && input.has_value();
    }
};

class TrustedFrontEnvelopeParser {
public:
    TrustedFrontEnvelopeParseResult parse_json(std::string_view payload) const;
};

#endif // _TRUSTED_FRONT_ENVELOPE_H_
