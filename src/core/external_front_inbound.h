#ifndef _EXTERNAL_FRONT_INBOUND_H_
#define _EXTERNAL_FRONT_INBOUND_H_

#include <string_view>
#include "session_types.h"

class ExternalFrontInbound {
public:
    SessionContext build_context(const ExternalFrontContext &front_context) const;
    SessionGateInput build_gate_input(const ExternalFrontContext &front_context,
                                      std::string_view initial_data) const;
    bool is_trusted_metadata(const ExternalFrontContext &front_context) const;
};

#endif // _EXTERNAL_FRONT_INBOUND_H_
