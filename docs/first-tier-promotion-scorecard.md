# First-Tier Promotion Scorecard

## Status

Draft

## Purpose

Force a strict, repeatable judgment after every serious candidate or baseline-comparison run.

This scorecard exists to prevent the project from confusing:

- internal progress
- architectural readiness
- real public-edge advancement

## How To Use

After a serious run, mark each dimension as one of:

- **Pass**
- **Mixed**
- **Fail**

Then make a final decision:

- **Not ready**
- **Improved but not enough**
- **Ready for narrow promotion**
- **Rollback / pause candidate work**

---

# 1. Scoring Dimensions

## A. Baseline Stability Preserved

Question:
Did the project preserve the current deployable baseline while running this candidate work?

### Pass
- baseline profile still works
- baseline smoke behavior remains understandable
- no candidate-only assumptions leaked into default behavior
- rollback path still returns to baseline without code revert

### Mixed
- baseline still works, but config or operator clarity regressed

### Fail
- default behavior drifted toward candidate assumptions
- rollback is no longer simple
- baseline confidence is visibly lower than before

Score: [ ] Pass  [ ] Mixed  [ ] Fail
Notes:

---

## B. Evidence Quality

Question:
Did this run produce evidence strong enough to compare against the baseline rather than just describe activity?

### Pass
- evidence bundle is complete
- config snapshot exists
- logs exist
- timestamps / outputs are coherent
- the run can be compared to a previous run without guesswork

### Mixed
- most evidence exists, but one important input is missing or unclear

### Fail
- the run mostly produced narrative rather than comparison-grade evidence

Score: [ ] Pass  [ ] Mixed  [ ] Fail
Notes:

---

## C. Operator Clarity

Question:
Can an operator explain what happened quickly and accurately?

### Pass
- active path is obvious
- acceptance / rejection signals are understandable
- fallback usage is visible
- candidate failures can be separated from baseline or transport failures

### Mixed
- the run is explainable, but only with deep project context

### Fail
- logs or artifacts are too ambiguous to support quick diagnosis

Score: [ ] Pass  [ ] Mixed  [ ] Fail
Notes:

---

## D. Rollback Confidence

Question:
Can the candidate be disabled cleanly and baseline behavior confirmed quickly?

### Pass
- rollback is config-driven
- rollback steps are documented
- rollback verification is explicit
- restored baseline behavior is observable

### Mixed
- rollback worked, but verification was noisy or too manual

### Fail
- rollback required ad hoc debugging, code changes, or guesswork

Score: [ ] Pass  [ ] Mixed  [ ] Fail
Notes:

---

## E. Public-Edge Separation Readiness

Question:
Did this run materially improve confidence that the project can separate public edge behavior from backend admission logic in an operationally coherent way?

### Pass
- front / backend role split is clear
- trust boundary is explicit
- candidate path demonstrates real separation value
- operator evidence supports the separation claim

### Mixed
- the architecture is closer, but the operational gain is still unproven

### Fail
- the run mostly proves internal plumbing, not public-edge value

Score: [ ] Pass  [ ] Mixed  [ ] Fail
Notes:

---

## F. Net Value vs Added Complexity

Question:
Did this run show enough practical upside to justify the complexity it adds?

### Pass
- the added moving parts feel justified by clearer future value
- the comparison suggests a believable next step

### Mixed
- the candidate is promising, but the value gap over baseline remains too small or too uncertain

### Fail
- complexity clearly outruns proven benefit

Score: [ ] Pass  [ ] Mixed  [ ] Fail
Notes:

---

# 2. Final Decision Rules

## Ready for narrow promotion
Only if:
- no Fail in A-D
- at least Pass in E
- at least Mixed in F
- and the overall judgment is evidence-based rather than aspirational

## Improved but not enough
Use if:
- baseline is preserved
- evidence quality is decent
- candidate is more real than before
- but public-edge improvement is still not strong enough to justify a tier upgrade

## Not ready
Use if:
- evidence is incomplete
- operator clarity is weak
- rollback is not trustworthy
- or the run mostly proves path existence only

## Rollback / pause candidate work
Use if:
- baseline confidence regressed
- rollback confidence is low
- complexity clearly exceeded value
- or trust/observability assumptions became fuzzy

---

# 3. Final Scorecard Summary

- Baseline Stability Preserved: 
- Evidence Quality: 
- Operator Clarity: 
- Rollback Confidence: 
- Public-Edge Separation Readiness: 
- Net Value vs Added Complexity: 

## Final Decision
- [ ] Not ready
- [ ] Improved but not enough
- [ ] Ready for narrow promotion
- [ ] Rollback / pause candidate work

## Blunt One-Sentence Verdict

> 

## Next Action
- [ ] strengthen baseline only
- [ ] improve evidence tooling
- [ ] improve operator clarity
- [ ] run another narrow staging iteration
- [ ] pause candidate work
