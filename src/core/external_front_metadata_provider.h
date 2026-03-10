#ifndef _EXTERNAL_FRONT_METADATA_PROVIDER_H_
#define _EXTERNAL_FRONT_METADATA_PROVIDER_H_

#include <optional>
#include "config.h"
#include "session_types.h"

class ExternalFrontMetadataProvider {
public:
    virtual ~ExternalFrontMetadataProvider() = default;
    virtual bool active() const = 0;
    virtual std::string injection_mode_name() const = 0;
    virtual std::optional<ExternalFrontContext> maybe_build_context() const = 0;
};

class ConfigExternalFrontMetadataProvider : public ExternalFrontMetadataProvider {
public:
    explicit ConfigExternalFrontMetadataProvider(const Config &config);

    bool active() const override;
    std::string injection_mode_name() const override;
    std::optional<ExternalFrontContext> maybe_build_context() const override;

private:
    const Config &config;
};

#endif // _EXTERNAL_FRONT_METADATA_PROVIDER_H_
