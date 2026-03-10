#ifndef _OUTBOUND_DIALER_H_
#define _OUTBOUND_DIALER_H_

#include <functional>
#include <string>
#include <boost/asio/ip/tcp.hpp>
#include "config.h"
#include "session_types.h"

class OutboundDialer {
public:
    using ResolveSuccess = std::function<void(boost::asio::ip::tcp::resolver::results_type::const_iterator)>;
    using FailureHandler = std::function<void(const std::string&)>;
    using ConnectSuccess = std::function<void()>;

    explicit OutboundDialer(const Config &config);

    void resolve_tcp(boost::asio::ip::tcp::resolver &resolver,
                     const boost::asio::ip::tcp::endpoint &in_endpoint,
                     const ConnectTarget &target,
                     ResolveSuccess on_success,
                     FailureHandler on_failure) const;

    void connect_tcp(boost::asio::ip::tcp::socket &socket,
                     boost::asio::ip::tcp::resolver::results_type::const_iterator endpoint,
                     const boost::asio::ip::tcp::endpoint &in_endpoint,
                     const ConnectTarget &target,
                     ConnectSuccess on_success,
                     FailureHandler on_failure) const;

private:
    const Config &config;
};

#endif // _OUTBOUND_DIALER_H_
