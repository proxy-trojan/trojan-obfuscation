#ifndef _FALLBACK_CONTROLLER_H_
#define _FALLBACK_CONTROLLER_H_

#include "config.h"
#include "runtime_metrics.h"

class FallbackController {
public:
    FallbackController(const Config::AbuseControlConfig &config, RuntimeMetrics &runtime_metrics);

    bool try_acquire_slot();
    void release_slot();

private:
    const Config::AbuseControlConfig &config;
    RuntimeMetrics &runtime_metrics;
};

#endif // _FALLBACK_CONTROLLER_H_
