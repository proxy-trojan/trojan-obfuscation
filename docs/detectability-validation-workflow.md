# Detectability Validation Workflow

## Status

Draft

## Purpose

Define a repeatable workflow for evaluating whether a deployment shape is becoming harder or easier to identify.

This workflow is designed for Phase 4.
It is intentionally:
- practical rather than academically complete
- deployment-aware rather than protocol-only
- useful before full automation exists

## Non-Goals

This workflow does **not** attempt to prove that a system is:
- invisible
- undetectable
- safe in every censorship environment

It only aims to support better decisions by answering:
- what public signals are exposed now?
- which signals changed after a deployment or code change?
- did the change improve, preserve, or weaken the practical posture?

## Core Principle

A detectability claim is only credible if it can be checked from at least three angles:
1. **passive observation**
2. **active probing**
3. **fallback / public-surface behavior**

If a change improves only one angle while worsening the others, it should not automatically be considered an improvement.

---

# 1. Validation Targets

Every validation run should name the target deployment shape being evaluated.

Minimum target set:
1. **Current baseline** — embedded TLS + fallback
2. **Candidate stronger posture** — trusted external front + backend handoff
3. **Reference mainstream baseline** — a simple Trojan/TLS deployment for comparison

Optional targets:
- NaiveProxy-style reference deployment
- REALITY-style reference deployment
- QUIC-first reference deployment

## Rule
Do not compare abstract protocols only.
Compare **deployment shapes**.

---

# 2. Validation Dimensions

## A. Passive observation
Question:
- what does the public-facing connection look like without interacting deeply?

Examples of evidence:
- TLS version/cipher behavior
- ALPN behavior
- SNI-related posture
- certificate / front-door realism
- whether the exposed surface looks like a believable ordinary service

## B. Active probing
Question:
- what happens when a scanner or adversary intentionally sends malformed, partial, unexpected, or non-protocol traffic?

Examples of evidence:
- handshake failures
- protocol mis-match behavior
- abnormal timing
- fallback inconsistency
- overly distinct rejection signatures

## C. Public-surface realism
Question:
- if the service is visited like a normal public web-facing endpoint, does it look believable?

Examples of evidence:
- plain HTTP behavior
- fallback backend realism
- consistency across expected and unexpected requests
- whether the public-facing response reveals proxy-like traits too quickly

## D. Operational consistency
Question:
- does the deployment preserve the same behavior across nodes, restarts, and rollback states?

Examples of evidence:
- config drift between nodes
- rollout side effects
- rollback leaving traces of the “new” path enabled

---

# 3. Run Types

## Run Type 1 — Baseline snapshot
Use when:
- starting a new validation cycle
- before a major deployment change
- before comparing against another solution

Output:
- a snapshot of the current signals and posture

## Run Type 2 — Before/after diff
Use when:
- a code change or deployment change claims to improve camouflage

Output:
- what signals changed
- whether the change is net-positive, net-neutral, or net-negative

## Run Type 3 — Reference comparison
Use when:
- comparing the project against another mainstream deployment class

Output:
- relative ranking and likely trade-offs

---

# 4. Workflow Steps

## Step 1 — Define the deployment shape
Record:
- target name
- topology summary
- whether it is baseline or candidate
- whether a front layer exists
- rollback path

Template:
```markdown
### Target
- Name:
- Shape:
- Public entry:
- Backend entry:
- Fallback behavior:
- Rollback method:
```

## Step 2 — Capture passive observation
Collect a small, repeatable passive snapshot.

Check at least:
- public TLS surface
- ALPN behavior
- public-facing certificate / hostname realism
- whether the service surface looks like a direct backend or a believable front

Record:
- expected behavior
- observed behavior
- suspicious differences

## Step 3 — Run active probing scenarios
Use a fixed set of probe categories.

Minimum categories:
1. non-protocol connection
2. partial handshake / malformed input
3. HTTP-like request to non-HTTP path
4. incorrect Trojan-like attempt
5. fallback-triggering request

Record for each:
- response class
- timing notes
- whether behavior is distinctive or believable

## Step 4 — Inspect fallback / public behavior
Check whether the public-facing response looks coherent.

Questions:
- does fallback look like a real backend or a generic placeholder?
- does plain HTTP behavior leak proxy identity?
- do invalid paths and valid paths differ in suspicious ways?

## Step 5 — Review operator signals
Check what operators can see.

Minimum required signals:
- which ingress path was selected
- rejection reason if a path was rejected
- whether fallback was used
- whether rollback cleanly restored baseline path selection

## Step 6 — Rate the result
Use one of these outcomes:
- **Improved**
- **No meaningful change**
- **Mixed / uncertain**
- **Worse**

The rating must include a short reason.

---

# 5. Minimum Evidence To Record

Every validation run should produce:
- target deployment description
- passive observation notes
- active probing notes
- fallback/public-surface notes
- operator-observability notes
- final rating
- recommended next action

## Minimal report template
```markdown
# Detectability Validation Report

## Target
- Name:
- Shape:
- Date:

## Passive Observation
- Summary:
- Suspicious signals:

## Active Probing
- Probe classes run:
- Distinctive responses:

## Public-Surface Realism
- Fallback quality:
- Plain HTTP quality:

## Operator Signals
- Available signals:
- Missing signals:

## Verdict
- Rating:
- Why:
- Recommended next action:
```

---

# 6. Red Flags

The following should be treated as high-signal problems:
- the public-facing surface obviously looks like a direct backend proxy endpoint
- malformed traffic produces highly distinctive rejection behavior
- fallback looks synthetic or too shallow
- deployment claims stronger camouflage without changing the public-edge posture
- rollback does not restore the original surface cleanly
- operators cannot distinguish trusted path, rejected path, and fallback path

---

# 7. Acceptance Gates For Stronger Claims

A deployment or change should **not** be described as “stronger” unless all of the following are true:

1. passive observation is not worse
2. active probing does not reveal a more distinctive response signature
3. public-surface realism is at least preserved
4. operator visibility is sufficient to explain accepted/rejected behavior
5. rollback remains simple enough to use under pressure

If any of these fail, the change should be treated as:
- unproven
- mixed
- or operationally unsafe

---

# 8. Recommended Phase 4 Usage

## First use
Run this workflow first against:
1. the current embedded TLS + fallback baseline
2. one reference mainstream Trojan/TLS deployment

This establishes a sanity baseline.

## Second use
Run it against any staging trusted-front candidate **before** real-source rollout work is accepted as mainline.

## Third use
Use it to compare whether trusted-front work is actually improving the public-edge posture enough to justify added operational cost.

---

# 9. Final Recommendation

Treat detectability validation as a deployment workflow, not as a code-only judgment.

The project should not ask only:
- “did the code become more advanced?”

It should ask:
- “did the public-facing shape become harder to model?”
- “can operators still explain what happened?”
- “can we roll it back safely?”

That is the standard this workflow is meant to enforce.
