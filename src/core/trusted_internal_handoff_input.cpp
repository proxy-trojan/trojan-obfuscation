#include "trusted_internal_handoff_input.h"

std::string trusted_internal_handoff_input_status_name(TrustedInternalHandoffInputStatus status) {
    switch (status) {
    case TrustedInternalHandoffInputStatus::Accepted:
        return "accepted_trusted_internal_handoff_input";
    case TrustedInternalHandoffInputStatus::RejectedMissingSourceName:
        return "rejected_missing_trusted_internal_source_name";
    case TrustedInternalHandoffInputStatus::RejectedMissingTrustedFrontId:
        return "rejected_missing_trusted_internal_front_id";
    case TrustedInternalHandoffInputStatus::RejectedMissingOriginalClientIdentity:
        return "rejected_missing_trusted_internal_client_identity";
    case TrustedInternalHandoffInputStatus::RejectedMissingVerifiedTlsTermination:
        return "rejected_missing_trusted_internal_verified_tls_termination";
    }
    return "rejected_missing_trusted_internal_source_name";
}

TrustedInternalHandoffInputDecision TrustedInternalHandoffInputContract::evaluate(const TrustedInternalHandoffInput &input) const {
    if (input.source_name.empty()) {
        return {TrustedInternalHandoffInputStatus::RejectedMissingSourceName,
                trusted_internal_handoff_input_status_name(TrustedInternalHandoffInputStatus::RejectedMissingSourceName)};
    }
    if (input.trusted_front_id.empty()) {
        return {TrustedInternalHandoffInputStatus::RejectedMissingTrustedFrontId,
                trusted_internal_handoff_input_status_name(TrustedInternalHandoffInputStatus::RejectedMissingTrustedFrontId)};
    }
    if (input.original_client_ip.empty()) {
        return {TrustedInternalHandoffInputStatus::RejectedMissingOriginalClientIdentity,
                trusted_internal_handoff_input_status_name(TrustedInternalHandoffInputStatus::RejectedMissingOriginalClientIdentity)};
    }
    if (!input.metadata_verified || !input.tls_terminated_by_front) {
        return {TrustedInternalHandoffInputStatus::RejectedMissingVerifiedTlsTermination,
                trusted_internal_handoff_input_status_name(TrustedInternalHandoffInputStatus::RejectedMissingVerifiedTlsTermination)};
    }
    return {TrustedInternalHandoffInputStatus::Accepted,
            trusted_internal_handoff_input_status_name(TrustedInternalHandoffInputStatus::Accepted)};
}
