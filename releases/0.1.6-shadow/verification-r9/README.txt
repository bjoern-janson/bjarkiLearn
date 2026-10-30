bjarkiLearn 0.1.6-shadow - verification revision 9
Published 2026-10-30

This directory publishes the exact audited verification-r9 ZIP. The addon
runtime and install ZIP remain 0.1.6-shadow. Python belongs to the separate
offline verification tools; it is not required by the installed Lua addon.

Install: ../bjarkiLearn-0.1.6-shadow.zip
Verify: bjarkiLearn-0.1.6-shadow-verification-r9.zip

Extract the verification ZIP to a separate folder, then run from its root:
  python -m pip install -r requirements-test.txt
  python -B run_all.py
  python -B build_verification_r9.py --output ../verification-dist

Both commands support --lupa-path for an existing Lupa dependency directory.
run_all.py --collect-existing revalidates completed evidence without rerunning
the full suite. The source and tests are inside the ZIP, not in the install ZIP.
Use ordinary Windows paths and ordinary file/directory names; see the two
confirmed limitations below. Do not place output under a payload directory.

Current status
The fresh deep audit completed all 23 full-suite jobs with their expected exits,
including 19/19 generated-metadata and 24/24 output-path cases. The clean ZIP's
1,815 members, CRCs, inventory, and all 14 installation files were checked.
Clean current and legacy builders reproduced the exact delivered ZIP.

Two confirmed verification-tooling bugs remain, both predating r9:
1. Equivalent ordinary and extended Windows namespace paths can bypass the
   protected-output check. Publication inside protected inputs then invalidates
   later completed-run verification. Existing runtime file bytes are unchanged.
2. An extended-name trailing-dot file without a canonical sibling, or a
   trailing-dot directory subtree, can be skipped before the rejection check.
   The builder can succeed while omitting supplemental physical payload files.
The existing 43 r9 cases do not cover these failures. This publication does not
fix them and does not assert that the verification tooling is free of bugs.

Evidence
- The ZIP and receipt are unchanged from the audited release.
- *-validation.json is the original pre-audit packaging result. Its statement
  that independent repair review had no remaining findings describes that
  earlier review, and is superseded by the two findings in *-audit.txt/json.
- *-audit.txt/json describe the subsequent deep audit and native reproductions.
- audit-run-manifest.json and audit-verification.json record the fresh 23-job
  rerun (474690d6a1384b6281547fb364de5c42); audit-run-exit.json records its exit.
- The ZIP retains the earlier completed release run and historical evidence.
  The audit rerun is separate; no report inside the release ZIP was replaced.
- SHA256SUMS covers every file in this directory except itself.

Absolute paths in preserved receipts/reports identify the original workspace;
they are provenance, not portable download links. Follow the ZIP's reproduction
instructions to generate local evidence. Local hashes establish consistency,
not independent cryptographic proof that a process executed.

Publication changes only repository documentation and this new artifact folder.
Earlier release folders/files and the install archive remain unchanged. The root
README and VERIFICATION notes now describe r9; their archived install copies
retain the original 0.1.6 documentation.

Validation scope: native Windows and Lua 5.1/5.4 with modeled WoW APIs. Native
POSIX full-suite execution, physical cross-drive/network-share behavior, live
WoW behavior, frame-time cost, and predictive usefulness are not established.
