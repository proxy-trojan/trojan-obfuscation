#include "abuse_controller.h"
#include "log.h"

using std::string;
using namespace boost::asio::ip;

AbuseController::AbuseController(const Config::AbuseControlConfig &config) : config(config) {}

bool AbuseController::try_acquire_connection_slot(const tcp::endpoint &endpoint) {
    if (!config.enabled || config.per_ip_max_connections <= 0) {
        return true;
    }
    const string ip = endpoint.address().to_string();
    std::lock_guard<std::mutex> lock(mutex);
    auto &stats = per_ip[ip];
    if (stats.active_connections >= static_cast<size_t>(config.per_ip_max_connections)) {
        return false;
    }
    ++stats.active_connections;
    return true;
}

void AbuseController::release_connection_slot(const tcp::endpoint &endpoint) {
    if (!config.enabled || config.per_ip_max_connections <= 0) {
        return;
    }
    const string ip = endpoint.address().to_string();
    std::lock_guard<std::mutex> lock(mutex);
    auto it = per_ip.find(ip);
    if (it == per_ip.end()) {
        return;
    }
    if (it->second.active_connections > 0) {
        --it->second.active_connections;
    }
    if (it->second.active_connections == 0 &&
        it->second.auth_fail_count == 0 &&
        it->second.cooldown_until <= std::chrono::steady_clock::now()) {
        per_ip.erase(it);
    }
}

bool AbuseController::is_ip_in_cooldown(const tcp::endpoint &endpoint) const {
    if (!config.enabled || config.auth_fail_max <= 0 || config.cooldown_seconds <= 0) {
        return false;
    }
    const string ip = endpoint.address().to_string();
    std::scoped_lock lock(mutex);
    auto it = per_ip.find(ip);
    if (it == per_ip.end()) {
        return false;
    }
    return it->second.cooldown_until > std::chrono::steady_clock::now();
}

void AbuseController::record_auth_failure(const tcp::endpoint &endpoint) {
    if (!config.enabled || config.auth_fail_max <= 0 || config.auth_fail_window_seconds <= 0) {
        return;
    }
    const auto now = std::chrono::steady_clock::now();
    const string ip = endpoint.address().to_string();
    std::lock_guard<std::mutex> lock(mutex);
    auto &stats = per_ip[ip];
    if (stats.auth_fail_window_start.time_since_epoch().count() == 0 ||
        now - stats.auth_fail_window_start > std::chrono::seconds(config.auth_fail_window_seconds)) {
        stats.auth_fail_window_start = now;
        stats.auth_fail_count = 1;
    } else {
        ++stats.auth_fail_count;
    }
    if (stats.auth_fail_count >= static_cast<size_t>(config.auth_fail_max)) {
        stats.cooldown_until = now + std::chrono::seconds(config.cooldown_seconds);
        stats.auth_fail_count = 0;
        stats.auth_fail_window_start = now;
        Log::log_with_endpoint(endpoint, "authentication failure threshold reached; entering cooldown", Log::WARN);
    }
}
