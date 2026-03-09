#ifndef _ABUSE_CONTROLLER_H_
#define _ABUSE_CONTROLLER_H_

#include <chrono>
#include <mutex>
#include <string>
#include <unordered_map>
#include <boost/asio/ip/tcp.hpp>
#include "config.h"

class AbuseController {
public:
    explicit AbuseController(const Config::AbuseControlConfig &config);

    bool try_acquire_connection_slot(const boost::asio::ip::tcp::endpoint &endpoint);
    void release_connection_slot(const boost::asio::ip::tcp::endpoint &endpoint);
    bool is_ip_in_cooldown(const boost::asio::ip::tcp::endpoint &endpoint) const;
    void record_auth_failure(const boost::asio::ip::tcp::endpoint &endpoint);

private:
    struct IpAbuseStats {
        size_t active_connections{0};
        size_t auth_fail_count{0};
        std::chrono::steady_clock::time_point auth_fail_window_start{};
        std::chrono::steady_clock::time_point cooldown_until{};
    };

    Config::AbuseControlConfig config;
    mutable std::mutex mutex;
    std::unordered_map<std::string, IpAbuseStats> per_ip;
};

#endif // _ABUSE_CONTROLLER_H_
