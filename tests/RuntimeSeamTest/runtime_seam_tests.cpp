#include <exception>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <boost/asio/ip/address.hpp>
#include <boost/asio/ip/tcp.hpp>
#include "core/config.h"
#include "core/external_front_inbound.h"
#include "core/external_front_trust_policy.h"
#include "core/log.h"
#include "core/relay_executor.h"
#include "core/session_admission_runtime.h"
#include "core/session_lifecycle_runtime.h"
using namespace std;
using namespace boost::asio::ip;

namespace {

struct TestFailure : runtime_error {
    using runtime_error::runtime_error;
};

void expect_true(bool condition, const string &message) {
    if (!condition) {
        throw TestFailure(message);
    }
}

tcp::endpoint loopback_endpoint(uint16_t port = 443) {
    return tcp::endpoint(make_address("127.0.0.1"), port);
}

Config make_test_config() {
    Config config{};
    config.run_type = Config::SERVER;
    config.local_addr = "127.0.0.1";
    config.local_port = 443;
    config.remote_addr = "127.0.0.1";
    config.remote_port = 80;
    config.target_addr = "";
    config.target_port = 0;
    config.udp_timeout = 60;
    config.threads = 1;
    config.log_level = Log::INFO;
    config.ssl.verify = false;
    config.ssl.verify_hostname = false;
    config.ssl.prefer_server_cipher = true;
    config.ssl.reuse_session = true;
    config.ssl.session_ticket = false;
    config.ssl.session_timeout = 600;
    config.tcp.prefer_ipv4 = false;
    config.tcp.no_delay = true;
    config.tcp.keep_alive = true;
    config.tcp.reuse_port = false;
    config.tcp.fast_open = false;
    config.tcp.fast_open_qlen = 20;
    config.mysql.enabled = false;
    config.abuse_control.enabled = true;
    config.abuse_control.per_ip_max_connections = 64;
    config.abuse_control.auth_fail_window_seconds = 60;
    config.abuse_control.auth_fail_max = 20;
    config.abuse_control.cooldown_seconds = 60;
    config.abuse_control.fallback_max_active = 32;
    return config;
}

void test_admission_runtime_external_auth_records_password() {
    int auth_success_calls = 0;
    int auth_failure_calls = 0;
    string auth_password;
    SessionAdmissionRuntime runtime(
        [&]() { ++auth_success_calls; },
        [&](const tcp::endpoint &) { ++auth_failure_calls; },
        {});

    SessionGate::SessionDecision decision;
    decision.valid_trojan_request = true;
    decision.authenticated = true;
    decision.used_external_authenticator = true;
    decision.auth_record_password = "external-password";

    runtime.apply_auth_result(loopback_endpoint(), decision, auth_password);

    expect_true(auth_success_calls == 1, "external auth should record one success callback");
    expect_true(auth_failure_calls == 0, "external auth should not record failure callback");
    expect_true(auth_password == "external-password", "external auth should store auth password");
}

void test_admission_runtime_configured_credential_does_not_store_password() {
    int auth_success_calls = 0;
    int auth_failure_calls = 0;
    string auth_password;
    SessionAdmissionRuntime runtime(
        [&]() { ++auth_success_calls; },
        [&](const tcp::endpoint &) { ++auth_failure_calls; },
        {});

    SessionGate::SessionDecision decision;
    decision.valid_trojan_request = true;
    decision.authenticated = true;
    decision.used_external_authenticator = false;
    decision.auth_record_password = "ignored";

    runtime.apply_auth_result(loopback_endpoint(), decision, auth_password);

    expect_true(auth_success_calls == 1, "configured credential auth should record one success callback");
    expect_true(auth_failure_calls == 0, "configured credential auth should not record failure callback");
    expect_true(auth_password.empty(), "configured credential auth should not overwrite auth password");
}

void test_admission_runtime_auth_failure_records_failure_only() {
    int auth_success_calls = 0;
    int auth_failure_calls = 0;
    string auth_password = "unchanged";
    SessionAdmissionRuntime runtime(
        [&]() { ++auth_success_calls; },
        [&](const tcp::endpoint &) { ++auth_failure_calls; },
        {});

    SessionGate::SessionDecision decision;
    decision.valid_trojan_request = true;
    decision.authenticated = false;

    runtime.apply_auth_result(loopback_endpoint(), decision, auth_password);

    expect_true(auth_success_calls == 0, "auth failure should not record success callback");
    expect_true(auth_failure_calls == 1, "auth failure should record one failure callback");
    expect_true(auth_password == "unchanged", "auth failure should not mutate auth password");
}

void test_admission_runtime_fallback_slot_paths() {
    bool fallback_slot_acquired = false;
    SessionAdmissionRuntime no_callback({}, {}, {});
    expect_true(no_callback.try_acquire_fallback_slot(fallback_slot_acquired), "missing fallback callback should be treated as allowed");
    expect_true(!fallback_slot_acquired, "missing fallback callback should not mutate slot flag");

    int callback_calls = 0;
    SessionAdmissionRuntime allow({}, {}, [&]() {
        ++callback_calls;
        return true;
    });
    expect_true(allow.try_acquire_fallback_slot(fallback_slot_acquired), "fallback callback returning true should allow slot");
    expect_true(fallback_slot_acquired, "allowed fallback slot should set acquired flag");

    SessionAdmissionRuntime deny({}, {}, [&]() {
        ++callback_calls;
        return false;
    });
    expect_true(!deny.try_acquire_fallback_slot(fallback_slot_acquired), "fallback callback returning false should deny slot");
    expect_true(!fallback_slot_acquired, "denied fallback slot should clear acquired flag");
    expect_true(callback_calls == 2, "fallback callback should be invoked for allow and deny paths");
}

void test_lifecycle_runtime_release_slots() {
    bool connection_slot_acquired = true;
    bool fallback_slot_acquired = true;
    int release_connection_calls = 0;
    int release_fallback_calls = 0;
    tcp::endpoint released_endpoint;

    SessionLifecycleRuntime runtime(
        [&](const tcp::endpoint &endpoint) {
            ++release_connection_calls;
            released_endpoint = endpoint;
        },
        [&]() { ++release_fallback_calls; });

    runtime.release_slots(loopback_endpoint(8443), connection_slot_acquired, fallback_slot_acquired);

    expect_true(release_connection_calls == 1, "connection slot should be released once");
    expect_true(release_fallback_calls == 1, "fallback slot should be released once");
    expect_true(!connection_slot_acquired, "connection slot flag should be cleared");
    expect_true(!fallback_slot_acquired, "fallback slot flag should be cleared");
    expect_true(released_endpoint == loopback_endpoint(8443), "released endpoint should match input endpoint");
}

void test_lifecycle_runtime_release_slots_respects_flags() {
    bool connection_slot_acquired = false;
    bool fallback_slot_acquired = false;
    int release_connection_calls = 0;
    int release_fallback_calls = 0;

    SessionLifecycleRuntime runtime(
        [&](const tcp::endpoint &) { ++release_connection_calls; },
        [&]() { ++release_fallback_calls; });

    runtime.release_slots(loopback_endpoint(), connection_slot_acquired, fallback_slot_acquired);

    expect_true(release_connection_calls == 0, "connection release callback should not run when slot not acquired");
    expect_true(release_fallback_calls == 0, "fallback release callback should not run when slot not acquired");
}

void test_relay_executor_build_execution_plan_for_authenticated_tcp() {
    Config config = make_test_config();
    RelayExecutor executor(config);

    SessionGate::SessionDecision decision;
    decision.path = SessionGate::Path::AUTHENTICATED_TCP;
    decision.target.host = "example.com";
    decision.target.port = 443;
    decision.outbound_payload = "tcp-payload";
    decision.request.address.address = "example.com";
    decision.request.address.port = 443;

    RelayExecutionPlan plan = executor.build_execution_plan(decision);

    expect_true(plan.mode == RelayMode::StartTcpForward, "authenticated tcp should produce StartTcpForward plan");
    expect_true(plan.target.host == "example.com", "tcp plan should preserve target host");
    expect_true(plan.target.port == 443, "tcp plan should preserve target port");
    expect_true(plan.initial_outbound_payload == "tcp-payload", "tcp plan should preserve outbound payload");
    expect_true(!plan.requires_fallback_slot, "authenticated tcp should not require fallback slot");
    expect_true(!plan.log_as_warning, "authenticated tcp log should not be warning");
    expect_true(plan.log_message.find("requested connection to example.com:443") != string::npos, "authenticated tcp should describe requested connection");
}

void test_relay_executor_build_execution_plan_for_authenticated_udp() {
    Config config = make_test_config();
    RelayExecutor executor(config);

    SessionGate::SessionDecision decision;
    decision.path = SessionGate::Path::AUTHENTICATED_UDP;
    decision.target.host = "8.8.8.8";
    decision.target.port = 53;
    decision.outbound_payload = "udp-payload";
    decision.request.address.address = "dns.google";
    decision.request.address.port = 53;

    RelayExecutionPlan plan = executor.build_execution_plan(decision);

    expect_true(plan.mode == RelayMode::StartUdpForward, "authenticated udp should produce StartUdpForward plan");
    expect_true(plan.target.host == "8.8.8.8", "udp plan should preserve target host");
    expect_true(plan.target.port == 53, "udp plan should preserve target port");
    expect_true(plan.initial_outbound_payload == "udp-payload", "udp plan should preserve outbound payload");
    expect_true(!plan.requires_fallback_slot, "authenticated udp should not require fallback slot");
    expect_true(!plan.log_as_warning, "authenticated udp log should not be warning");
    expect_true(plan.log_message.find("requested UDP associate to dns.google:53") != string::npos, "authenticated udp should describe requested associate target");
}

void test_relay_executor_build_execution_plan_for_fallback() {
    Config config = make_test_config();
    RelayExecutor executor(config);

    SessionGate::SessionDecision decision;
    decision.path = SessionGate::Path::FALLBACK;
    decision.target.host = "fallback.internal";
    decision.target.port = 8080;
    decision.outbound_payload = "fallback-payload";

    RelayExecutionPlan plan = executor.build_execution_plan(decision);

    expect_true(plan.mode == RelayMode::StartTcpForward, "fallback should reuse tcp-forward execution mode");
    expect_true(plan.target.host == "fallback.internal", "fallback plan should preserve target host");
    expect_true(plan.target.port == 8080, "fallback plan should preserve target port");
    expect_true(plan.initial_outbound_payload == "fallback-payload", "fallback plan should preserve outbound payload");
    expect_true(plan.requires_fallback_slot, "fallback plan should require fallback slot");
    expect_true(plan.log_as_warning, "fallback log should be warning-level");
    expect_true(plan.log_message.find("not trojan request, connecting to fallback.internal:8080") != string::npos, "fallback plan should describe fallback destination");
}

void test_relay_executor_begin_tcp_relay_fast_fails_when_fallback_slot_denied() {
    Config config = make_test_config();
    RelayExecutor executor(config);
    boost::asio::io_context io_context;
    tcp::resolver resolver(io_context);
    tcp::socket socket(io_context);

    int acquire_calls = 0;
    int success_calls = 0;
    int failure_calls = 0;
    string failure_message;

    bool started = executor.begin_tcp_relay(
        resolver,
        socket,
        loopback_endpoint(),
        ConnectTarget{"blocked.example", 443, true},
        true,
        [&]() {
            ++acquire_calls;
            return false;
        },
        [&]() {
            ++success_calls;
        },
        [&](const string &message) {
            ++failure_calls;
            failure_message = message;
        });

    expect_true(!started, "relay should not start when fallback slot acquisition is denied");
    expect_true(acquire_calls == 1, "fallback slot acquisition should be attempted once");
    expect_true(success_calls == 0, "success handler should not run on fast-fail path");
    expect_true(failure_calls == 1, "failure handler should run once on fast-fail path");
    expect_true(failure_message == "fallback rejected: active fallback session budget exhausted", "fast-fail path should report fallback budget exhaustion");
}

void test_external_front_inbound_builds_context_from_verified_metadata() {
    ExternalFrontInbound inbound;
    ExternalFrontContext front_context;
    front_context.trusted_front_id = "front-1";
    front_context.original_client_ip = "203.0.113.10";
    front_context.original_client_port = 45678;
    front_context.server_name = "example.com";
    front_context.negotiated_alpn = "h2";
    front_context.ingress_mode = "external_front";
    front_context.tls_terminated_by_front = true;
    front_context.metadata_verified = true;

    SessionContext context = inbound.build_context(front_context);

    expect_true(context.source_ip == "203.0.113.10", "external front context should preserve original client ip");
    expect_true(context.source_port == 45678, "external front context should preserve original client port");
    expect_true(context.selected_alpn == "h2", "external front context should preserve negotiated ALPN");
    expect_true(context.tls_handshake_completed, "verified front-terminated tls should be treated as handshake completed");
    expect_true(context.inbound_mode == InboundMode::ExternalFront, "external front context should set inbound mode");
}

void test_external_front_inbound_validates_trusted_metadata() {
    ExternalFrontInbound inbound;
    ExternalFrontContext trusted;
    trusted.trusted_front_id = "front-1";
    trusted.original_client_ip = "203.0.113.10";
    trusted.original_client_port = 45678;
    trusted.tls_terminated_by_front = true;
    trusted.metadata_verified = true;

    ExternalFrontContext untrusted = trusted;
    untrusted.metadata_verified = false;

    expect_true(inbound.is_trusted_metadata(trusted), "verified external front metadata should be trusted");
    expect_true(!inbound.is_trusted_metadata(untrusted), "unverified external front metadata should not be trusted");

    SessionContext untrusted_context = inbound.build_context(untrusted);
    expect_true(untrusted_context.source_ip.empty(), "untrusted external front metadata should not populate source ip");
    expect_true(untrusted_context.source_port == 0, "untrusted external front metadata should not populate source port");
    expect_true(untrusted_context.selected_alpn.empty(), "untrusted external front metadata should not populate ALPN");
    expect_true(!untrusted_context.tls_handshake_completed, "untrusted external front metadata should not mark tls handshake complete");
    expect_true(untrusted_context.inbound_mode == InboundMode::ExternalFront, "external front mode should still be identified even when metadata is untrusted");
}

void test_external_front_inbound_evaluates_fallback_with_alpn_override() {
    Config config = make_test_config();
    config.remote_addr = "fallback.internal";
    config.remote_port = 443;
    config.ssl.alpn_port_override["h2"] = 8443;

    ExternalFrontInbound inbound(config, nullptr);
    ExternalFrontContext front_context;
    front_context.trusted_front_id = "front-1";
    front_context.original_client_ip = "203.0.113.10";
    front_context.original_client_port = 45678;
    front_context.negotiated_alpn = "h2";
    front_context.tls_terminated_by_front = true;
    front_context.metadata_verified = true;

    auto decision = inbound.evaluate_initial_data(front_context, "not-a-trojan-request");

    expect_true(decision.path == SessionGate::Path::FALLBACK, "external front fallback path should remain available");
    expect_true(decision.target.host == "fallback.internal", "fallback decision should preserve configured remote host");
    expect_true(decision.target.port == 8443, "fallback decision should apply ALPN port override from trusted front metadata");
    expect_true(decision.target.is_fallback, "fallback decision should mark target as fallback");
    expect_true(decision.outbound_payload == "not-a-trojan-request", "fallback decision should preserve initial payload");
}

void test_external_front_trust_policy_requires_front_id_client_identity_and_verified_tls() {
    ExternalFrontTrustPolicy policy;
    ExternalFrontContext context;
    context.trusted_front_id = "front-1";
    context.original_client_ip = "203.0.113.10";
    context.original_client_port = 45678;
    context.tls_terminated_by_front = true;
    context.metadata_verified = true;

    expect_true(policy.is_trusted(context), "fully populated trusted front metadata should be accepted");

    ExternalFrontContext missing_front_id = context;
    missing_front_id.trusted_front_id.clear();
    expect_true(!policy.is_trusted(missing_front_id), "missing trusted front id should be rejected");

    ExternalFrontContext missing_client_ip = context;
    missing_client_ip.original_client_ip.clear();
    expect_true(!policy.is_trusted(missing_client_ip), "missing original client identity should be rejected");

    ExternalFrontContext unverified = context;
    unverified.metadata_verified = false;
    expect_true(!policy.is_trusted(unverified), "unverified metadata should be rejected");

    ExternalFrontContext not_terminated = context;
    not_terminated.tls_terminated_by_front = false;
    expect_true(!policy.is_trusted(not_terminated), "metadata without verified front-side tls termination should be rejected");
}

} // namespace

int main() {
    try {
        Log::redirect("/dev/null");
        Log::set_callback({});

        test_admission_runtime_external_auth_records_password();
        test_admission_runtime_configured_credential_does_not_store_password();
        test_admission_runtime_auth_failure_records_failure_only();
        test_admission_runtime_fallback_slot_paths();
        test_lifecycle_runtime_release_slots();
        test_lifecycle_runtime_release_slots_respects_flags();
        test_relay_executor_build_execution_plan_for_authenticated_tcp();
        test_relay_executor_build_execution_plan_for_authenticated_udp();
        test_relay_executor_build_execution_plan_for_fallback();
        test_relay_executor_begin_tcp_relay_fast_fails_when_fallback_slot_denied();
        test_external_front_inbound_builds_context_from_verified_metadata();
        test_external_front_inbound_validates_trusted_metadata();
        test_external_front_inbound_evaluates_fallback_with_alpn_override();
        test_external_front_trust_policy_requires_front_id_client_identity_and_verified_tls();

        Log::reset();
        Log::set_callback({});
        return 0;
    } catch (const exception &ex) {
        cerr << "runtime_seam_tests failed: " << ex.what() << endl;
        Log::reset();
        Log::set_callback({});
        return 1;
    }
}
