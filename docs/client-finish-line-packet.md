# Client Finish-Line Packet

Use this packet when moving from active feature work into **internal alpha validation**.

## Core docs

1. `client/README.md`
2. `docs/client-development-notes.md`
3. `docs/client-product-architecture.md`
4. `docs/adr-client-product-stack.md`

## Alpha validation docs

1. `docs/client-internal-alpha-checklist.md`
2. `docs/client-runtime-smoke-test.md`
3. `docs/client-wrap-up-summary-2026-03-11.md`
4. `docs/client-packaging-readiness.md`
5. `docs/client-linux-packaging-plan.md`

## Recommended order

1. Read `client-wrap-up-summary-2026-03-11.md`
2. Read `client-internal-alpha-checklist.md`
3. Run `client-runtime-smoke-test.md`
4. Fix only the issues discovered by the first smoke run
5. Promote to `client-internal-alpha-1` when the checklist is green

## Current truth

The client is already good enough to function as a **product shell / architecture demo**.

The remaining work to cross into internal alpha is primarily:
- Flutter runtime validation
- real adapter environment validation
- first runtime smoke test
