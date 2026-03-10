#include <exception>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <boost/asio/ip/address.hpp>
#include <boost/asio/ip/tcp.hpp>
#include "core/config.h"
#include "core/external_front_handoff_builder.h"
#include "core/external_front_handoff_contract.h"
#include "core/external_front_inbound.h"
#include "core/trusted_internal_handoff_input.h"
#include "core/external_front_metadata_provider.h"
#include "core/external_front_trust_policy.h"
#include "core/log.h"
#include "core/relay_executor.h"
#include "core/server_ingress_selector.h"
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
    config.external_front.enabled = false;
    config.external_front.inject_test_metadata = false;
    config.external_front.test_trusted_front_id = "";
    config.external_front.test_original_client_ip = "";
    config.external_front.test_original_client_port = 0;
    config.external_front.test_negotiated_alpn = "";
    config.external_front.test_tls_terminated_by_front = false;
    config.external_front.test_metadata_verified = false;
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

    ExternalFrontValidationResult trusted_result{ExternalFrontValidationStatus::Trusted};
    expect_true(inbound.should_apply_client_identity(trusted_result), "trusted validation should allow client identity shaping");
    expect_true(inbound.should_apply_transport_context(trusted_result), "trusted validation should allow transport context shaping");

    ExternalFrontValidationResult rejected_result{ExternalFrontValidationStatus::MissingVerifiedTlsTermination};
    expect_true(!inbound.should_apply_client_identity(rejected_result), "rejected validation should not allow client identity shaping");
    expect_true(!inbound.should_apply_transport_context(rejected_result), "rejected validation should not allow transport context shaping");

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

    auto trusted = policy.validate(context);
    expect_true(trusted.trusted(), "fully populated trusted front metadata should be accepted");
    expect_true(trusted.status == ExternalFrontValidationStatus::Trusted, "trusted metadata should return Trusted status");
    expect_true(external_front_validation_status_name(trusted.status) == "trusted", "trusted status should expose stable reason string");

    ExternalFrontContext missing_front_id = context;
    missing_front_id.trusted_front_id.clear();
    auto missing_front_id_result = policy.validate(missing_front_id);
    expect_true(!missing_front_id_result.trusted(), "missing trusted front id should be rejected");
    expect_true(missing_front_id_result.status == ExternalFrontValidationStatus::MissingTrustedFrontId, "missing trusted front id should return the right validation status");
    expect_true(external_front_validation_status_name(missing_front_id_result.status) == "missing_trusted_front_id", "missing front-id status should expose stable reason string");

    ExternalFrontContext missing_client_ip = context;
    missing_client_ip.original_client_ip.clear();
    auto missing_client_ip_result = policy.validate(missing_client_ip);
    expect_true(!missing_client_ip_result.trusted(), "missing original client identity should be rejected");
    expect_true(missing_client_ip_result.status == ExternalFrontValidationStatus::MissingOriginalClientIdentity, "missing original client identity should return the right validation status");
    expect_true(external_front_validation_status_name(missing_client_ip_result.status) == "missing_original_client_identity", "missing client-identity status should expose stable reason string");

    ExternalFrontContext unverified = context;
    unverified.metadata_verified = false;
    auto unverified_result = policy.validate(unverified);
    expect_true(!unverified_result.trusted(), "unverified metadata should be rejected");
    expect_true(unverified_result.status == ExternalFrontValidationStatus::MissingVerifiedTlsTermination, "unverified metadata should report verified-tls requirement failure");
    expect_true(external_front_validation_status_name(unverified_result.status) == "missing_verified_tls_termination", "unverified status should expose stable reason string");

    ExternalFrontContext not_terminated = context;
    not_terminated.tls_terminated_by_front = false;
    auto not_terminated_result = policy.validate(not_terminated);
    expect_true(!not_terminated_result.trusted(), "metadata without verified front-side tls termination should be rejected");
    expect_true(not_terminated_result.status == ExternalFrontValidationStatus::MissingVerifiedTlsTermination, "missing front-side tls termination should report verified-tls requirement failure");
    expect_true(external_front_validation_status_name(not_terminated_result.status) == "missing_verified_tls_termination", "non-terminated status should expose stable reason string");
}

void test_config_external_front_metadata_provider_respects_enablement() {
    Config disabled = make_test_config();
    ConfigExternalFrontMetadataProvider disabled_provider(disabled);
    expect_true(!disabled_provider.active(), "provider should report inactive when external-front mode is disabled");
    expect_true(disabled_provider.injection_mode_name() == "test_injected_external_front", "provider should expose stable injection mode name");
    auto disabled_context = disabled_provider.maybe_build_context();
    expect_true(!disabled_context.has_value(), "provider should not inject metadata when external-front mode is disabled");

    auto disabled_injection = disabled_provider.evaluate_injection();
    expect_true(disabled_injection.decision == ExternalFrontMetadataProvider::Decision::Inactive,
                "disabled provider should evaluate to inactive decision");
    expect_true(disabled_injection.mode == "test_injected_external_front",
                "disabled provider should still expose stable mode name");
    expect_true(!disabled_injection.context.has_value(),
                "disabled provider should not carry metadata context");

    Config enabled = make_test_config();
    enabled.external_front.enabled = true;
    enabled.external_front.inject_test_metadata = true;
    enabled.external_front.test_trusted_front_id = "front-1";
    enabled.external_front.test_original_client_ip = "203.0.113.10";
    enabled.external_front.test_original_client_port = 45678;
    enabled.external_front.test_negotiated_alpn = "h2";
    enabled.external_front.test_tls_terminated_by_front = true;
    enabled.external_front.test_metadata_verified = true;

    ConfigExternalFrontMetadataProvider enabled_provider(enabled);
    expect_true(enabled_provider.active(), "provider should report active when explicitly enabled");
    expect_true(enabled_provider.injection_mode_name() == "test_injected_external_front", "provider should expose test injection mode name");
    auto enabled_context = enabled_provider.maybe_build_context();
    expect_true(enabled_context.has_value(), "provider should inject metadata when explicitly enabled");
    expect_true(enabled_context->trusted_front_id == "front-1", "provider should propagate configured trusted front id");
    expect_true(enabled_context->original_client_ip == "203.0.113.10", "provider should propagate configured original client ip");
    expect_true(enabled_context->original_client_port == 45678, "provider should propagate configured original client port");
    expect_true(enabled_context->negotiated_alpn == "h2", "provider should propagate configured negotiated ALPN");
    expect_true(enabled_context->tls_terminated_by_front, "provider should propagate configured tls-terminated flag");
    expect_true(enabled_context->metadata_verified, "provider should propagate configured metadata-verified flag");
    expect_true(enabled_context->ingress_mode == "test_injected_external_front", "provider should mark test-injected ingress mode");

    auto enabled_injection = enabled_provider.evaluate_injection();
    expect_true(enabled_injection.decision == ExternalFrontMetadataProvider::Decision::ActiveWithMetadata,
                "enabled provider should evaluate to active-with-metadata decision");
    expect_true(enabled_injection.mode == "test_injected_external_front",
                "enabled provider should expose the same mode in injection result");
    expect_true(enabled_injection.context.has_value(),
                "enabled provider injection result should include metadata context");
    expect_true(enabled_injection.context->trusted_front_id == "front-1",
                "injection result should preserve trusted front id");
}

void test_trusted_internal_handoff_input_contract_rejects_incomplete_inputs_and_accepts_verified_input() {
    TrustedInternalHandoffInputContract contract;

    TrustedInternalHandoffInput missing_source_name;
    auto missing_source_name_decision = contract.evaluate(missing_source_name);
    expect_true(!missing_source_name_decision.accepted(), "trusted-internal input without source name should be rejected");
    expect_true(missing_source_name_decision.reason == "rejected_missing_trusted_internal_source_name", "missing source name should expose stable rejection reason");

    TrustedInternalHandoffInput missing_front_id;
    missing_front_id.source_name = "internal_handoff_source";
    auto missing_front_id_decision = contract.evaluate(missing_front_id);
    expect_true(!missing_front_id_decision.accepted(), "trusted-internal input without trusted front id should be rejected");
    expect_true(missing_front_id_decision.reason == "rejected_missing_trusted_internal_front_id", "missing trusted front id should expose stable rejection reason");

    TrustedInternalHandoffInput missing_client_identity;
    missing_client_identity.source_name = "internal_handoff_source";
    missing_client_identity.trusted_front_id = "internal-front";
    auto missing_client_identity_decision = contract.evaluate(missing_client_identity);
    expect_true(!missing_client_identity_decision.accepted(), "trusted-internal input without client identity should be rejected");
    expect_true(missing_client_identity_decision.reason == "rejected_missing_trusted_internal_client_identity", "missing client identity should expose stable rejection reason");

    TrustedInternalHandoffInput missing_verified_tls;
    missing_verified_tls.source_name = "internal_handoff_source";
    missing_verified_tls.trusted_front_id = "internal-front";
    missing_verified_tls.original_client_ip = "203.0.113.10";
    auto missing_verified_tls_decision = contract.evaluate(missing_verified_tls);
    expect_true(!missing_verified_tls_decision.accepted(), "trusted-internal input without verified tls termination should be rejected");
    expect_true(missing_verified_tls_decision.reason == "rejected_missing_trusted_internal_verified_tls_termination", "missing verified tls termination should expose stable rejection reason");

    TrustedInternalHandoffInput accepted_input;
    accepted_input.source_name = "internal_handoff_source";
    accepted_input.trusted_front_id = "internal-front";
    accepted_input.original_client_ip = "203.0.113.10";
    accepted_input.original_client_port = 45678;
    accepted_input.server_name = "front.example.com";
    accepted_input.negotiated_alpn = "h2";
    accepted_input.tls_terminated_by_front = true;
    accepted_input.metadata_verified = true;
    auto accepted_decision = contract.evaluate(accepted_input);
    expect_true(accepted_decision.accepted(), "fully populated trusted-internal input should be accepted");
    expect_true(accepted_decision.reason == "accepted_trusted_internal_handoff_input", "accepted trusted-internal input should expose stable acceptance reason");
}

void test_external_front_handoff_builder_shapes_test_injected_and_trusted_internal_handoffs() {
    ExternalFrontHandoffBuilder builder;

    ExternalFrontMetadataProvider::InjectionResult inactive_injection;
    inactive_injection.decision = ExternalFrontMetadataProvider::Decision::Inactive;
    inactive_injection.mode = "test_injected_external_front";
    auto inactive_handoff = builder.maybe_build_test_injected_handoff(inactive_injection);
    expect_true(!inactive_handoff.has_value(), "builder should not shape test-injected handoff without metadata context");

    ExternalFrontMetadataProvider::InjectionResult active_injection;
    active_injection.decision = ExternalFrontMetadataProvider::Decision::ActiveWithMetadata;
    active_injection.mode = "test_injected_external_front";
    ExternalFrontContext injected_context;
    injected_context.trusted_front_id = "front-1";
    injected_context.original_client_ip = "203.0.113.10";
    active_injection.context = injected_context;

    auto test_handoff = builder.maybe_build_test_injected_handoff(active_injection);
    expect_true(test_handoff.has_value(), "builder should shape test-injected handoff when metadata exists");
    expect_true(test_handoff->source_kind == ExternalFrontHandoffSourceKind::TestInjected, "test-injected handoff should expose test source kind");
    expect_true(test_handoff->source_name == "test_injected_external_front", "test-injected handoff should preserve source name");
    expect_true(test_handoff->context.has_value(), "test-injected handoff should carry metadata context");
    expect_true(test_handoff->context->trusted_front_id == "front-1", "test-injected handoff should preserve metadata context");

    TrustedInternalHandoffInput trusted_input;
    trusted_input.source_name = "internal_handoff_source";
    trusted_input.trusted_front_id = "internal-front";
    trusted_input.original_client_ip = "203.0.113.11";
    trusted_input.original_client_port = 45679;
    trusted_input.server_name = "front.example.com";
    trusted_input.negotiated_alpn = "h2";
    trusted_input.tls_terminated_by_front = true;
    trusted_input.metadata_verified = true;
    auto trusted_handoff = builder.maybe_build_trusted_internal_handoff(trusted_input);
    expect_true(trusted_handoff.has_value(), "trusted-internal builder should shape handoff for accepted input");
    expect_true(trusted_handoff->source_kind == ExternalFrontHandoffSourceKind::TrustedInternalHandoff, "trusted-internal builder should expose trusted-internal source kind");
    expect_true(trusted_handoff->source_name == "internal_handoff_source", "trusted-internal builder should preserve source name");
    expect_true(trusted_handoff->context.has_value(), "trusted-internal builder should always carry metadata context");
    expect_true(trusted_handoff->context->trusted_front_id == "internal-front", "trusted-internal builder should preserve trusted front id");
    expect_true(trusted_handoff->context->original_client_ip == "203.0.113.11", "trusted-internal builder should preserve original client ip");
    expect_true(trusted_handoff->context->ingress_mode == "trusted_internal_handoff", "trusted-internal builder should mark trusted internal ingress mode");
}

void test_external_front_handoff_contract_accepts_known_sources_and_rejects_unknown_or_missing_context() {
    ExternalFrontHandoffContract contract;

    ExternalFrontHandoff missing_context;
    missing_context.source_kind = ExternalFrontHandoffSourceKind::TestInjected;
    missing_context.source_name = "test_injected_external_front";
    auto missing_context_decision = contract.evaluate(missing_context);
    expect_true(!missing_context_decision.accepted(), "handoff without context should be rejected");
    expect_true(missing_context_decision.reason == "rejected_missing_handoff_context", "missing-context handoff should expose stable rejection reason");

    ExternalFrontHandoff unknown_source;
    unknown_source.source_kind = ExternalFrontHandoffSourceKind::Unknown;
    unknown_source.source_name = "mystery_front";
    unknown_source.context = ExternalFrontContext{};
    auto unknown_source_decision = contract.evaluate(unknown_source);
    expect_true(!unknown_source_decision.accepted(), "unknown handoff source should be rejected");
    expect_true(unknown_source_decision.reason == "rejected_unknown_handoff_source", "unknown handoff source should expose stable rejection reason");

    ExternalFrontHandoff test_injected;
    test_injected.source_kind = ExternalFrontHandoffSourceKind::TestInjected;
    test_injected.source_name = "test_injected_external_front";
    test_injected.context = ExternalFrontContext{};
    auto test_injected_decision = contract.evaluate(test_injected);
    expect_true(test_injected_decision.accepted(), "test-injected handoff should be accepted by the contract");
    expect_true(test_injected_decision.reason == "accepted_test_injected_handoff", "test-injected handoff should expose stable acceptance reason");

    ExternalFrontHandoff trusted_internal;
    trusted_internal.source_kind = ExternalFrontHandoffSourceKind::TrustedInternalHandoff;
    trusted_internal.source_name = "trusted_internal_front";
    trusted_internal.context = ExternalFrontContext{};
    auto trusted_internal_decision = contract.evaluate(trusted_internal);
    expect_true(trusted_internal_decision.accepted(), "trusted-internal handoff should be accepted by the contract");
    expect_true(trusted_internal_decision.reason == "accepted_trusted_internal_handoff", "trusted-internal handoff should expose stable acceptance reason");
}

void test_server_ingress_selector_routes_external_front_selection() {
    Config disabled_config = make_test_config();
    disabled_config.remote_addr = "fallback.internal";
    disabled_config.remote_port = 443;
    disabled_config.ssl.alpn_port_override["h2"] = 8443;

    ServerIngressSelector disabled_selector(disabled_config, nullptr);
    expect_true(!disabled_selector.external_front_enabled(), "external front ingress mode should be disabled by default");
    auto default_observation = disabled_selector.observe_default();
    expect_true(default_observation.status == ServerIngressSelector::ObservationStatus::EmbeddedTlsDefault, "default observation should report embedded tls default");
    expect_true(default_observation.reason == "embedded_tls_default", "default observation should carry embedded tls reason");
    auto default_selection = disabled_selector.select_default();
    expect_true(default_selection.mode == InboundMode::EmbeddedTls, "default ingress selection should remain embedded tls");
    expect_true(!default_selection.external_front_context.has_value(), "default ingress selection should not carry external front metadata");

    ExternalFrontContext front_context;
    front_context.trusted_front_id = "front-1";
    front_context.original_client_ip = "203.0.113.10";
    front_context.original_client_port = 45678;
    front_context.negotiated_alpn = "h2";
    front_context.tls_terminated_by_front = true;
    front_context.metadata_verified = true;

    auto disabled_observation = disabled_selector.observe_external_front(front_context);
    expect_true(disabled_observation.status == ServerIngressSelector::ObservationStatus::ExternalFrontDisabled, "disabled external front mode should report disabled observation status");
    expect_true(disabled_observation.reason == "external_front_disabled", "disabled external front mode should report disabled reason");

    auto disabled_selection = disabled_selector.select_external_front(front_context);
    expect_true(disabled_selection.mode == InboundMode::EmbeddedTls, "disabled external front mode should fall back to embedded tls selection");
    expect_true(!disabled_selection.external_front_context.has_value(), "disabled external front mode should not carry external front metadata");

    Config enabled_config = disabled_config;
    enabled_config.external_front.enabled = true;
    ServerIngressSelector enabled_selector(enabled_config, nullptr);
    expect_true(enabled_selector.external_front_enabled(), "external front ingress mode should be enabled when configured");

    ExternalFrontContext rejected_front_context = front_context;
    rejected_front_context.metadata_verified = false;
    auto rejected_observation = enabled_selector.observe_external_front(rejected_front_context);
    expect_true(rejected_observation.status == ServerIngressSelector::ObservationStatus::ExternalFrontRejected, "untrusted metadata should report rejected observation status");
    expect_true(rejected_observation.reason == "missing_verified_tls_termination", "untrusted metadata should expose validation reason");

    auto enabled_observation = enabled_selector.observe_external_front(front_context);
    expect_true(enabled_observation.status == ServerIngressSelector::ObservationStatus::ExternalFrontTrusted, "trusted metadata should report trusted observation status");
    expect_true(enabled_observation.reason == "trusted", "trusted metadata should expose trusted reason");

    auto enabled_selection = enabled_selector.select_external_front(front_context);
    expect_true(enabled_selection.mode == InboundMode::ExternalFront, "enabled external front mode should use external front selection");
    expect_true(enabled_selection.external_front_context.has_value(), "enabled external front mode should carry front metadata");

    boost::asio::io_context io_context;
    boost::asio::ssl::context ssl_context(boost::asio::ssl::context::tls_server);
    boost::asio::ssl::stream<tcp::socket> socket(io_context, ssl_context);

    auto decision = enabled_selector.evaluate(enabled_selection, loopback_endpoint(), socket, "not-a-trojan-request");
    expect_true(decision.path == SessionGate::Path::FALLBACK, "selector should route enabled external-front path into external-front inbound evaluation");
    expect_true(decision.target.host == "fallback.internal", "external-front selection should preserve fallback host");
    expect_true(decision.target.port == 8443, "external-front selection should still apply ALPN port override");
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
        test_config_external_front_metadata_provider_respects_enablement();
        test_trusted_internal_handoff_input_contract_rejects_incomplete_inputs_and_accepts_verified_input();
        test_external_front_handoff_builder_shapes_test_injected_and_trusted_internal_handoffs();
        test_external_front_handoff_contract_accepts_known_sources_and_rejects_unknown_or_missing_context();
        test_server_ingress_selector_routes_external_front_selection();

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
