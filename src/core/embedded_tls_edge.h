#ifndef _EMBEDDED_TLS_EDGE_H_
#define _EMBEDDED_TLS_EDGE_H_

#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl.hpp>
#include "session_types.h"

class EmbeddedTlsEdgeContextBuilder {
public:
    SessionContext build_context(const boost::asio::ip::tcp::endpoint &endpoint,
                                 boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket) const;

    SessionGateInput build_gate_input(const boost::asio::ip::tcp::endpoint &endpoint,
                                      boost::asio::ssl::stream<boost::asio::ip::tcp::socket> &socket,
                                      const std::string_view &initial_data) const;
};

#endif // _EMBEDDED_TLS_EDGE_H_
