#ifndef _TRUSTED_INTERNAL_HANDOFF_INPUT_H_
#define _TRUSTED_INTERNAL_HANDOFF_INPUT_H_

#include <cstdint>
#include <string>

struct TrustedInternalHandoffInput {
    std::string source_name;
    std::string trusted_front_id;
    std::string original_client_ip;
    uint16_t original_client_port{0};
    std::string server_name;
    std::string negotiated_alpn;
    bool tls_terminated_by_front{false};
    bool metadata_verified{false};
};

enum class TrustedInternalHandoffInputStatus {
    Accepted,
    RejectedMissingSourceName,
    RejectedMissingTrustedFrontId,
    RejectedMissingOriginalClientIdentity,
    RejectedMissingVerifiedTlsTermination
};

std::string trusted_internal_handoff_input_status_name(TrustedInternalHandoffInputStatus status);

struct TrustedInternalHandoffInputDecision {
    TrustedInternalHandoffInputStatus status{TrustedInternalHandoffInputStatus::RejectedMissingSourceName};
    std::string reason;

    bool accepted() const {
        return status == TrustedInternalHandoffInputStatus::Accepted;
    }
};

class TrustedInternalHandoffInputContract {
public:
    TrustedInternalHandoffInputDecision evaluate(const TrustedInternalHandoffInput &input) const;
};

#endif // _TRUSTED_INTERNAL_HANDOFF_INPUT_H_
