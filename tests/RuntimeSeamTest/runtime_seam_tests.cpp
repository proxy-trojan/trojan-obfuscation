#include <exception>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <boost/asio/ip/address.hpp>
#include <boost/asio/ip/tcp.hpp>
#include "core/log.h"
#include "core/session_admission_runtime.h"
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

} // namespace

int main() {
    try {
        Log::redirect("/dev/null");
        Log::set_callback({});

        test_admission_runtime_external_auth_records_password();
        test_admission_runtime_configured_credential_does_not_store_password();
        test_admission_runtime_auth_failure_records_failure_only();
        test_admission_runtime_fallback_slot_paths();

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
