#ifndef _SESSION_GATE_H_
#define _SESSION_GATE_H_

#include <string>
#include <string_view>
#include "config.h"
#include "authenticator.h"
#include "proto/trojanrequest.h"
#include "session_types.h"

class SessionGate {
public:
    enum class Path {
        AUTHENTICATED_TCP,
        AUTHENTICATED_UDP,
        FALLBACK
    };

    struct SessionDecision {
        Path path{Path::FALLBACK};
        bool valid_trojan_request{false};
        bool authenticated{false};
        bool used_external_authenticator{false};
        TrojanRequest request;
        ConnectTarget target;
        std::string outbound_payload;
        std::string auth_record_password;
    };

    SessionGate(const Config &config, Authenticator *auth);

    SessionDecision evaluate(const SessionGateInput &input) const;

private:
    const Config &config;
    Authenticator *auth;
};

#endif // _SESSION_GATE_H_
