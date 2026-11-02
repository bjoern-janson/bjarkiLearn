"""Check frozen install-source bytes; no network, client, or file changes."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--portraits", required=True, type=Path)
    parser.add_argument("--cc", required=True, type=Path)
    parser.add_argument("--ui", required=True, type=Path)
    parser.add_argument("--learn", type=Path, default=Path("."))
    args = parser.parse_args()
    roots = {"bjarkiPortraits": args.portraits, "bjarkiCC": args.cc,
             "bjarkiUI": args.ui, "bjarkiLearn": args.learn}
    manifest = json.loads(Path(__file__).with_name("candidate.json").read_text())
    checked = 0
    for addon in manifest["addons"]:
        root = roots[addon["addon"]]
        for name, expected in addon["files"].items():
            # Release checksum lists are generated, not repository source files.
            if name in addon["generated_files"]:
                continue
            path = root / name
            if not path.is_file():
                parser.exit(1, "Missing candidate source: " + str(path) + "\n")
            if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                parser.exit(1, "Candidate source differs: " + str(path) + "\n")
            checked += 1
        print(addon["addon"] + " " + addon["version"] + ": exact source bytes")
    print(str(checked) + " source files match the frozen candidate manifest")


if __name__ == "__main__":
    main()
