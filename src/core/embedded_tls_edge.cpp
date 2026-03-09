#include "embedded_tls_edge.h"

SessionContext EmbeddedTlsEdgeContextBuilder::build_context(
    const boost::asio::ip::tcp::endpoint &endpoint,
    boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket) const {
    SessionContext context;
    context.source_ip = endpoint.address().to_string();
    context.source_port = endpoint.port();
    context.tls_handshake_completed = true;
    context.inbound_mode = InboundMode::EmbeddedTls;

    const unsigned char *alpn_out = nullptr;
    unsigned int alpn_len = 0;
    SSL_get0_alpn_selected(socket.native_handle(), &alpn_out, &alpn_len);
    if (alpn_out != nullptr) {
        context.selected_alpn.assign(reinterpret_cast<const char*>(alpn_out), alpn_len);
    }
    return context;
}

SessionGateInput EmbeddedTlsEdgeContextBuilder::build_gate_input(
    const boost::asio::ip::tcp::endpoint &endpoint,
    boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket,
    const std::string_view &initial_data) const {
    SessionGateInput input;
    input.context = build_context(endpoint, socket);
    input.initial_data = initial_data;
    return input;
}
