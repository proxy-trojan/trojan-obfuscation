#include "external_front_handoff_contract.h"

std::string external_front_handoff_source_kind_name(ExternalFrontHandoffSourceKind source_kind) {
    switch (source_kind) {
    case ExternalFrontHandoffSourceKind::Unknown:
        return "unknown_handoff_source";
    case ExternalFrontHandoffSourceKind::TestInjected:
        return "test_injected_handoff";
    case ExternalFrontHandoffSourceKind::TrustedInternalHandoff:
        return "trusted_internal_handoff";
    }
    return "unknown_handoff_source";
}

std::string external_front_handoff_contract_status_name(ExternalFrontHandoffContractStatus status) {
    switch (status) {
    case ExternalFrontHandoffContractStatus::AcceptedTestInjected:
        return "accepted_test_injected_handoff";
    case ExternalFrontHandoffContractStatus::AcceptedTrustedInternal:
        return "accepted_trusted_internal_handoff";
    case ExternalFrontHandoffContractStatus::RejectedMissingContext:
        return "rejected_missing_handoff_context";
    case ExternalFrontHandoffContractStatus::RejectedUnknownSource:
        return "rejected_unknown_handoff_source";
    }
    return "rejected_unknown_handoff_source";
}

ExternalFrontHandoffContractDecision ExternalFrontHandoffContract::evaluate(const ExternalFrontHandoff &handoff) const {
    if (!handoff.has_context()) {
        return {ExternalFrontHandoffContractStatus::RejectedMissingContext,
                external_front_handoff_contract_status_name(ExternalFrontHandoffContractStatus::RejectedMissingContext)};
    }

    switch (handoff.source_kind) {
    case ExternalFrontHandoffSourceKind::TestInjected:
        return {ExternalFrontHandoffContractStatus::AcceptedTestInjected,
                external_front_handoff_contract_status_name(ExternalFrontHandoffContractStatus::AcceptedTestInjected)};
    case ExternalFrontHandoffSourceKind::TrustedInternalHandoff:
        return {ExternalFrontHandoffContractStatus::AcceptedTrustedInternal,
                external_front_handoff_contract_status_name(ExternalFrontHandoffContractStatus::AcceptedTrustedInternal)};
    case ExternalFrontHandoffSourceKind::Unknown:
        return {ExternalFrontHandoffContractStatus::RejectedUnknownSource,
                external_front_handoff_contract_status_name(ExternalFrontHandoffContractStatus::RejectedUnknownSource)};
    }

    return {ExternalFrontHandoffContractStatus::RejectedUnknownSource,
            external_front_handoff_contract_status_name(ExternalFrontHandoffContractStatus::RejectedUnknownSource)};
}
