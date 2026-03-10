#ifndef _CONFIG_TRUSTED_INTERNAL_HANDOFF_SOURCE_STUB_H_
#define _CONFIG_TRUSTED_INTERNAL_HANDOFF_SOURCE_STUB_H_

#include <optional>
#include "config.h"
#include "trusted_internal_handoff_input.h"

class ConfigTrustedInternalHandoffSourceStub {
public:
    explicit ConfigTrustedInternalHandoffSourceStub(const Config &config);

    bool active() const;
    std::optional<TrustedInternalHandoffInput> maybe_build_input() const;

private:
    const Config &config;
};

#endif // _CONFIG_TRUSTED_INTERNAL_HANDOFF_SOURCE_STUB_H_
