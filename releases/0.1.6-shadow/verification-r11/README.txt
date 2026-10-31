bjarkiLearn 0.1.6-shadow - verification revision 11
Published 2026-10-31

All three confirmed r10 verification-tooling bugs are repaired:
1. The completed-copy checker rejects output inside its source before writing,
   including equivalent ordinary/extended Windows paths and missing descendants.
   Distinct Unicode siblings remain supported.
2. Checker subprocesses resolve inherited relative PYTHONPATH entries against
   the caller before changing working directory. Explicit dependency precedence,
   empty entries, UTF-8 logs and active assertions retain their protections.
3. Windows reserved payload components are rejected before file predicates,
   traversal or exclusions can silently omit them. This is a Windows portability
   policy; ordinary and near-name payload and POSIX exclusions remain supported.

The addon runtime and original install ZIP remain 0.1.6-shadow, unchanged.
Python is only for this separate offline verification bundle.
Install: ../bjarkiLearn-0.1.6-shadow.zip
Verify: bjarkiLearn-0.1.6-shadow-verification-r11.zip

Extract the verification ZIP, then run from its root:
  python -m pip install -r requirements-test.txt
  python -B run_all.py
  python -B build_verification_r11.py --output ../verification-dist
Both commands accept --lupa-path for an existing Lupa dependency directory.
run_all.py --collect-existing revalidates exact completed evidence without
repeating the full suite. See README-VERIFICATION.txt inside the ZIP for details.

The final full run completed all 26 required jobs with their expected exits,
including 38 new cases. All 19 completed-copy CLI controls, 42 direct report
acceptance controls, eight collector rejection controls and two clean collector
controls passed. Fifteen deliberately wrong implementations were detected.
All 51 original root assertions, 185 prior Python sources outside the four
intentionally changed Python files, and all 14 installation files were preserved.
Independent review found no outstanding issue in the repaired scope.

Final packaging checked all 2,008 archive members, CRCs, inventory, sealed input
and output hashes, and exact reviewed source. Rebuilding through the oldest
entry point from a fresh extraction produced a byte-identical ZIP.
The final completed run is 3c30799aa3af4ac8895397a42e13cca1.

The ZIP contains source, tests, preserved history, reports and supporting
evidence. Two POSIX expectations in a new test were corrected after the first
Windows run; the complete suite was rerun against the final source. Both attempts
are distinguished in the evidence. One-off supporting scripts retain their
original workspace assumptions; the documented runner/builders are the portable
entry points. REVIEW.txt/json describe independent review; *-validation.json
records final completion. SHA256SUMS covers this directory except itself.
Absolute paths in preserved reports are provenance, not portable download links.

Earlier release artifacts and install ZIPs remain unchanged. Root repository
documentation is updated separately from archived install documentation.
Scope: native Windows and real Lua 5.1/5.4 with modeled WoW APIs. POSIX/UNC models
do not establish native POSIX or network-share execution. Physical cross-drive
behavior, live WoW, frame-time cost and predictive usefulness remain unverified.
