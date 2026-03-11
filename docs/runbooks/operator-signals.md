# Runbook: Operator Signals

## Purpose

Define the minimum operator-visible signals for Phase 4 baseline and trusted-front candidate work.

This runbook is intentionally grounded in the current implementation.
It documents signals that already exist in logs or runtime summaries so operators can reason about the system without guessing.

## Core Rule

A useful signal must help answer at least one of these quickly:

- did the baseline path run?
- was trusted-front attempted?
- was trusted-front accepted or rejected?
- did fallback happen?
- did admission/rate-limit controls reject the connection?

If a run cannot answer those, observability is not good enough yet.

---

# 1. Baseline / Candidate Path Signals

## Embedded-TLS default path
Current stable observation label:
- `embedded_tls_default`

This is the default meaning when no trusted external-front path is selected.

## Trusted-front metadata accepted
Current log:
- `external-front metadata accepted: trusted`

Meaning:
- trusted-front metadata was present
- validation passed
- the external-front path was selected rather than the embedded-TLS default path

## Trusted-front metadata rejected
Current log:
- `external-front metadata rejected: <reason>`

Current stable reason strings include:
- `missing_trusted_front_id`
- `missing_original_client_identity`
- `missing_verified_tls_termination`

Meaning:
- trusted-front metadata was present
- validation failed
- trusted fields should not be applied
- the system should fall back to the conservative/default path behavior

---

# 2. Trusted-Front Transport / Admission Signals

## Trusted-front connection accepted into the listener
Current log:
- `incoming trusted-front connection`

Meaning:
- the trusted-front listener accepted a connection
- this does **not** by itself prove metadata trust or successful downstream handoff

## Trusted-front source rejected before deeper handling
Current log:
- `trusted-front connection rejected: <reason>`

Current known reason example:
- `rejected_non_loopback_trusted_front_source`

Meaning:
- the trusted-front transport connection reached the listener
- admission policy rejected the peer before candidate-path handling continued

## Trusted-front ingress frame rejected
Current log:
- `trusted-front ingress rejected: <reason>`

Current stable reason strings include:
- `rejected_incomplete_trusted_front_ingress_frame`
- `rejected_invalid_trusted_front_ingress_length`
- `rejected_invalid_trusted_front_ingress_envelope`
- `rejected_missing_trusted_front_downstream_payload`

Meaning:
- transport arrived
- framing/envelope/payload parse or shape failed
- this is a transport/protocol-level failure, not a baseline ingress success

---

# 3. Baseline Admission / Safety Signals

## Cooldown rejection
Current log:
- `connection rejected: IP is in authentication cooldown`

Meaning:
- abuse-control cooldown rejected the connection early

## Per-IP concurrent connection rejection
Current log:
- `connection rejected: per-IP concurrent connection limit reached`

Meaning:
- admission was rejected by the concurrent-connection guardrail

## Fallback budget rejection
Current log:
- `fallback rejected: active fallback session budget exhausted`

Meaning:
- fallback path wanted to start
- fallback concurrency budget denied it

---

# 4. Runtime Summary Signal

## Runtime metrics line
Current summary prefix:
- `runtime metrics: accepted=`

This final line is useful for fast post-run triage.
It summarizes:
- accepted connections
- rejected connections
- rejected fallback count
- auth success/failure counts
- fallback counts
- active session counts

Use this to answer:
- was the run mostly healthy?
- did rejection volume spike?
- did fallback usage or fallback rejection spike?

---

# 5. Minimum Interpretation Matrix

## A. Trusted-front candidate worked enough to continue investigation
Typical signal pattern:
- `incoming trusted-front connection`
- `external-front metadata accepted: trusted`
- no immediate trusted-front ingress rejection

## B. Trusted-front transport reached the backend but policy blocked it
Typical signal pattern:
- `trusted-front connection rejected: <reason>`

Interpretation:
- peer/admission trust failed before candidate path could be exercised normally

## C. Trusted-front transport reached the backend but frame parsing failed
Typical signal pattern:
- `incoming trusted-front connection`
- `trusted-front ingress rejected: <reason>`

Interpretation:
- transport path exists
- envelope/payload framing is broken or incomplete

## D. Metadata arrived but was not trusted
Typical signal pattern:
- `external-front metadata rejected: <reason>`

Interpretation:
- candidate metadata path exists
- trust policy blocked trusted field shaping
- compare this carefully against expected source assumptions

## E. Baseline path is still dominating
Typical signal pattern:
- no trusted-front acceptance log
- baseline behavior still visible
- runtime summary remains healthy

Interpretation:
- candidate may still be inactive, rejected, or simply not selected

---

# 6. What Operators Should Record In Notes

For each serious run, record at minimum:
- whether trusted-front was attempted
- whether trusted-front was accepted or rejected
- the first stable rejection reason seen
- whether fallback occurred
- the final runtime metrics line

If you cannot fill these in, add that missing signal to the backlog.

---

# 7. Final Guidance

Do not treat "listener accepted a connection" as equivalent to:
- trusted metadata accepted
- candidate path succeeded
- public-edge improvement proven

Those are different levels.
The logs are only useful if operators keep those layers separate.
