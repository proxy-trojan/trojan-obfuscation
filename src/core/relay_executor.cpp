#include "relay_executor.h"

using namespace std;
using namespace boost::asio::ip;

RelayExecutor::RelayExecutor(const Config &config) : outbound_dialer(config) {}

RelayExecutionPlan RelayExecutor::build_execution_plan(const SessionGate::SessionDecision &decision) const {
    RelayExecutionPlan plan;
    plan.target = decision.target;
    plan.initial_outbound_payload = decision.outbound_payload;

    if (decision.path == SessionGate::Path::AUTHENTICATED_UDP) {
        plan.mode = RelayMode::StartUdpForward;
        plan.log_message = "requested UDP associate to " + decision.request.address.address + ':' + to_string(decision.request.address.port);
        plan.log_as_warning = false;
        return plan;
    }

    if (decision.path == SessionGate::Path::AUTHENTICATED_TCP) {
        plan.mode = RelayMode::StartTcpForward;
        plan.log_message = "requested connection to " + decision.request.address.address + ':' + to_string(decision.request.address.port);
        plan.log_as_warning = false;
        return plan;
    }

    plan.mode = RelayMode::StartTcpForward;
    plan.log_message = "not trojan request, connecting to " + decision.target.host + ':' + to_string(decision.target.port);
    plan.log_as_warning = true;
    plan.requires_fallback_slot = true;
    return plan;
}

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
