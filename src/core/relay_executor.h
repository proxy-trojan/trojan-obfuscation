#ifndef _RELAY_EXECUTOR_H_
#define _RELAY_EXECUTOR_H_

#include <functional>
#include <string>
#include <boost/asio/ip/tcp.hpp>
#include "config.h"
#include "outbound_dialer.h"
#include "session_types.h"

class RelayExecutor {
public:
    using FailureHandler = std::function<void(const std::string&)>;
    using ConnectSuccess = std::function<void()>;
    using AcquireFallbackSlot = std::function<bool()>;

    explicit RelayExecutor(const Config &config);

    bool begin_tcp_relay(boost::asio::ip::tcp::resolver &resolver,
                         boost::asio::ip::tcp::socket &socket,
                         const boost::asio::ip::tcp::endpoint &in_endpoint,
                         const ConnectTarget &target,
                         bool requires_fallback_slot,
                         AcquireFallbackSlot acquire_fallback_slot,
                         ConnectSuccess on_success,
                         FailureHandler on_failure) const;

private:
    OutboundDialer outbound_dialer;
};

#endif // _RELAY_EXECUTOR_H_
