#ifndef _EXTERNAL_FRONT_HANDOFF_CONTRACT_H_
#define _EXTERNAL_FRONT_HANDOFF_CONTRACT_H_

#include <string>
#include "session_types.h"

std::string external_front_handoff_source_kind_name(ExternalFrontHandoffSourceKind source_kind);

enum class ExternalFrontHandoffContractStatus {
    AcceptedTestInjected,
    AcceptedTrustedInternal,
    RejectedMissingContext,
    RejectedUnknownSource
};

std::string external_front_handoff_contract_status_name(ExternalFrontHandoffContractStatus status);

struct ExternalFrontHandoffContractDecision {
    ExternalFrontHandoffContractStatus status{ExternalFrontHandoffContractStatus::RejectedUnknownSource};
    std::string reason;

    bool accepted() const {
        return status == ExternalFrontHandoffContractStatus::AcceptedTestInjected ||
               status == ExternalFrontHandoffContractStatus::AcceptedTrustedInternal;
    }
};

class ExternalFrontHandoffContract {
public:
    ExternalFrontHandoffContractDecision evaluate(const ExternalFrontHandoff &handoff) const;
};

#endif // _EXTERNAL_FRONT_HANDOFF_CONTRACT_H_
