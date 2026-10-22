# bjarkiLearn 0.1.0-shadow verification

## Release result

**124 passing case executions, zero failures, 25,398 assertions across Lua 5.1 and Lua 5.4.**

These results execute the actual runtime source with explicit modeled WoW APIs. All six runtime Lua files also compile independently under both engines. Ordinary and Camelot TOCs have the same load order and version. The release builder checks ZIP CRCs, inventories and exact source-byte matches after packaging.

| Runtime | Suite | Passed | Failed | Assertions |
| --- | --- | ---: | ---: | ---: |
| lua51 | adapter | 18 | 0 | 109 |
| lua51 | core | 24 | 0 | 174 |
| lua51 | network | 14 | 0 | 7840 |
| lua51 | replay | 2 | 0 | 4454 |
| lua51 | rules | 4 | 0 | 122 |
| lua54 | adapter | 18 | 0 | 109 |
| lua54 | core | 24 | 0 | 174 |
| lua54 | network | 14 | 0 | 7840 |
| lua54 | replay | 2 | 0 | 4454 |
| lua54 | rules | 4 | 0 | 122 |

## Behavioral evidence

- Numeric models learn an interacting synthetic pattern and a linear association; output masks, clipping, exact no-ops, deterministic copies, finite checks and atomic rejection are exercised.
- Core tests cover anchor exclusion, duplicate delivery, independent applications, per-family absence coverage, uncertain boundaries, immutable features, saved pre-update predictions and correction of their evaluation contributions.
- Corrections invalidate affected adaptive state and rebuild from clean retained examples. Eviction tests prevent stale revisions restoring retracted labels and prevent overlapping windows when an actor is evicted and recreated.
- The 1,100-cycle replay remains bounded at 16 actors, 128 occurrences and 256 examples. Combat collects observations without training; the retained candidate then completes outside combat.
- A synthetic changed-association replay reverses the earlier learned relationship and matches a clean rebuild from the revised corpus to numerical tolerance. This verifies adaptation machinery, not gameplay accuracy.
- Persistence stores deidentified compatible examples and deliberately resets transient session state. Restart and malformed-save tests verify deterministic clean rebuilding and atomic import rejection.
- Adapter tests cover secret/missing values, GUID rebinding and aliases, registration failure, unknown combat, optional bus load order, replay, world entry, disabled collection, copied public views and event-handler training deferral.
- Independent numeric review checked masked analytic gradients against finite differences in both engines. Independent core and integration reviews reproduced and rechecked the retention and bridge fixes, including integrations with the unchanged v16 SharedEvidence.lua. No confirmed important findings remained in those reviewed scopes.

## Practical limits

Live-client validation is outstanding. Modeled APIs cannot establish actual event delivery completeness, secret-value behavior in every client branch, real CPU cost, taint behavior or compatibility with every other addon. The target is Interface 16001, as used by the supplied Forever v16 suite.

Player-stream coverage is a declared collection regime. Enemy absence remains unknown and enemy learned scores are withheld. Scores are uncalibrated shadow diagnostics, and every public forecast has usable=false. No predictive improvement, consumer benefit or 99/100 quality claim follows from these tests.

The 256 retained windows are a bounded recent corpus, with masked and enemy-only windows included. Earlier examples are deliberately forgotten. Corrections outside retained identity/time support are conservatively rejected or censored. Pending windows and raw identities are not restored across reloads. The clock-based training budget is soft at a sample boundary; client profiling is still required.

## Reproduce

    python3 -m pip install -r requirements-test.txt
    python3 tests/run.py
    python3 tools/build_release.py --output dist

Raw per-suite results are in verification/results.jsonl. Runtime source hashes follow.

| File | SHA-256 |
| --- | --- |
| Bootstrap.lua | `8b44d8a6d47e15de1ab740479fbbdee0d11f4c4570c2381ca952c7878935a289` |
| Rules.lua | `25ef0cc8edb17cab6d251a63784589bcabc6c9485cd30e46078b404e4df8a532` |
| Network.lua | `2334ac31ce6a9c9946b17fd35441bc4db319a3febc6edf4e0fc3c278fae5f7e8` |
| Core.lua | `d6c0dcbbf52b10cc2a80370269103703fb9e83b55bd64bca72265412088a1bb0` |
| Adapter.lua | `8d202f577b5c0abce58e7655e56b37597ccb17f465233333952614370a614c88` |
| Main.lua | `7c1293d701171d3052c25cbab3dfcda4440619f8396e01103dcc4ecb22c06ec2` |
