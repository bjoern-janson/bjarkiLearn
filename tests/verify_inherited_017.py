#!/usr/bin/env python3
"""Re-run frozen 0.1.6 Lua test logic against 0.1.7 with scoped fixture changes.

The archive is never edited. Historical cross-version whole-state comparisons
remain visible as expected mismatches, rather than being silently discarded.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "releases/0.1.6-shadow/verification-r11/bjarkiLearn-0.1.6-shadow-verification-r11.zip"
RECEIPT = ROOT / "releases/0.1.6-shadow/verification-r11/bjarkiLearn-0.1.6-shadow-verification-r11-validation.json"
REPORT = ROOT / "inherited-017-results.json"

OLD_COMPAT = ("learn1/forever16001-provisional2/features48-v2/cast-delivery-v2/"
              "h2/player-combat-v1/mlp12-sgd4-v1")
NEW_COMPAT = ("learn1/forever16001-provisional2/features48-v3/cast-delivery-v2/"
              "h2/player-combat-v1/self-aura-v1/retention-v1/replay-v2/mlp12-sgd4-v1")
EXPECTED_HISTORIC = {
    ("lua51", "current_vs_exact015", "exact_unaffected_feature_matrix_and_config"),
    ("lua51", "current_vs_exact015", "unaffected_mage_trace_seed_16073"),
    ("lua51", "current_vs_exact015", "unaffected_mage_trace_seed_73913"),
    ("lua54", "current_vs_exact015", "exact_unaffected_feature_matrix_and_config"),
    ("lua54", "current_vs_exact015", "unaffected_mage_trace_seed_16073"),
    ("lua54", "current_vs_exact015", "unaffected_mage_trace_seed_73913"),
}


def exact_patch(path: Path, old: str, new: str) -> dict:
    original = path.read_text(encoding="utf-8-sig")
    count = original.count(old)
    if count != 1:
        raise RuntimeError(f"{path.name}: expected precisely one patch anchor, got {count}: {old[:65]}")
    changed = original.replace(old, new)
    path.write_text(changed, encoding="utf-8")
    return {"file": str(path.name), "old": old, "new": new,
            "before": hashlib.sha256(original.encode()).hexdigest(),
            "after": hashlib.sha256(changed.encode()).hexdigest()}


def run(name: str, cmd: list[str], tmp: Path) -> dict:
    logfile = tmp / f"{name}.log"
    resultfile = tmp / f"{name}.json"
    proc = subprocess.run(cmd + ["--output", str(resultfile)], cwd=ROOT,
                          text=True, capture_output=True)
    logfile.write_text(proc.stdout + "\n" + proc.stderr)
    if not resultfile.is_file():
        raise RuntimeError(f"{name} runner did not produce a report: {proc.stdout[-1500:]} {proc.stderr[-1500:]}")
    data = json.loads(resultfile.read_text())
    rows = data["cases"]
    failures = [r for r in rows if r["passed"] is not True]
    summary = {"name": name, "exit": proc.returncode, "total": len(rows),
               "passed": len(rows) - len(failures),
               "source_unchanged": data.get("source_unchanged", False),
               "baseline_unchanged": data.get("baseline_unchanged", True),
               "failures": failures}
    if not summary["source_unchanged"] or not summary["baseline_unchanged"]:
        raise RuntimeError(name + ": test runner mutated original sources")
    return summary


def main() -> int:
    receipt = json.loads(RECEIPT.read_text())
    actual = hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()
    if actual != receipt["sha256"]:
        raise RuntimeError("historical archive checksum mismatch")
    with tempfile.TemporaryDirectory(prefix="bjarki017-") as folder:
        tmp = Path(folder)
        prefixes = ("tests-016/", "review-016/", "smoke/", "baseline/source/bjarkiLearn/")
        with ZipFile(ARCHIVE) as z:
            # The numerical learner and class/feature rules remain byte-identical
            # to 0.1.6; whole-state deviations must come from the declared
            # collection, retention and serving-lifecycle changes.
            for unchanged in ("Network.lua", "Rules.lua"):
                if z.read("source/bjarkiLearn/" + unchanged) != (ROOT / unchanged).read_bytes():
                    raise RuntimeError("undeclared mathematical/rule source drift: " + unchanged)
            for entry in z.infolist():
                path = entry.filename
                if entry.is_dir() or not (path.startswith(prefixes) or path == "input-manifest.json"):
                    continue
                target = tmp / path
                if not target.resolve().is_relative_to(tmp.resolve()):
                    raise RuntimeError("unsafe historical archive member")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(z.read(entry))
        patches = []
        edit = lambda file, old, new: patches.append(exact_patch(tmp / file, old, new))
        # Saved-version contract: exact new key, older invalid saves still rejected.
        edit("tests-016/cases.lua", OLD_COMPAT, NEW_COMPAT)
        # Retire the player training row using player data, not intentionally
        # protected unknown enemy rows; retain the old late-correction assertion.
        edit("tests-016/cases.lua",
             "c:_Resolve({actor='other',anchor=t,deadline=t+2,resolveAt=t+2.25,regime='other',x={},predictions={},coverage={},lost={},revision=1})",
             "c:_Resolve({actor='P',anchor=t,deadline=t+2,resolveAt=t+2.25,regime='player',x=NS.Rules.Features({class='DRUID',role='self',combat=true},t,{}),predictions={},coverage={[3]=true},lost={},revision=1})")
        edit("review-016/lifecycle.lua",
             "pushOthers(c,256,w.x);eq(c.model,serving,'replay retirement preserves serving');eq(#c.examples,256)",
             "for i=1,256 do c:_Resolve({actor='P',anchor=20+i*3,deadline=22+i*3,resolveAt=22.25+i*3,regime='player',x=w.x,predictions={},coverage={[3]=true},lost={},revision=1}) end;eq(c.model,serving,'replay retirement preserves serving');eq(#c.examples,256)")
        edit("review-016/lifecycle.lua",
             "ns.Config.version=='0.1.6-shadow' and .75 or 1",
             "ns.Config.version~='0.1.5-shadow' and .75 or 1")
        edit("review-016/lifecycle.lua",
             "ns.Config.version=='0.1.6-shadow' and 0 or 1",
             "ns.Config.version~='0.1.5-shadow' and 0 or 1")
        edit("review-016/lifecycle.lua",
             "local is016=ns.Config.version=='0.1.6-shadow'",
             "local is016=ns.Config.version~='0.1.5-shadow'")
        edit("smoke/probes.lua",
             "eq(ns.Config.version,'0.1.6-shadow')",
             "eq(ns.Config.version,'0.1.7-shadow')")
        edit("smoke/probes.lua", OLD_COMPAT, NEW_COMPAT)
        baseline = tmp / "baseline/source/bjarkiLearn"
        results = [
            run("semantic", [sys.executable, str(tmp / "tests-016/run.py"),
                             "--source", str(ROOT), "--baseline", str(baseline)], tmp),
            run("review", [sys.executable, str(tmp / "review-016/run.py"),
                           "--source", str(ROOT), "--baseline", str(baseline)], tmp),
            run("smoke", [sys.executable, str(tmp / "smoke/run.py"),
                          "--source", str(ROOT)], tmp),
        ]
        count = {r["name"]: r["total"] for r in results}
        if count != {"semantic": 42, "review": 34, "smoke": 8}:
            raise RuntimeError(f"historical test inventory changed: {count}")
        unexpected = []
        for result in results:
            for f in result["failures"]:
                key = (f.get("engine", f.get("runtime")), f.get("source"),
                       f.get("name", f.get("case")))
                if result["name"] != "review" or key not in EXPECTED_HISTORIC:
                    unexpected.append((result["name"], key, f.get("error")))
        historic = {(f.get("engine"), f.get("source"), f.get("name"))
                    for result in results if result["name"] == "review"
                    for f in result["failures"]}
        if historic != EXPECTED_HISTORIC:
            unexpected.append(("historic_mismatch_set", historic, EXPECTED_HISTORIC))
        report = {"archive_sha256": actual, "fixture_adaptations": patches,
                  "results": results, "historic_expected_failures": len(EXPECTED_HISTORIC),
                  "unexpected": unexpected,
                  "scope": "Lua 5.1/5.4 with modeled native WoW APIs; original archived tests untouched."}
        REPORT.write_text(json.dumps(report, indent=2) + "\n")
        for result in results:
            print(result["name"], result["passed"], "/", result["total"],
                  "failed IDs:", [(f.get("engine", f.get("runtime")),
                                   f.get("name", f.get("case"))) for f in result["failures"]])
        print("Historical-only incomparable cases:", len(EXPECTED_HISTORIC))
        print("Unexpected failures:", len(unexpected))
        for item in unexpected[:15]:
            print(item)
        return 1 if unexpected else 0


if __name__ == "__main__":
    raise SystemExit(main())
