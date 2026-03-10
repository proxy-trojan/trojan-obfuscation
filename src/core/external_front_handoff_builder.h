#ifndef _EXTERNAL_FRONT_HANDOFF_BUILDER_H_
#define _EXTERNAL_FRONT_HANDOFF_BUILDER_H_

#include <optional>
#include <string>
#include "external_front_metadata_provider.h"
#include "session_types.h"
#include "trusted_internal_handoff_input.h"

class ExternalFrontHandoffBuilder {
public:
    std::optional<ExternalFrontHandoff> maybe_build_test_injected_handoff(
        const ExternalFrontMetadataProvider::InjectionResult &injection) const;

    std::optional<ExternalFrontHandoff> maybe_build_trusted_internal_handoff(
        const TrustedInternalHandoffInput &input) const;
};

#endif // _EXTERNAL_FRONT_HANDOFF_BUILDER_H_
