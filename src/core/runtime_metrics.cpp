#include "runtime_metrics.h"
#include <string>

using namespace std;

string RuntimeMetrics::summary() const {
    return "runtime metrics: accepted=" + to_string(accepted_connections_total.load()) +
           ", rejected=" + to_string(rejected_connections_total.load()) +
           ", rejected_fallback=" + to_string(rejected_fallback_total.load()) +
           ", auth_success=" + to_string(auth_success_total.load()) +
           ", auth_failure=" + to_string(auth_failure_total.load()) +
           ", fallback=" + to_string(fallback_connections_total.load()) +
           ", active=" + to_string(active_sessions.load()) +
           ", active_fallback=" + to_string(active_fallback_sessions.load());
}
