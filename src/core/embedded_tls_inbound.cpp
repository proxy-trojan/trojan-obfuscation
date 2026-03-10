#include "embedded_tls_inbound.h"

EmbeddedTlsInbound::EmbeddedTlsInbound(const Config &config, Authenticator *auth)
    : edge_context_builder(), session_gate(config, auth) {}

SessionContext EmbeddedTlsInbound::build_context(
    const boost::asio::ip::tcp::endpoint &endpoint,
    boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket) const {
    return edge_context_builder.build_context(endpoint, socket);
}

SessionGateInput EmbeddedTlsInbound::build_gate_input(
    const boost::asio::ip::tcp::endpoint &endpoint,
    boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket,
    const std::string_view &initial_data) const {
    return edge_context_builder.build_gate_input(endpoint, socket, initial_data);
}

SessionGate::SessionDecision EmbeddedTlsInbound::evaluate_initial_data(
    const boost::asio::ip::tcp::endpoint &endpoint,
    boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket,
    const std::string_view &initial_data) const {
    return session_gate.evaluate(build_gate_input(endpoint, socket, initial_data));
}
