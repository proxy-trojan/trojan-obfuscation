#ifndef _SESSION_ADMISSION_RUNTIME_H_
#define _SESSION_ADMISSION_RUNTIME_H_

#include <functional>
#include <string>
#include <boost/asio/ip/tcp.hpp>
#include "session_gate.h"

class SessionAdmissionRuntime {
public:
    using RecordAuthSuccess = std::function<void()>;
    using RecordAuthFailure = std::function<void(const boost::asio::ip::tcp::endpoint&)>;
    using AcquireFallbackSlot = std::function<bool()>;

    SessionAdmissionRuntime(RecordAuthSuccess record_auth_success = {},
                            RecordAuthFailure record_auth_failure = {},
                            AcquireFallbackSlot acquire_fallback_slot = {});

    void apply_auth_result(const boost::asio::ip::tcp::endpoint &endpoint,
                           const SessionGate::SessionDecision &decision,
                           std::string &auth_password) const;

    bool try_acquire_fallback_slot(bool &fallback_slot_acquired) const;

private:
    RecordAuthSuccess record_auth_success;
    RecordAuthFailure record_auth_failure;
    AcquireFallbackSlot acquire_fallback_slot;
};

#endif // _SESSION_ADMISSION_RUNTIME_H_
