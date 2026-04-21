import importlib.util
import pathlib

_SCRIPT_PATH = (
    pathlib.Path(__file__).resolve().parents[1]
    / "ux"
    / "compute_ux_metrics_snapshot.py"
)
_SPEC = importlib.util.spec_from_file_location(
    "compute_ux_metrics_snapshot",
    _SCRIPT_PATH,
)
_MODULE = importlib.util.module_from_spec(_SPEC)
assert _SPEC and _SPEC.loader
_SPEC.loader.exec_module(_MODULE)
compute_snapshot = _MODULE.compute_snapshot


def test_snapshot_contains_required_sections():
    result = compute_snapshot(events=[])
    assert "fcsr" in result
    assert "hfe" in result
    assert "guardrails" in result


def test_snapshot_fcsr_counts_runtime_true_only():
    events = [
        {"userId": "u1", "name": "first_session_started", "at": "2026-04-17T10:00:00Z"},
        {"userId": "u1", "name": "runtime_session_ready_runtime_true", "at": "2026-04-17T10:03:00Z"},
        {"userId": "u2", "name": "first_session_started", "at": "2026-04-17T10:00:00Z"},
        {"userId": "u2", "name": "runtime_session_ready_fallback", "at": "2026-04-17T10:03:00Z"},
    ]

    result = compute_snapshot(events=events)
    assert result["fcsr"]["numerator"] == 1
    assert result["fcsr"]["denominator"] == 2
    assert result["fcsr"]["value"] == 0.5


def test_snapshot_recovery_outcome_and_acted_closure():
    events = [
        {
            "userId": "u1",
            "sessionId": "s1",
            "name": "recovery_suggested",
            "at": "2026-04-21T00:00:00Z",
        },
        {
            "userId": "u1",
            "sessionId": "s1",
            "name": "recovery_action_executed",
            "at": "2026-04-21T00:00:05Z",
            "fields": {
                "action": "open_profiles",
                "source": "readiness_recommendation",
                "failureFamily": "connect",
                "runtimePosture": "runtime_true",
            },
        },
        {
            "userId": "u1",
            "sessionId": "s1",
            "name": "recovery_outcome",
            "at": "2026-04-21T00:01:00Z",
            "fields": {
                "action": "open_profiles",
                "source": "readiness_recommendation",
                "failureFamily": "connect",
                "runtimePosture": "runtime_true",
                "outcome": "success",
            },
        },
    ]

    result = compute_snapshot(events=events)
    assert result["guardrails"]["ssr"] == 1.0
    assert result["guardrails"]["recovery_acted_rate"] == 1.0
    assert result["guardrails"]["recovery_outcome"]["success"] == 1
    assert result["guardrails"]["recovery_outcome"]["fail"] == 0
    assert result["guardrails"]["recovery_outcome"]["abandon"] == 0
