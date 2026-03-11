#ifndef _TRUSTED_FRONT_ADMISSION_POLICY_H_
#define _TRUSTED_FRONT_ADMISSION_POLICY_H_

#include <string>
#include <boost/asio/ip/tcp.hpp>
#include "config.h"

enum class TrustedFrontAdmissionStatus {
    AllowedLoopbackSource,
    AllowedUnrestrictedSource,
    RejectedNonLoopbackSource
};

std::string trusted_front_admission_status_name(TrustedFrontAdmissionStatus status);

struct TrustedFrontAdmissionDecision {
    TrustedFrontAdmissionStatus status{TrustedFrontAdmissionStatus::RejectedNonLoopbackSource};
    std::string reason;

    bool allowed() const {
        return status == TrustedFrontAdmissionStatus::AllowedLoopbackSource ||
               status == TrustedFrontAdmissionStatus::AllowedUnrestrictedSource;
    }
};

class TrustedFrontAdmissionPolicy {
public:
    explicit TrustedFrontAdmissionPolicy(const Config &config);
    TrustedFrontAdmissionDecision evaluate(const boost::asio::ip::tcp::endpoint &endpoint) const;

private:
    const Config &config;
};

#endif // _TRUSTED_FRONT_ADMISSION_POLICY_H_
