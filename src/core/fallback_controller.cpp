#include "fallback_controller.h"

FallbackController::FallbackController(const Config::AbuseControlConfig &config, RuntimeMetrics &runtime_metrics)
    : config(config), runtime_metrics(runtime_metrics) {}

bool FallbackController::try_acquire_slot() {
    if (!config.enabled || config.fallback_max_active <= 0) {
        ++runtime_metrics.fallback_connections_total;
        ++runtime_metrics.active_fallback_sessions;
        return true;
    }
    auto current = runtime_metrics.active_fallback_sessions.load(std::memory_order_relaxed);
    while (current < static_cast<uint64_t>(config.fallback_max_active)) {
        if (runtime_metrics.active_fallback_sessions.compare_exchange_weak(current, current + 1, std::memory_order_relaxed)) {
            ++runtime_metrics.fallback_connections_total;
            return true;
        }
    }
    ++runtime_metrics.rejected_fallback_total;
    return false;
}

void FallbackController::release_slot() {
    auto active = runtime_metrics.active_fallback_sessions.load(std::memory_order_relaxed);
    while (active > 0 && !runtime_metrics.active_fallback_sessions.compare_exchange_weak(active, active - 1, std::memory_order_relaxed)) {
    }
}
