#include "trusted_front_admission_policy.h"

using boost::asio::ip::tcp;

std::string trusted_front_admission_status_name(TrustedFrontAdmissionStatus status) {
    switch (status) {
    case TrustedFrontAdmissionStatus::AllowedLoopbackSource:
        return "allowed_loopback_trusted_front_source";
    case TrustedFrontAdmissionStatus::AllowedUnrestrictedSource:
        return "allowed_unrestricted_trusted_front_source";
    case TrustedFrontAdmissionStatus::RejectedNonLoopbackSource:
        return "rejected_non_loopback_trusted_front_source";
    }
    return "rejected_non_loopback_trusted_front_source";
}

TrustedFrontAdmissionPolicy::TrustedFrontAdmissionPolicy(const Config &config)
    : config(config) {}

TrustedFrontAdmissionDecision TrustedFrontAdmissionPolicy::evaluate(const tcp::endpoint &endpoint) const {
    if (!config.external_front.require_trusted_front_loopback_source) {
        return {TrustedFrontAdmissionStatus::AllowedUnrestrictedSource,
                trusted_front_admission_status_name(TrustedFrontAdmissionStatus::AllowedUnrestrictedSource)};
    }

    if (endpoint.address().is_loopback()) {
        return {TrustedFrontAdmissionStatus::AllowedLoopbackSource,
                trusted_front_admission_status_name(TrustedFrontAdmissionStatus::AllowedLoopbackSource)};
    }

    return {TrustedFrontAdmissionStatus::RejectedNonLoopbackSource,
            trusted_front_admission_status_name(TrustedFrontAdmissionStatus::RejectedNonLoopbackSource)};
}
