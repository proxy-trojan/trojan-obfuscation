#include "external_front_metadata_provider.h"

ConfigExternalFrontMetadataProvider::ConfigExternalFrontMetadataProvider(const Config &config)
    : config(config) {}

bool ConfigExternalFrontMetadataProvider::active() const {
    return config.external_front.enabled && config.external_front.inject_test_metadata;
}

std::string ConfigExternalFrontMetadataProvider::injection_mode_name() const {
    return "test_injected_external_front";
}

std::optional<ExternalFrontContext> ConfigExternalFrontMetadataProvider::maybe_build_context() const {
    if (!active()) {
        return std::nullopt;
    }

    ExternalFrontContext context;
    context.trusted_front_id = config.external_front.test_trusted_front_id;
    context.original_client_ip = config.external_front.test_original_client_ip;
    context.original_client_port = config.external_front.test_original_client_port;
    context.negotiated_alpn = config.external_front.test_negotiated_alpn;
    context.tls_terminated_by_front = config.external_front.test_tls_terminated_by_front;
    context.metadata_verified = config.external_front.test_metadata_verified;
    context.ingress_mode = injection_mode_name();
    return context;
}
