#!/usr/bin/env python3
"""Run the real addon Lua in isolated Lua 5.1 and 5.4 runtimes via Lupa."""
from pathlib import Path
import argparse
import importlib
import json
import os
import sys

ROOT = Path(__file__).resolve().parents[1]
deps = os.environ.get("BJARKI_LUPA_PATH", "/tmp/bjarkiCC-v15-deps")
if Path(deps).exists():
    sys.path.insert(0, deps)

parser = argparse.ArgumentParser()
parser.add_argument("suite", nargs="?", default="all")
parser.add_argument("--engine", choices=["lua51", "lua54", "both"], default="both")
args = parser.parse_args()
paths = sorted((ROOT / "tests").glob("test_*.lua"))
if args.suite != "all":
    paths = [p for p in paths if p.stem == "test_" + args.suite]
if not paths:
    raise SystemExit("No matching test suite")

engines = ["lua51", "lua54"] if args.engine == "both" else [args.engine]
totals = []
for engine in engines:
    LuaRuntime = importlib.import_module("lupa." + engine).LuaRuntime
    for path in paths:
        lua = LuaRuntime(unpack_returned_tuples=True)
        ns = lua.table()
        support = ROOT / "tests" / "wow.lua"
        if support.exists():
            lua.execute(support.read_text())
        for name in ("Bootstrap", "Rules", "Network", "Core", "Adapter", "Main"):
            module = ROOT / (name + ".lua")
            if module.exists():
                lua.execute(module.read_text(), "bjarkiLearn", ns, name=name + ".lua")
        harness = lua.execute((ROOT / "tests" / "harness.lua").read_text())
        suite = lua.execute(path.read_text(), name=path.name)
        suite(ns, harness)
        failures = [harness.failures[i] for i in range(1, len(harness.failures) + 1)]
        result = {"engine": engine, "suite": path.stem, "passed": harness.passed,
                  "failed": len(failures), "assertions": harness.assertions,
                  "failures": failures}
        totals.append(result)
        print(json.dumps(result))
print(json.dumps({"total_passed": sum(r["passed"] for r in totals),
                  "total_failed": sum(r["failed"] for r in totals),
                  "total_assertions": sum(r["assertions"] for r in totals)}))
sys.exit(any(r["failed"] for r in totals))
