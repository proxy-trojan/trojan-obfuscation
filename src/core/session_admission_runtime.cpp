#include "session_admission_runtime.h"
#include "log.h"

using namespace std;
using namespace boost::asio::ip;

SessionAdmissionRuntime::SessionAdmissionRuntime(RecordAuthSuccess record_auth_success,
                                                 RecordAuthFailure record_auth_failure,
                                                 AcquireFallbackSlot acquire_fallback_slot)
    : record_auth_success(std::move(record_auth_success)),
      record_auth_failure(std::move(record_auth_failure)),
      acquire_fallback_slot(std::move(acquire_fallback_slot)) {}

void SessionAdmissionRuntime::apply_auth_result(const tcp::endpoint &endpoint,
                                                const SessionGate::SessionDecision &decision,
                                                string &auth_password) const {
    if (decision.valid_trojan_request && decision.authenticated) {
        if (decision.used_external_authenticator) {
            auth_password = decision.auth_record_password;
            if (record_auth_success) {
                record_auth_success();
            }
            Log::log_with_endpoint(endpoint, "authenticated by external authenticator", Log::INFO);
        } else {
            if (record_auth_success) {
                record_auth_success();
            }
            Log::log_with_endpoint(endpoint, "authenticated by configured credential", Log::INFO);
        }
        return;
    }

    if (decision.valid_trojan_request) {
        if (record_auth_failure) {
            record_auth_failure(endpoint);
        }
        Log::log_with_endpoint(endpoint, "valid trojan request structure but authentication failed", Log::WARN);
    }
}

bool SessionAdmissionRuntime::try_acquire_fallback_slot(bool &fallback_slot_acquired) const {
    if (!acquire_fallback_slot) {
        return true;
    }

    fallback_slot_acquired = acquire_fallback_slot();
    return fallback_slot_acquired;
}
