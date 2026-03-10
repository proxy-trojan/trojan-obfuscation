#include "external_front_handoff_builder.h"

std::optional<ExternalFrontHandoff> ExternalFrontHandoffBuilder::maybe_build_test_injected_handoff(
    const ExternalFrontMetadataProvider::InjectionResult &injection) const {
    if (!injection.context.has_value()) {
        return std::nullopt;
    }

    ExternalFrontHandoff handoff;
    handoff.source_kind = ExternalFrontHandoffSourceKind::TestInjected;
    handoff.source_name = injection.mode;
    handoff.context = injection.context;
    return handoff;
}

ExternalFrontHandoff ExternalFrontHandoffBuilder::build_trusted_internal_handoff(
    std::string source_name,
    ExternalFrontContext context) const {
    ExternalFrontHandoff handoff;
    handoff.source_kind = ExternalFrontHandoffSourceKind::TrustedInternalHandoff;
    handoff.source_name = std::move(source_name);
    handoff.context = std::move(context);
    return handoff;
}
