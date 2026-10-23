# bjarkiLearn 0.1.5-shadow verification

This release implements two internal refactors against the exact 0.1.4-shadow install archive (SHA-256 `3cf686e9b1e3fe78b8577c15c75e2e1ba08fc6142b4cf794b36ac9da048f461d`). It removes redundant actor evidence mirrors and makes reconciliation triggers explicit. The compatibility key and saved-example schema are unchanged.

The verification bundle records fresh results under `reports-0.1.5`, cross-version differential probes under `tests-refactor`, and the independent whole-change review under `review-0.1.5`. Its root `run_all.py` runs the inherited applicable checks, the subsequent 0.1.4 audit controls, new refactor contracts and differential comparisons against the preserved source. The package builder requires successful reports with hashes matching the runtime it archives.

The comparisons exercise public context and forecasts, saved examples, learned and candidate parameters, revisions, correction invalidation, lead-only updates, future evidence, retirement, reset and bounded retention under Lua 5.1 and Lua 5.4. Unchanged public outputs are the compatibility target; the removed private actor fields are intentionally absent. The 16-actor, 128-occurrence, 256-example and 256-serving-descriptor limits remain.

Original Lua/Python test and support files are preserved byte-for-byte. A staged runner adapts only obsolete private-cache reads to explicit evidence projections and records every substitution; no production compatibility shim restores the removed caches. The six already-superseded future-positive assertions from older releases remain recorded as expected historical failures, not counted as passing. Observed-clock replacements retain their behavioral controls.

Package validation checks the same 14-file install inventory, both TOCs and version declarations, load references, UTF-8, CRC integrity and every archived byte against the verified source. Historical reports retain their original version labels; use the current aggregate for this release's results.

Reproduce after extracting `bjarkiLearn-0.1.5-shadow-verification.zip`:

```sh
python -m pip install -r requirements-test.txt
python run_all.py
python build_release.py --output dist
```

These are ordinary Lua checks with modeled WoW APIs. Live event delivery, native rendering, taint/secret enforcement, frame-time cost and predictive usefulness remain unverified in WoW. Shadow outputs retain `usable=false`. Discarded identities and sealed deidentified history cannot be reconstructed without limit. No installed addon or remote repository was modified.
