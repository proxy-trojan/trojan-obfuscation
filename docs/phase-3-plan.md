# Phase 3 Plan

## Purpose

Phase 2 finished the structural refactor needed to stop `ServerSession` from being a monolithic orchestration blob.

Phase 3 should build on that foundation by improving runtime clarity, testability, and future extensibility without destabilizing the current Trojan/TLS baseline.

## Baseline

Current working baseline:

- branch: `feature_1.0_no_obfus_and_no_rules`
- Phase 2 wrap-up: `docs/phase-2-wrap-up.md`
- Phase 2B architecture: `docs/phase-2b-architecture.md`

## Guiding Principles

1. preserve current runtime behavior
2. keep smoke/integration coverage green at every step
3. prefer concrete seams over speculative interface hierarchies
4. avoid reopening large monolithic files unless a new seam is being created
5. defer QUIC/ECH-specific work until runtime and service boundaries are cleaner

## Phase 3 Goals

### Functional goals
- preserve current server/client behavior
- preserve abuse-control behavior
- preserve fallback behavior
- preserve release/build/test reliability

### Architectural goals
- further reduce runtime density inside `ServerSession`
- improve seam-level testability
- reduce construction and policy glue inside `Service`
- prepare a cleaner decision point for future ingress experiments

### Non-goals
- no immediate QUIC implementation
- no immediate ECH implementation
- no full transport-adapter framework rollout
- no multi-process redesign
- no large protocol changes

---

# Phase 3A — Runtime Cleanup

## Objective

Continue shrinking the remaining runtime-heavy parts of `ServerSession`, with priority on the UDP path and seam-level testability.

## Why this comes first

Phase 2 already gave the TCP/session-admission path explicit seams:
- `EmbeddedTlsInbound`
- `RelayExecutor`
- `RelayExecutionPlan`
- `SessionAdmissionRuntime`
- `SessionLifecycleRuntime`

The most obvious remaining density is now in:
- UDP runtime flow
- UDP resolve/open/send orchestration
- a small amount of remaining handshake/runtime glue

## Recommended work order

### 3A.1 UDP runtime cleanup
Target areas:
- `ServerSession::udp_sent()`
- UDP target resolve path
- UDP socket open/bind path
- UDP send dispatch path

Deliverables:
- smaller, named helper steps around UDP dispatch
- less inline orchestration inside `udp_sent()`
- no behavior changes

### 3A.2 Seam-level testing
Add focused tests for:
- `RelayExecutor`
- `SessionAdmissionRuntime`
- `SessionLifecycleRuntime`
- execution-plan generation
- selected UDP runtime behavior where practical

Deliverables:
- at least one new seam-level test entrypoint or targeted test harness
- reduced reliance on smoke tests alone for regression confidence

### 3A.3 Runtime-host boundary review
After 3A.1 and 3A.2, review whether `ServerSession` can now be considered primarily a runtime host rather than an orchestration center.

Decision question:
- stop Phase 3A once the UDP path is acceptably clean,
- or perform one more narrow cleanup pass if a single remaining hotspot stands out.

## Current Phase 3A Progress Snapshot

Status: **in progress, but materially advanced**.

### Completed so far

#### UDP/runtime cleanup
The server-side UDP path is now split into smaller staged helpers instead of one inline block:
- `try_parse_udp_packet(...)`
- `resolve_udp_target(...)`
- `evaluate_udp_resolve_result(...)`
- `choose_udp_target_endpoint(...)`
- `dispatch_udp_payload(...)`
- `ensure_udp_socket_open(...)`

This means the UDP flow is now much closer to:
- parse
- decide
- resolve
- decide
- select endpoint
- dispatch payload

rather than a single inline orchestration block in `udp_sent()`.

#### Seam-level testing
A dedicated seam-test executable now exists:
- `runtime_seam_tests`
- registered as `RuntimeSeamTests` in CTest

The following seams now have direct coverage:
- `SessionAdmissionRuntime`
  - auth success / failure behavior
  - fallback slot allow / deny / no-callback behavior
- `SessionLifecycleRuntime`
  - slot release behavior
  - acquired-flag guarding behavior
- `RelayExecutor`
  - authenticated TCP execution plan
  - authenticated UDP execution plan
  - fallback execution plan
  - fallback fast-fail path in `begin_tcp_relay(...)`

### Current assessment

Phase 3A has already achieved two meaningful outcomes:
1. UDP runtime orchestration is materially clearer than the Phase 2 baseline.
2. Core runtime seams are no longer protected only by smoke tests.

### Likely remaining work

The remaining decisions are now more about *where to stop cleanly* than about missing a critical structural seam.

Reasonable next options:
- perform one more narrow UDP cleanup pass if a single remaining hotspot still stands out
- stop Phase 3A after a brief review and move to Phase 3B
- optionally add one more focused seam test only if it provides clear regression value

## Done criteria for Phase 3A

Phase 3A is done when:
- UDP runtime flow is materially clearer than the Phase 2 baseline
- build/test flow remains green
- `ServerSession` no longer contains a dense UDP orchestration block comparable to the old TCP path
- at least some seam-level tests exist beyond the current smoke suite

### Done-criteria status check

Current status against those criteria:
- ✅ UDP runtime flow is materially clearer than the Phase 2 baseline
- ✅ build/test flow remains green
- ✅ `ServerSession` no longer contains the old dense UDP orchestration shape
- ✅ seam-level tests now exist beyond the smoke suite

This means **Phase 3A is already close to a reasonable stopping point**, even if one additional narrow refinement may still be desirable.

---

# Phase 3B — Service Cleanup

## Objective

Reduce orchestration glue inside `Service`, especially around accept-path policy handling and session construction.

## Candidate seams

### 3B.1 Session construction seam
Potential extraction:
- `SessionFactory`
- or `ServerSessionFactory`

Responsibility:
- centralize session construction
- centralize callback wiring
- remove duplicated setup between single-worker and multi-worker accept paths

### 3B.2 Accept policy seam
Potential extraction:
- `AcceptGate`
- or `ConnectionAdmissionGate`

Responsibility:
- cooldown checks
- per-IP concurrency gating
- metrics/logging for accepted vs rejected connections

### 3B.3 Accept-path deduplication
Target:
- reduce duplicated accept-complete logic between `async_accept()` and `async_accept_worker()`

## Current Phase 3B Progress Snapshot

Status: **first-round cleanup completed; ready for evaluation**.

### Completed so far

#### 3B.1 Session construction seam
`Service` now creates sessions through internal helpers instead of duplicating construction logic in both accept paths:
- `create_server_session(...)`
- `create_session(...)`

This centralizes:
- `ServerSession` callback wiring
- per-run-type session construction
- single-worker and multi-worker accept-path setup behavior

Representative commit:
- `4f57031` — `refactor: extract service session construction helper`

#### 3B.2 Accept policy seam
`Service` now makes incoming-connection decisions through an explicit decision helper:
- `AcceptDecision`
- `evaluate_incoming_connection(...)`

This makes cooldown-vs-connection-limit-vs-accept policy decisions explicit before execution.

Representative commit:
- `ca4794f` — `refactor: make service accept decisions explicit`

#### 3B.3 Accept completion seam
The duplicated accept callback bodies are now merged into:
- `handle_accept_completion(...)`

This leaves `async_accept()` and `async_accept_worker()` closer to thin accept-loop shells.

Representative commit:
- `cb302e7` — `refactor: deduplicate service accept completion flow`

### Current assessment

Phase 3B has already achieved the first useful level of `Service` cleanup:
1. session construction is no longer duplicated inline across accept paths
2. accept policy is no longer expressed only as callback-local branching
3. accept completion flow is now centralized instead of duplicated

### Evaluation: stop here or continue?

At this point, the remaining question is whether to promote the new seams into standalone modules such as:
- `SessionFactory`
- `AcceptGate`

Current recommendation: **not yet**.

Why:
- the current seams are already explicit and useful
- `Service` has become materially thinner without introducing new files or speculative abstractions
- the marginal benefit of immediate module extraction is now lower than in the first three cleanup steps

Reasonable next options:
- stop Phase 3B here and document it as the first completed cleanup round
- continue only if `Service` still feels too dense after a fresh review
- promote helpers into standalone modules only when a second real use case appears or the class remains meaningfully oversized

## Done criteria for Phase 3B

Phase 3B is done when:
- `Service` is materially thinner
- session construction is not wired inline in multiple accept paths
- accept policy logic is clearer and less duplicated

### Done-criteria status check

Current status against those criteria:
- ✅ `Service` is materially thinner than the Phase 3A baseline
- ✅ session construction is no longer wired inline in both accept paths
- ✅ accept policy logic is now clearer and less duplicated

This means **Phase 3B first-round cleanup is already at a reasonable stopping point** unless a fresh review reveals a clearly remaining hotspot.

---

# Phase 3C — Future-Facing Direction Selection

## Objective

Choose a realistic next frontier without destabilizing the stable baseline.

## Candidate directions

### Option A — Continue runtime stabilization
Best when:
- baseline stability remains the top priority
- future ingress work is not yet urgent

### Option B — Service-layer cleanup first
Best when:
- `Service` becomes the next clear structural bottleneck
- code health remains the main focus

### Option C — Future ingress preparation
Best when:
- the project is ready to explore external edge modes
- a clear experiment target exists

Candidate experiment themes:
- external front / ECH-ready edge preparation
- QUIC ingress preparation
- web-native front experimentation

## Phase 3C output should be
- an ADR or equivalent design note
- one explicitly chosen direction
- a short list of deferred alternatives

Current decision draft:
- `docs/phase-3c-direction.md`

---

# Risks

## Risk 1 — Endless refactor drift
Mitigation:
- treat each sub-phase as complete once its done criteria are met
- avoid continuing only because more cleanup is always possible

## Risk 2 — Premature abstraction
Mitigation:
- do not introduce interface hierarchies without a second real implementation
- prefer concrete runtime helpers first

## Risk 3 — Test debt lagging behind structure
Mitigation:
- require test additions during Phase 3A, not after all refactors are complete

---

# Recommended Sequence

Recommended order:

1. Phase 3A — UDP/runtime cleanup + seam-level tests
2. Phase 3B — `Service` cleanup
3. Phase 3C — choose the next future-facing experiment direction

## Immediate next step

Phase 3A has already started successfully and no longer needs a blind “keep refactoring” default.

### Recommended next decision
Choose one of the following explicitly:

1. **Stop Phase 3A soon and move to Phase 3B**
   - if the current UDP/runtime shape is considered sufficiently clear
   - if preserving momentum and avoiding refactor drift is the priority

2. **Do one final narrow Phase 3A pass**
   - only if a single remaining UDP/runtime hotspot still stands out
   - keep the scope small and behavior-preserving

3. **Add one more seam-level test only when it closes a real gap**
   - do not expand the test suite mechanically without clear signal

Current recommendation: **treat Phase 3A as near-complete, and make the next step an explicit decision rather than an automatic continuation.**

### Documentation note for current Phase 3B status
As of the current cleanup round, `Service` helper-level seams are considered sufficient. Do **not** automatically promote them into standalone `SessionFactory` / `AcceptGate` modules unless a new round of review shows clear remaining density or a second real reuse case.
