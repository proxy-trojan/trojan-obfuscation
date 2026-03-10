#ifndef _SERVER_INGRESS_SELECTOR_H_
#define _SERVER_INGRESS_SELECTOR_H_

#include <optional>
#include <string_view>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl.hpp>
#include "authenticator.h"
#include "config.h"
#include "embedded_tls_inbound.h"
#include "external_front_inbound.h"
#include "session_gate.h"
#include "session_types.h"

class ServerIngressSelector {
public:
    struct Selection {
        InboundMode mode{InboundMode::EmbeddedTls};
        std::optional<ExternalFrontContext> external_front_context;
    };

    ServerIngressSelector(const Config &config, Authenticator *auth);

    bool external_front_enabled() const;
    Selection select_default() const;
    Selection select_external_front(const ExternalFrontContext &front_context) const;

    SessionGate::SessionDecision evaluate(
        const Selection &selection,
        const boost::asio::ip::tcp::endpoint &endpoint,
        boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket,
        std::string_view initial_data) const;

private:
    bool external_front_mode_enabled;
    EmbeddedTlsInbound embedded_tls_inbound;
    ExternalFrontInbound external_front_inbound;
};

#endif // _SERVER_INGRESS_SELECTOR_H_
