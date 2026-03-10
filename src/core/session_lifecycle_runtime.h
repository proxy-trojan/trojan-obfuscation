#ifndef _SESSION_LIFECYCLE_RUNTIME_H_
#define _SESSION_LIFECYCLE_RUNTIME_H_

#include <functional>
#include <string>
#include <boost/asio/ip/tcp.hpp>

class Authenticator;

class SessionLifecycleRuntime {
public:
    using ReleaseConnectionSlot = std::function<void(const boost::asio::ip::tcp::endpoint&)>;
    using ReleaseFallbackSlot = std::function<void()>;

    SessionLifecycleRuntime(ReleaseConnectionSlot release_connection_slot = {},
                            ReleaseFallbackSlot release_fallback_slot = {});

    void release_slots(const boost::asio::ip::tcp::endpoint &endpoint,
                       bool &connection_slot_acquired,
                       bool &fallback_slot_acquired) const;

    void record_usage(Authenticator *auth,
                      const std::string &auth_password,
                      uint64_t recv_len,
                      uint64_t sent_len) const;

private:
    ReleaseConnectionSlot release_connection_slot;
    ReleaseFallbackSlot release_fallback_slot;
};

#endif // _SESSION_LIFECYCLE_RUNTIME_H_
