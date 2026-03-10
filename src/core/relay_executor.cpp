#include "relay_executor.h"

using namespace std;
using namespace boost::asio::ip;

RelayExecutor::RelayExecutor(const Config &config) : outbound_dialer(config) {}

bool RelayExecutor::begin_tcp_relay(tcp::resolver &resolver,
                                    tcp::socket &socket,
                                    const tcp::endpoint &in_endpoint,
                                    const ConnectTarget &target,
                                    bool requires_fallback_slot,
                                    AcquireFallbackSlot acquire_fallback_slot,
                                    ConnectSuccess on_success,
                                    FailureHandler on_failure) const {
    if (requires_fallback_slot) {
        if (!acquire_fallback_slot || !acquire_fallback_slot()) {
            on_failure("fallback rejected: active fallback session budget exhausted");
            return false;
        }
    }

    auto resolve_failure = on_failure;
    outbound_dialer.resolve_tcp(
        resolver,
        in_endpoint,
        target,
        [&socket, in_endpoint, target, this, on_success = std::move(on_success), on_failure = std::move(on_failure)]
        (tcp::resolver::results_type::const_iterator iterator) mutable {
            outbound_dialer.connect_tcp(
                socket,
                iterator,
                in_endpoint,
                target,
                std::move(on_success),
                std::move(on_failure));
        },
        std::move(resolve_failure));

    return true;
}
