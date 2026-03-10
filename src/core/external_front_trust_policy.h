#ifndef _EXTERNAL_FRONT_TRUST_POLICY_H_
#define _EXTERNAL_FRONT_TRUST_POLICY_H_

#include <string>
#include "session_types.h"

class ExternalFrontTrustPolicy {
public:
    bool is_trusted(const ExternalFrontContext &front_context) const;
    bool requires_verified_tls_termination() const;
    bool requires_original_client_identity() const;
    bool requires_trusted_front_id() const;
};

#endif // _EXTERNAL_FRONT_TRUST_POLICY_H_
