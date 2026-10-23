bjarkiLearn 0.1.6-shadow publication

The 14 addon files at the repository root and docs/ match the verified install
archive byte-for-byte. DESIGN.md retains the original design. The current
README, API and implementation notes describe this shadow release.

Changes
- Recognize all six Entangling Roots cast ranks and the Druid root candidate.
- Use distinct defensive-witness recency and known-evidence inputs.
- Version the rules, features and cast target together. Older learning is not
 loaded because its root labels and witness ages cannot be reconstructed.
 The enabled/disabled preference is preserved; startup/status explains rejection.
- Correction handling, immutable inputs and the 16/128/256/256 history bounds remain.

Files
- bjarkiLearn-0.1.6-shadow.zip: install; extract bjarkiLearn into Interface/AddOns.
- bjarkiLearn-0.1.6-shadow-verification.zip: exact source, original baselines/tests,
 repair tests and reports, explicit historical adaptations, release builder.
- bjarkiLearn-0.1.6-shadow-audit-evidence.zip: subsequent independent deep audit,
 new probes, full fresh packaged rerun, exact source and results.
- bjarkiLearn-0.1.6-shadow-AUDIT.txt: independent audit report.
- audit-summary.json: independent audit aggregate and source hashes.
- bjarkiLearn-0.1.6-package.json: original release ZIP hashes and integrity checks.
- SHA256SUMS: hashes of the artifacts above and this release README.

Verification
The packaged verification was rerun on exact source: 42/42 repair cases, 34/34
comparison cases and 12/12 Lua syntax checks, with zero unexpected inherited
failures. Historical obsolete assertions remain separately recorded, not passes.
The additional audit passed 40 Core, 148 native and 24 persistence/model executions
(these counts include exact 0.1.5 controls), plus 16 end-to-end traces and 24 exact
comparisons. No confirmed remaining bug or unintended regression was found in
this bounded offline audit. The source and ZIPs are unchanged by publication.

Provenance
Statements in the preserved build/audit documents that no remote repository was
modified describe those earlier stages. This commit publishes those exact
artifacts. The preceding 0.1.5 release remains under releases/0.1.5-shadow/.
Report paths identify the original execution workspace; scripts and fixtures
are included. Follow each bundle's reproduction instructions.

Limits
Actual WoW event delivery, secret-value/taint enforcement, frame-time performance
and predictive usefulness remain unverified. This is a shadow release: forecasts
remain diagnostic and unusable for driving the interface.
