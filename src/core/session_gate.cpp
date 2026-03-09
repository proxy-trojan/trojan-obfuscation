#include "session_gate.h"

using namespace std;

SessionGate::SessionGate(const Config &config, Authenticator *auth) : config(config), auth(auth) {}

SessionGate::SessionDecision SessionGate::evaluate(const string_view &data, const SessionContext &context) const {
    SessionDecision result;
    result.request = TrojanRequest();
    result.valid_trojan_request = result.request.parse(data) != -1;

    if (result.valid_trojan_request) {
        auto password_iterator = config.password.find(result.request.password);
        if (password_iterator != config.password.end()) {
            result.authenticated = true;
        } else if (auth && auth->auth(result.request.password)) {
            result.authenticated = true;
            result.used_external_authenticator = true;
            result.auth_record_password = result.request.password;
        }
    }

    if (result.valid_trojan_request && result.authenticated) {
        result.target.host = result.request.address.address;
        result.target.port = result.request.address.port;
        result.target.is_fallback = false;
        result.outbound_payload = result.request.payload;
        result.path = result.request.command == TrojanRequest::UDP_ASSOCIATE ? Path::AUTHENTICATED_UDP : Path::AUTHENTICATED_TCP;
        return result;
    }

    result.target.host = config.remote_addr;
    result.target.is_fallback = true;
    if (!context.selected_alpn.empty()) {
        auto it = config.ssl.alpn_port_override.find(context.selected_alpn);
        result.target.port = it == config.ssl.alpn_port_override.end() ? config.remote_port : it->second;
    } else {
        result.target.port = config.remote_port;
    }
    result.outbound_payload = string(data);
    result.path = Path::FALLBACK;
    return result;
}
