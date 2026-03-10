#ifndef _EMBEDDED_TLS_INBOUND_H_
#define _EMBEDDED_TLS_INBOUND_H_

#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl.hpp>
#include "authenticator.h"
#include "config.h"
#include "embedded_tls_edge.h"
#include "session_gate.h"
#include "session_types.h"

class EmbeddedTlsInbound {
public:
    EmbeddedTlsInbound(const Config &config, Authenticator *auth);

    SessionContext build_context(const boost::asio::ip::tcp::endpoint &endpoint,
                                 boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket) const;

    SessionGateInput build_gate_input(const boost::asio::ip::tcp::endpoint &endpoint,
                                      boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket,
                                      const std::string_view &initial_data) const;

    SessionGate::SessionDecision evaluate_initial_data(
        const boost::asio::ip::tcp::endpoint &endpoint,
        boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket,
        const std::string_view &initial_data) const;

private:
    EmbeddedTlsEdgeContextBuilder edge_context_builder;
    SessionGate session_gate;
};

#endif // _EMBEDDED_TLS_INBOUND_H_
