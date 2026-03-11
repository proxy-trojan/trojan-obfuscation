#ifndef _EXTERNAL_FRONT_HANDOFF_BUILDER_H_
#define _EXTERNAL_FRONT_HANDOFF_BUILDER_H_

#include <optional>
#include <string>
#include "external_front_metadata_provider.h"
#include "session_types.h"
#include "trusted_internal_handoff_input.h"

struct ExternalFrontHandoffBuildResult {
    std::optional<ExternalFrontHandoff> handoff;
    std::string reason;

    bool built() const {
        return handoff.has_value();
    }
};

class ExternalFrontHandoffBuilder {
public:
    ExternalFrontHandoffBuildResult build_test_injected_handoff(
        const ExternalFrontMetadataProvider::InjectionResult &injection) const;

    ExternalFrontHandoffBuildResult build_trusted_internal_handoff(
        const TrustedInternalHandoffInput &input) const;
};

#endif // _EXTERNAL_FRONT_HANDOFF_BUILDER_H_
