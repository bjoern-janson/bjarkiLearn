bjarkiLearn 0.1.6-shadow - verification revision 10
Published 2026-10-30

The two confirmed r9 verification-tooling bugs are repaired. Resolved ordinary
and extended Windows namespace paths receive consistent output protection.
Unsupported trailing-dot/space entries are rejected before file predicates or
directory traversal can silently omit them. Native-distinct Unicode siblings
and ordinary payload files remain supported.

The addon runtime and original install ZIP remain 0.1.6-shadow, unchanged.
Python is only for this separate offline verification bundle.
Install: ../bjarkiLearn-0.1.6-shadow.zip
Verify: bjarkiLearn-0.1.6-shadow-verification-r10.zip

Extract the verification ZIP, then run from its root:
  python -m pip install -r requirements-test.txt
  python -B run_all.py
  python -B build_verification_r10.py --output ../verification-dist
Both commands accept --lupa-path for an existing Lupa dependency directory.

Verification: all 24 full-suite jobs returned expected exits; 22 new native-path
cases and 43 unchanged r9 cases passed. Exact r9 fails ten new cases. Four wrong
implementations were rejected; 15 completed-copy CLI controls and ten collector/
seal negative controls passed. All 48 old acceptance predicates, 180 unchanged
prior Python files and all 14 installation files were preserved. Independent
review found no blocker in the repaired scope. Final archive validation and a
clean extraction/legacy rebuild reproduced every published archive byte.

The ZIP contains source, tests, exact old history, completed reports, red/green
evidence and the supporting controls. REVIEW.txt/json record the independent
review before final parent checks; *-validation.json records final completion.
SHA256SUMS covers all files in this directory except itself. Absolute paths in
preserved evidence identify the original execution workspace, not portable links.

The r9 directory remains unchanged as historical evidence; its two known findings
are fixed in this revision. No Lua/TOC, original install ZIP or earlier release
artifact was changed. Repository documentation is updated separately.

Scope: native Windows and Lua 5.1/5.4 with modeled WoW APIs. UNC/POSIX path models
do not establish native share/POSIX execution. Live WoW, physical cross-drive
execution, frame-time cost and predictive usefulness remain unverified.
