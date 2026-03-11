# Baseline vs Trusted-Front Verdict Template

## Status

Template

## Purpose

Provide a strict, repeatable verdict template for comparing:

- the current embedded-TLS baseline
- a trusted-front candidate run

Use this after a serious validation run so the result does not degrade into hand-wavy prose.

---

# 1. Run Identity

- **Date:**
- **Reviewer:**
- **Operator owner:**
- **Scope:**
- **Candidate shape:**
- **Baseline evidence path:**
- **Candidate evidence path:**
- **Comparison artifact path:**

---

# 2. Input Completeness Check

## Baseline inputs present
- [ ] baseline `summary.json`
- [ ] baseline `config.snapshot.json`
- [ ] baseline `profile-mode.json`
- [ ] baseline report / notes

## Candidate inputs present
- [ ] candidate `summary.json`
- [ ] candidate `config.snapshot.json`
- [ ] candidate `profile-mode.json`
- [ ] candidate report / notes

## Comparison readiness
- [ ] baseline mode is explicitly `baseline`
- [ ] candidate mode is explicitly `candidate`
- [ ] timestamps / artifact paths are coherent
- [ ] evidence is sufficient to support judgment

If any critical box is unchecked, stop and classify the run as **Not ready**.

---

# 3. Baseline vs Candidate Judgment

## A. Passive public observation
### Baseline
- What was visible publicly?

### Candidate
- What was visible publicly?

### Verdict
- [ ] Better
- [ ] Same
- [ ] Worse

### Why

---

## B. Active probing behavior
### Baseline
- Key probing observations:

### Candidate
- Key probing observations:

### Verdict
- [ ] Better
- [ ] Same
- [ ] Worse

### Why

---

## C. Public-surface realism
### Baseline
- Fallback / normal browsing realism notes:

### Candidate
- Front / fallback realism notes:

### Verdict
- [ ] Better
- [ ] Same
- [ ] Worse

### Why

---

## D. Operator clarity
### Baseline
- Could operators explain path selection and failures?

### Candidate
- Could operators explain path selection and failures?

### Verdict
- [ ] Better
- [ ] Same
- [ ] Worse

### Why

---

## E. Rollback confidence
### Baseline
- Baseline restore assumptions:

### Candidate
- Rollback observations:

### Verdict
- [ ] Better
- [ ] Same
- [ ] Worse

### Why

---

## F. Net value vs added complexity
### Candidate complexity added
- What extra moving parts were introduced?

### Candidate value gained
- What real gain was demonstrated?

### Verdict
- [ ] Worth it
- [ ] Unclear
- [ ] Not worth it

### Why

---

# 4. Scorecard Mapping

Map the run into `docs/first-tier-promotion-scorecard.md`:

- Baseline Stability Preserved: [Pass / Mixed / Fail]
- Evidence Quality: [Pass / Mixed / Fail]
- Operator Clarity: [Pass / Mixed / Fail]
- Rollback Confidence: [Pass / Mixed / Fail]
- Public-Edge Separation Readiness: [Pass / Mixed / Fail]
- Net Value vs Added Complexity: [Pass / Mixed / Fail]

---

# 5. Forced Final Decision

Choose exactly one:
- [ ] Not ready
- [ ] Improved but not enough
- [ ] Ready for narrow promotion
- [ ] Rollback / pause candidate work

## Blunt One-Sentence Verdict

> 

---

# 6. Allowed Claims After This Run

## Claims that are justified
- 

## Claims that are NOT yet justified
- 

This section is mandatory.
It prevents overselling the result.

---

# 7. Next Action

Choose one:
- [ ] strengthen baseline only
- [ ] improve evidence tooling
- [ ] improve operator clarity
- [ ] run another narrow staging iteration
- [ ] pause candidate work

## Highest-value next change

## Biggest blocker

## Biggest remaining uncertainty
