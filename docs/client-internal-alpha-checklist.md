# Client Internal Alpha Checklist

## Goal

Define the minimum bar for calling the Trojan-Pro Flutter client **internal alpha ready**.

This checklist is intentionally practical: do not wait for perfect packaging or full production hardening before using it to judge whether the client is ready for first internal hands-on testing.

---

## Exit Definition

The client may be called **internal alpha** when all of the following are true:

1. The Flutter client launches successfully on at least one desktop target.
2. A profile can be created or imported.
3. A Trojan password can be stored and retrieved via the secure-storage boundary.
4. The real shell controller adapter can pass a binary health probe.
5. The client can attempt a real connect path using generated config + process launch.
6. The client can disconnect/terminate the spawned process cleanly.
7. Dashboard runtime session state reflects PID / exit / log-tail changes.
8. Diagnostics export succeeds and includes controller + packaging + runtime session data.

---

## Required Validation Steps

### A. Flutter Runtime Validation

- [ ] `cd client`
- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter run -d linux` (or macOS / Windows)

### B. Local Runtime Preparation

- [ ] Local `trojan` binary exists and is executable
- [ ] `TROJAN_CLIENT_ENABLE_REAL_ADAPTER=1`
- [ ] `TROJAN_CLIENT_BINARY=/absolute/path/to/trojan` if auto-discovery is not correct
- [ ] A reachable test server / safe local test target is available

### C. Product Flow Validation

- [ ] Create profile
- [ ] Store Trojan password
- [ ] Confirm runtime mode is `external-runtime-boundary`
- [ ] Confirm health probe is not `unavailable`
- [ ] Click connect
- [ ] Observe PID + config path + runtime session tail
- [ ] Click disconnect
- [ ] Confirm PID clears and config is cleaned up

### D. Diagnostics / Productization Validation

- [ ] Diagnostics preview succeeds
- [ ] Diagnostics export succeeds
- [ ] Packaging snapshot export succeeds
- [ ] Diagnostics bundle includes runtime session / controller telemetry / packaging status

---

## Non-Blocking for Internal Alpha

The following are important, but **not required** for the first internal alpha milestone:

- desktop installer generation
- signed releases / notarization
- auto-update service backend
- CI packaging automation
- polished reconnect strategy
- full runtime log viewer UX
- mobile targets

---

## Blocking Failures

If any of the following is true, the client is **not** internal alpha ready:

- Flutter app does not launch on a target desktop platform
- secure storage cannot persist/retrieve Trojan password
- real adapter cannot probe or launch the trojan binary
- connect path cannot start a process
- disconnect cannot stop the process
- runtime session data never updates in UI
- diagnostics export fails

---

## Current Most Likely Remaining Risks

1. Flutter runtime/analyze issues in a real desktop environment
2. binary path / environment mismatch on the operator machine
3. runtime process exit behavior differing from the current skeleton assumptions
4. secure-storage plugin behavior differing across desktop targets

---

## Suggested Milestone Label

Once all required checks pass:

**Milestone:** `client-internal-alpha-1`
