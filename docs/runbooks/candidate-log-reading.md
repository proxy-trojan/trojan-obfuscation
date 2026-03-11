# Runbook: Candidate Log Reading

## Purpose

Help operators read baseline vs trusted-front candidate logs without over-interpreting them.

This runbook focuses on the current implementation and current stable log strings.

---

# 1. Read Order

When reviewing a candidate run, read logs in this order:

1. transport/admission result
2. trusted-front metadata trust result
3. ingress frame result
4. fallback/admission guardrail result
5. final runtime metrics summary

This order reduces confusion between:
- transport-level problems
- metadata trust problems
- parsing problems
- fallback/admission problems

---

# 2. Transport / Admission Layer

## Good sign
- `incoming trusted-front connection`

Meaning:
- the trusted-front listener accepted a connection

## Bad sign
- `trusted-front connection rejected: <reason>`

Meaning:
- the candidate path was blocked at trusted-front admission
- do **not** keep reading later candidate-path assumptions as if the handoff succeeded

### First question to ask
> Did the trusted-front connection reach the backend listener and survive admission?

If no, stop there and fix admission/trust-boundary assumptions first.

---

# 3. Metadata Trust Layer

## Good sign
- `external-front metadata accepted: trusted`

Meaning:
- the metadata passed current trust validation
- the system can shape downstream trusted context from it

## Bad sign
- `external-front metadata rejected: <reason>`

Common reasons:
- `missing_trusted_front_id`
- `missing_original_client_identity`
- `missing_verified_tls_termination`

### Interpretation rule
Metadata rejection means:
- external-front was observed
- but its trusted context was **not** accepted

That is not the same as:
- transport failure
- fallback failure
- baseline regression

Keep the diagnosis narrow.

---

# 4. Ingress Frame Layer

## Bad sign
- `trusted-front ingress rejected: <reason>`

Common reasons:
- `rejected_incomplete_trusted_front_ingress_frame`
- `rejected_invalid_trusted_front_ingress_length`
- `rejected_invalid_trusted_front_ingress_envelope`
- `rejected_missing_trusted_front_downstream_payload`

### Interpretation rule
If you see this line, the candidate transport arrived but the trusted-front frame did not parse or shape correctly.

This usually means one of:
- framing bug
- envelope generation mismatch
- payload omission
- sender/backend protocol mismatch

---

# 5. Fallback / Guardrail Layer

## Fallback capacity failure
- `fallback rejected: active fallback session budget exhausted`

Meaning:
- fallback was attempted
- safety budget denied it

## Public admission guardrail failures
- `connection rejected: IP is in authentication cooldown`
- `connection rejected: per-IP concurrent connection limit reached`

Meaning:
- the run may have been distorted by abuse-control behavior rather than candidate-path logic

### Interpretation rule
Do not blame candidate-path logic for failures clearly explained by fallback/admission guardrails.

---

# 6. Runtime Summary Layer

## Summary line
- `runtime metrics: accepted=...`

Use it to answer:
- was rejection volume unusual?
- did fallback rejection spike?
- was the run mostly healthy despite one localized candidate issue?

Do not use this line alone to claim candidate success.
It is a summary, not proof of public-edge improvement.

---

# 7. Quick Triage Patterns

## Pattern A — Admission blocked early
- `trusted-front connection rejected: ...`

Diagnosis bucket:
- trusted-front source / boundary / policy problem

## Pattern B — Candidate reached parsing but failed framing
- `incoming trusted-front connection`
- `trusted-front ingress rejected: ...`

Diagnosis bucket:
- sender/backend frame mismatch

## Pattern C — Metadata path exists but trust failed
- `external-front metadata rejected: ...`

Diagnosis bucket:
- metadata completeness / verification problem

## Pattern D — Candidate looks healthy enough for next comparison step
- `incoming trusted-front connection`
- `external-front metadata accepted: trusted`
- no immediate ingress rejection
- runtime metrics not obviously degraded

Diagnosis bucket:
- candidate path likely healthy enough for deeper comparison, but still not proof of first-tier status

---

# 8. What To Capture In Your Notes

For each serious candidate run, record:
- first trusted-front admission result
- first metadata trust result
- first ingress parse result
- first fallback/admission guardrail anomaly
- final runtime metrics line
- one blunt sentence about whether the run failed at transport, trust, framing, or comparison value

---

# 9. Final Rule

Never collapse these into one vague conclusion:
- trusted-front connection reached backend
- metadata was trusted
- frame parsed
- fallback behaved well
- candidate improved the public edge

Those are five different claims.
Treat them separately or the logs will lie to you.
