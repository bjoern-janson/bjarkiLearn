bjarkiLearn 0.1.5-shadow publication

The 14 addon files at the repository root and docs/ match the audited install archive byte-for-byte. DESIGN.md retains the original design; the current README and implementation notes describe what this shadow release actually implements.

Files
- bjarkiLearn-0.1.5-shadow.zip: installable addon; extract its bjarkiLearn folder into Interface/AddOns.
- bjarkiLearn-0.1.5-shadow-verification.zip: original portable verification source, tests, baselines and release reports.
- bjarkiLearn-0.1.5-shadow-audit-evidence.zip: subsequent independent review, new tests, complete fresh packaged rerun and source snapshots.
- bjarkiLearn-0.1.5-shadow-audit.txt: detailed independent audit report.
- audit-summary.json: aggregate checks and source hashes.
- bjarkiLearn-0.1.5-shadow-audit-checks.json: integrity checks for the independent evidence bundle.
- SHA256SUMS: SHA-256 for the artifacts listed above.

Verification
The complete packaged suite passed on the exact source, followed by independent Core, native and numeric/persistence review. No confirmed remaining bug or 0.1.5 regression was found in that bounded audit. The source and archives are unchanged by publication. Extract either verification bundle and follow its README to reproduce the modeled Lua 5.1/5.4 checks.

Provenance
The source documents and audit reports describe the earlier build/audit stages. Their statements that no remote repository was modified apply to those stages. This commit publishes those exact artifacts to GitHub; it does not claim a fresh live-client validation. Paths in the preserved reports identify the original execution environment. Portable runners and fixtures accompany them.

Limits
Live-client API behavior, protected-value enforcement, taint, actual frame-time cost and predictive usefulness remain unverified. This remains a shadow release with read-only diagnostic forecasts.
