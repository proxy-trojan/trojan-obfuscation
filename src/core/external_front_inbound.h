#ifndef _EXTERNAL_FRONT_INBOUND_H_
#define _EXTERNAL_FRONT_INBOUND_H_

#include <memory>
#include <string_view>
#include "authenticator.h"
#include "config.h"
#include "external_front_trust_policy.h"
#include "session_gate.h"
#include "session_types.h"

class ExternalFrontInbound {
public:
    ExternalFrontInbound() = default;
    ExternalFrontInbound(const Config &config, Authenticator *auth);

    SessionContext build_context(const ExternalFrontContext &front_context) const;
    SessionGateInput build_gate_input(const ExternalFrontContext &front_context,
                                      std::string_view initial_data) const;
    bool should_apply_client_identity(const ExternalFrontValidationResult &validation_result) const;
    bool should_apply_transport_context(const ExternalFrontValidationResult &validation_result) const;
    ExternalFrontValidationResult validation_result(const ExternalFrontContext &front_context) const;
    bool is_trusted_metadata(const ExternalFrontContext &front_context) const;
    SessionGate::SessionDecision evaluate_initial_data(const ExternalFrontContext &front_context,
                                                       std::string_view initial_data) const;

private:
    ExternalFrontTrustPolicy trust_policy;
    std::unique_ptr<SessionGate> session_gate;
};

#endif // _EXTERNAL_FRONT_INBOUND_H_
