import importlib.util
import pathlib
import subprocess
import sys

_SCRIPT_PATH = (
    pathlib.Path(__file__).resolve().parents[1]
    / "perf"
    / "compute_daily_action_perf_baseline.py"
)
_SPEC = importlib.util.spec_from_file_location(
    "compute_daily_action_perf_baseline",
    _SCRIPT_PATH,
)
_MODULE = importlib.util.module_from_spec(_SPEC)
assert _SPEC and _SPEC.loader

# Mimic normal import semantics: insert into sys.modules before exec.
# This is required for dataclasses + postponed annotations, which rely on
# sys.modules[__module__] during class processing.
sys.modules[_SPEC.name] = _MODULE

_SPEC.loader.exec_module(_MODULE)

PerfBaseline = _MODULE.PerfBaseline
ThresholdPolicy = _MODULE.ThresholdPolicy
_load_baseline = _MODULE._load_baseline
_load_policy = _MODULE._load_policy
_baseline_medians = _MODULE._baseline_medians
_evaluate_regression = _MODULE.evaluate_regression

_FIXTURES = pathlib.Path(__file__).resolve().parent / "fixtures"


def test_fixture_loads_and_has_expected_schema():
    baseline = _load_baseline(_FIXTURES / "daily_action_perf_baseline_sample.json")
    assert baseline.schema_version == "1"
    assert baseline.profile == "baseline"
    assert len(baseline.samples) == 3

    medians = _baseline_medians(baseline)
    assert set(medians.keys()) == {"connect_ready_ms", "cpu_time_ms", "rss_kb"}


def test_regression_evaluation_passes_within_thresholds():
    baseline = _load_baseline(_FIXTURES / "daily_action_perf_baseline_sample.json")
    candidate = _load_baseline(_FIXTURES / "daily_action_perf_baseline_candidate_ok.json")
    policy = _load_policy(_FIXTURES / "daily_action_perf_threshold_policy.json")

    findings = _evaluate_regression(baseline=baseline, candidate=candidate, policy=policy)
    assert findings
    assert all(f.status == "pass" for f in findings)


def test_regression_evaluation_fails_when_over_threshold():
    baseline = _load_baseline(_FIXTURES / "daily_action_perf_baseline_sample.json")
    candidate = _load_baseline(_FIXTURES / "daily_action_perf_baseline_candidate_bad.json")
    policy = _load_policy(_FIXTURES / "daily_action_perf_threshold_policy.json")

    findings = _evaluate_regression(baseline=baseline, candidate=candidate, policy=policy)
    assert any(f.status == "fail" for f in findings)


def test_cli_evaluate_returns_nonzero_on_failure(tmp_path):
    out_path = tmp_path / "eval.json"
    cmd = [
        sys.executable,
        str(_SCRIPT_PATH),
        "evaluate",
        "--baseline",
        str(_FIXTURES / "daily_action_perf_baseline_sample.json"),
        "--candidate",
        str(_FIXTURES / "daily_action_perf_baseline_candidate_bad.json"),
        "--policy",
        str(_FIXTURES / "daily_action_perf_threshold_policy.json"),
        "--output",
        str(out_path),
    ]
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
    assert proc.returncode == 2
    assert out_path.exists()
