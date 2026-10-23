# bjarkiLearn 0.1.6-shadow verification

This release repairs Druid root cast coverage and duplicated defensive-witness inputs against the exact 0.1.5-shadow install archive, SHA-256 `608ff7b953b0fa705ee11b0b517dfc0f433eaff6c0b7532d4a36f830d74184df`. Its semantic compatibility key changes; older learned examples are rejected, while enabled/disabled settings are retained. The saved structure remains schema 1.

## Current evidence

- The dedicated repair suite passes **42/42 cases**, with **67,624 checks** across Lua 5.1 and 5.4. The same final fixtures on exact 0.1.5 pass all 14 unchanged controls and fail the 28 executions requiring the new semantics. Initial pre-edit red reports are retained.
- Independent comparison passes **34/34 cases**, including exact comparisons for unaffected inputs and trajectories against 0.1.5, and corrected-versus-clean replay checks within each version for intentionally changed inputs. Only declared version, compatibility, target and candidate-basis metadata is normalized in the cross-version comparisons.
- A small separate repair smoke suite passes **8/8 checks**. The aggregate also compiles all six runtime Lua files in both engines and validates the two TOCs.
- The inherited runner executes **39 leaf jobs** against both exact 0.1.5 and 0.1.6. Its raw reports preserve failed historical expectations. The classifier requires the expected failure identities and counts, passing applicable controls, source hashes and replacements; it rejects any unclassified failure.

The suite covers each root rank through Main/Adapter, positive labels, Druid class candidates, witness age/expiry/future boundaries, copied projections, immutable anchors, atomic rejection of old saves on a live model, enabled and disabled startup, rejection notices, fresh-runtime deterministic save/reload, correction/retraction/reattribution, future maturity, retirement guards, time-floor protection, and actual record overflow. Limits remain 16 actors, 128 occurrences, 256 retained examples and 256 serving descriptors; candidate replay is bounded by retained examples. Adapter.lua and Network.lua are byte-identical to 0.1.5. Core.lua changes only its advertised target field.

## Historical expectation handling

Original inputs remain byte-for-byte intact: 421 verification files, 469 independent-audit files, and the 14-file 0.1.5 baseline. Disposable fixture adaptations are listed in `inherited/semantics.py` and the report manifests. Six exact expected-value substitutions in four files express witness recency at the existing timestamps; their known-bit, timing, correction and label assertions remain. Baseline controls use the original values. No production shim changes the tested runtime.

Six pre-0.1.4 future-positive assertion executions remain superseded, as in 0.1.5; they are recorded as failures and never counted as passes. Whole-model or whole-public-state equality with older releases is also no longer a valid requirement after the intentional feature, vocabulary and compatibility changes. Those raw comparisons remain failed historical claims. Same-version reload/cross-Lua controls and original lifecycle assertions are retained. Additional full traces run with independent 0.1.6 namespaces to check deterministic repeatability; they are explicitly not evidence of old/new model equivalence. The separate 34-case review supplies scoped cross-version comparisons and changed-input clean replay checks.

`reports-016/verification.json` is the current aggregate. `reports-016/inherited/classification.json` records the exact inherited pass counts, retired comparison claims and adapted controls. Historical reports retain their original version labels and are not represented as new successes.

## Reproduction and package integrity

Extract `bjarkiLearn-0.1.6-shadow-verification.zip`, then run:

```sh
python -m pip install -r requirements-test.txt
python run_all.py
python build_release.py --output dist
```

An optional `--lupa-path` points the runner to an existing Lupa installation. `run_all.py --collect-existing` validates completed report hashes and classifications without rerunning tests. Every packaged report is tied to the exact runtime files; document-only edits during an inherited run are identified separately from runtime changes.

The package builder requires a passing exact-source aggregate and the final review's source manifest. It validates the 14-file install inventory, both TOCs, version metadata, load order, UTF-8, ZIP CRCs and every archived byte. The separate evidence ZIP includes source, exact 0.1.5 baseline, original tests, new tests, red/green reports, adaptations, independent review and payload hashes.

These checks execute ordinary Lua with modeled WoW APIs. Live event delivery, rendering, taint/secret enforcement, frame-time cost and predictive usefulness remain unverified in WoW. Forecasts retain `usable=false`. Bounded, discarded identities and sealed deidentified examples cannot be reconstructed without limit. No installed addon or remote repository was modified for this release.
