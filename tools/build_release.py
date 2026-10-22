#!/usr/bin/env python3
"""Verify both Lua engines and build reproducible addon/source archives."""
from pathlib import Path
import argparse
import hashlib
import importlib
import json
import os
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=ROOT / "dist")
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
version = re.search(r'version = "([^"]+)"', (ROOT / "Bootstrap.lua").read_text()).group(1)

run = subprocess.run([sys.executable, "tests/run.py"], cwd=ROOT, text=True, capture_output=True)
print(run.stdout, end="")
if run.returncode:
    print(run.stderr, file=sys.stderr)
    raise SystemExit(run.returncode)
rows = [json.loads(line) for line in run.stdout.splitlines() if line.strip()]
results, total = rows[:-1], rows[-1]
assert total["total_failed"] == 0

toc = (ROOT / "bjarkiLearn.toc").read_text()
assert toc == (ROOT / "bjarkiLearn_Camelot.toc").read_text()
assert "## Version: " + version in toc
runtime = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
assert runtime == [name + ".lua" for name in ["Bootstrap", "Rules", "Network", "Core", "Adapter", "Main"]]
deps = os.environ.get("BJARKI_LUPA_PATH", "/tmp/bjarkiCC-v15-deps")
if Path(deps).exists():
    sys.path.insert(0, deps)
for engine in ("lua51", "lua54"):
    lua = importlib.import_module("lupa." + engine).LuaRuntime(unpack_returned_tuples=True)
    compile_lua = lua.eval("function(s,n) local f,e=(loadstring or load)(s,n); assert(f,e); return true end")
    for name in runtime:
        assert compile_lua((ROOT / name).read_text(), name)

sha = lambda data: hashlib.sha256(data).hexdigest()
hashes = {name: sha((ROOT / name).read_bytes()) for name in runtime}
(ROOT / "verification").mkdir(exist_ok=True)
(ROOT / "verification" / "results.jsonl").write_text(run.stdout)
(ROOT / "verification" / "runtime-sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
table = "\n".join(f'| {r["engine"]} | {r["suite"].removeprefix("test_")} | {r["passed"]} | {r["failed"]} | {r["assertions"]} |' for r in results)
hash_table = "\n".join(f"| {name} | `{value}` |" for name, value in hashes.items())
report = f'''# bjarkiLearn {version} verification

## Release result

**{total["total_passed"]} passing case executions, zero failures, {total["total_assertions"]:,} assertions across Lua 5.1 and Lua 5.4.**

These results execute the actual runtime source with explicit modeled WoW APIs. All six runtime Lua files also compile independently under both engines. Ordinary and Camelot TOCs have the same load order and version. The release builder checks ZIP CRCs, inventories and exact source-byte matches after packaging.

| Runtime | Suite | Passed | Failed | Assertions |
| --- | --- | ---: | ---: | ---: |
{table}

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
{hash_table}
'''
(ROOT / "VERIFICATION.md").write_text(report)

install = runtime + ["bjarkiLearn.toc", "bjarkiLearn_Camelot.toc", "README.md", "CHANGELOG.md", "DESIGN.md", "VERIFICATION.md", "docs/API.md", "docs/IMPLEMENTATION.md"]
source = [str(p.relative_to(ROOT)) for p in ROOT.rglob("*") if p.is_file()
          and not any(part in {".git", "__pycache__", ".venv", "dist"} for part in p.relative_to(ROOT).parts)]
def archive(path, names, prefix):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in sorted(names):
            info = zipfile.ZipInfo(prefix + name, date_time=(2026, 10, 22, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, (ROOT / name).read_bytes())
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        assert set(z.namelist()) == {prefix + name for name in names}
        for name in names:
            assert z.read(prefix + name) == (ROOT / name).read_bytes()
    return {"file": str(path), "bytes": path.stat().st_size, "entries": len(names), "sha256": sha(path.read_bytes())}

archives = [archive(output / f"bjarkiLearn-{version}.zip", install, "bjarkiLearn/"),
            archive(output / f"bjarkiLearn-{version}-source-and-tests.zip", source, "bjarkiLearn-source/")]
(output / "bjarkiLearn-release.json").write_text(json.dumps({"version": version, "tests": total, "runtime": hashes, "archives": archives}, indent=2) + "\n")
for item in archives:
    print(json.dumps(item))
