#include "server_ingress_selector.h"
#include <stdexcept>

ServerIngressSelector::ServerIngressSelector(const Config &config, Authenticator *auth)
    : embedded_tls_inbound(config, auth),
      external_front_inbound(config, auth) {}

ServerIngressSelector::Selection ServerIngressSelector::select_default() const {
    return Selection{};
}

ServerIngressSelector::Selection ServerIngressSelector::select_external_front(const ExternalFrontContext &front_context) const {
    Selection selection;
    selection.mode = InboundMode::ExternalFront;
    selection.external_front_context = front_context;
    return selection;
}

SessionGate::SessionDecision ServerIngressSelector::evaluate(
    const Selection &selection,
    const boost::asio::ip::tcp::endpoint &endpoint,
    boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket,
    std::string_view initial_data) const {
    if (selection.mode == InboundMode::ExternalFront) {
        if (!selection.external_front_context.has_value()) {
            throw std::logic_error("external front selection requires external front context");
        }
        return external_front_inbound.evaluate_initial_data(*selection.external_front_context, initial_data);
    }
    return embedded_tls_inbound.evaluate_initial_data(endpoint, socket, initial_data);
}
