# bjarkiLearn 0.1.6-shadow verification

This release repairs Druid root cast coverage and duplicated defensive-witness inputs against the exact 0.1.5-shadow install archive, SHA-256 `608ff7b953b0fa705ee11b0b517dfc0f433eaff6c0b7532d4a36f830d74184df`. Its semantic compatibility key changes; older learned examples are rejected, while enabled/disabled settings are retained. The saved structure remains schema 1.

## Verification tooling revision 9 (2026-10-30)

The [r9 artifact directory](releases/0.1.6-shadow/verification-r9/README.txt) contains the exact audited bundle, checksums, original release receipt, and subsequent audit results. The install ZIP and all six Lua files and both TOCs remain unchanged at 0.1.6-shadow. Root repository documentation is updated separately from the archived install documentation.

The fresh audit run completed **23/23 jobs with their expected exits**. Its 1,037 input hashes match the release, and its 193 output hashes were checked. The r9 metadata and output-path suites passed **19/19** and **24/24** cases. Archive checks covered all 1,815 files and all 14 installation files. Clean builds reproduced the released archive SHA-256, `d978df2e8895cd505f24d712d73e92bc8cb59cfe7177c51dcba384c2b86adf34`.

Two confirmed P2 verification-tooling gaps remain; both predate r9:

- **Extended Windows namespace aliases:** `C:\...` and `\\?\C:\...` can identify the same directory while bypassing the protected-output comparison. Actual builders published into protected inputs, invalidating later completed-run verification.
- **Unpaired trailing-dot entries:** ordinary Windows file predicates/traversal can skip a physical trailing-dot file or directory before the rejection guard runs. Actual builders succeeded while omitting supplemental payload files from both ZIP and inventory.

These cases are absent from the existing 43 r9 cases. The delivered clean ZIP is intact; this repository publication applies no additional fixes. Use ordinary Windows paths and file names, and an output directory outside the bundle's payload trees. The [deep audit](releases/0.1.6-shadow/verification-r9/bjarkiLearn-0.1.6-shadow-verification-r9-audit.txt) supersedes the earlier repair review's no-remaining-findings statement for verification tooling.

The full rerun used native Windows and actual Lua 5.1/5.4 with modeled WoW APIs. It does not establish native POSIX full-suite behavior, physical cross-drive or network-share behavior, or live WoW performance and usefulness. Publication rechecks the exact archive and completed evidence; it does not replace the separately recorded fresh audit run.

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

Extract `bjarkiLearn-0.1.6-shadow-verification-r9.zip`, then run:

```sh
python -m pip install -r requirements-test.txt
python run_all.py
python build_verification_r9.py --output ../verification-dist
```

An optional `--lupa-path` points the runner to an existing Lupa installation. `run_all.py --collect-existing` validates completed report hashes and classifications without rerunning tests. Every packaged report is tied to the exact runtime files; document-only edits during an inherited run are identified separately from runtime changes.

The package builder requires a passing exact-source aggregate and the final review's source manifest. It validates the 14-file install inventory, both TOCs, version metadata, load order, UTF-8, ZIP CRCs and every archived byte. The separate evidence ZIP includes source, exact 0.1.5 baseline, original tests, new tests, red/green reports, adaptations, independent review and payload hashes.

These checks execute ordinary Lua with modeled WoW APIs. Live event delivery, rendering, taint/secret enforcement, frame-time cost and predictive usefulness remain unverified in WoW. Forecasts retain `usable=false`. Bounded, discarded identities and sealed deidentified examples cannot be reconstructed without limit. Preserved reports describe their original execution stages; this repository publication adds the exact r9 artifacts and current audit notes without modifying the installed addon or archived runtime.
