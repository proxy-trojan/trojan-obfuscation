#ifndef _RUNTIME_METRICS_H_
#define _RUNTIME_METRICS_H_

#include <atomic>
#include <cstdint>
#include <string>

class RuntimeMetrics {
public:
    std::atomic<uint64_t> accepted_connections_total{0};
    std::atomic<uint64_t> rejected_connections_total{0};
    std::atomic<uint64_t> rejected_fallback_total{0};
    std::atomic<uint64_t> auth_success_total{0};
    std::atomic<uint64_t> auth_failure_total{0};
    std::atomic<uint64_t> fallback_connections_total{0};
    std::atomic<uint64_t> active_sessions{0};
    std::atomic<uint64_t> active_fallback_sessions{0};

    std::string summary() const;
};

#endif // _RUNTIME_METRICS_H_
