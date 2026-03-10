#include "session_lifecycle_runtime.h"
#include "authenticator.h"

using namespace std;
using namespace boost::asio::ip;

SessionLifecycleRuntime::SessionLifecycleRuntime(ReleaseConnectionSlot release_connection_slot,
                                                 ReleaseFallbackSlot release_fallback_slot)
    : release_connection_slot(std::move(release_connection_slot)),
      release_fallback_slot(std::move(release_fallback_slot)) {}

void SessionLifecycleRuntime::release_slots(const tcp::endpoint &endpoint,
                                            bool &connection_slot_acquired,
                                            bool &fallback_slot_acquired) const {
    if (connection_slot_acquired && release_connection_slot) {
        release_connection_slot(endpoint);
        connection_slot_acquired = false;
    }
    if (fallback_slot_acquired && release_fallback_slot) {
        release_fallback_slot();
        fallback_slot_acquired = false;
    }
}

void SessionLifecycleRuntime::record_usage(Authenticator *auth,
                                           const string &auth_password,
                                           uint64_t recv_len,
                                           uint64_t sent_len) const {
    if (auth && !auth_password.empty()) {
        auth->record(auth_password, recv_len, sent_len);
    }
}
