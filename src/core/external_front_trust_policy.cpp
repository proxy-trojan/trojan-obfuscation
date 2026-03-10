#include "external_front_trust_policy.h"

ExternalFrontValidationResult ExternalFrontTrustPolicy::validate(const ExternalFrontContext &front_context) const {
    if (requires_trusted_front_id() && front_context.trusted_front_id.empty()) {
        return {ExternalFrontValidationStatus::MissingTrustedFrontId};
    }
    if (requires_original_client_identity() && front_context.original_client_ip.empty()) {
        return {ExternalFrontValidationStatus::MissingOriginalClientIdentity};
    }
    if (requires_verified_tls_termination() &&
        (!front_context.metadata_verified || !front_context.tls_terminated_by_front)) {
        return {ExternalFrontValidationStatus::MissingVerifiedTlsTermination};
    }
    return {ExternalFrontValidationStatus::Trusted};
}

bool ExternalFrontTrustPolicy::is_trusted(const ExternalFrontContext &front_context) const {
    return validate(front_context).trusted();
}

bool ExternalFrontTrustPolicy::requires_verified_tls_termination() const {
    return true;
}

bool ExternalFrontTrustPolicy::requires_original_client_identity() const {
    return true;
}

bool ExternalFrontTrustPolicy::requires_trusted_front_id() const {
    return true;
}
