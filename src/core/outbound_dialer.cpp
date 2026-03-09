#include "outbound_dialer.h"
#include "log.h"

using namespace std;
using namespace boost::asio::ip;

OutboundDialer::OutboundDialer(const Config &config) : config(config) {}

void OutboundDialer::resolve_tcp(tcp::resolver &resolver,
                                 const tcp::endpoint &in_endpoint,
                                 const string &query_addr,
                                 const string &query_port,
                                 ResolveSuccess on_success,
                                 FailureHandler on_failure) const {
    resolver.async_resolve(query_addr, query_port,
        [this, in_endpoint, query_addr, on_success = std::move(on_success), on_failure = std::move(on_failure)]
        (const boost::system::error_code error, const tcp::resolver::results_type& results) mutable {
            if (error || results.empty()) {
                on_failure("cannot resolve remote server hostname " + query_addr + ": " + error.message());
                return;
            }
            auto iterator = results.begin();
            if (config.tcp.prefer_ipv4) {
                for (auto it = results.begin(); it != results.end(); ++it) {
                    const auto &addr = it->endpoint().address();
                    if (addr.is_v4()) {
                        iterator = it;
                        break;
                    }
                }
            }
            Log::log_with_endpoint(in_endpoint, query_addr + " is resolved to " + iterator->endpoint().address().to_string(), Log::ALL);
            on_success(iterator);
        });
}

void OutboundDialer::connect_tcp(tcp::socket &socket,
                                 tcp::resolver::results_type::const_iterator endpoint,
                                 const tcp::endpoint &in_endpoint,
                                 const string &query_addr,
                                 const string &query_port,
                                 ConnectSuccess on_success,
                                 FailureHandler on_failure) const {
    boost::system::error_code ec;
    socket.open(endpoint->endpoint().protocol(), ec);
    if (ec) {
        on_failure("cannot open outbound socket: " + ec.message());
        return;
    }
    if (config.tcp.no_delay) {
        socket.set_option(tcp::no_delay(true));
    }
    if (config.tcp.keep_alive) {
        socket.set_option(boost::asio::socket_base::keep_alive(true));
    }
#ifdef TCP_FASTOPEN_CONNECT
    if (config.tcp.fast_open) {
        using fastopen_connect = boost::asio::detail::socket_option::boolean<IPPROTO_TCP, TCP_FASTOPEN_CONNECT>;
        boost::system::error_code fast_open_ec;
        socket.set_option(fastopen_connect(true), fast_open_ec);
    }
#endif // TCP_FASTOPEN_CONNECT
    socket.async_connect(*endpoint,
        [in_endpoint, query_addr, query_port, on_success = std::move(on_success), on_failure = std::move(on_failure)]
        (const boost::system::error_code error) mutable {
            if (error) {
                on_failure("cannot establish connection to remote server " + query_addr + ':' + query_port + ": " + error.message());
                return;
            }
            Log::log_with_endpoint(in_endpoint, "tunnel established");
            on_success();
        });
}
