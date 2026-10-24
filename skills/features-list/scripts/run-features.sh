#!/usr/bin/env bash
# run-features.sh
#
# The only writer of features.json. Runs each feature's verification
# command and flips state to 'passing' or 'blocked' based on exit code.
#
# Usage:
#   run-features.sh [<project-root>]            # run all non-retired features
#   run-features.sh --id <feature-id> [<root>]  # run a single feature
#   run-features.sh --all [<root>]              # run all features including retired
#
# Exit code:
#   0 if every targeted feature ended in 'passing'
#   1 if any feature ended in 'blocked' or the file is malformed

set -uo pipefail

usage() {
    cat >&2 <<'EOF'
Usage:
  run-features.sh [<project-root>]
  run-features.sh --id <feature-id> [<project-root>]
  run-features.sh --all [<project-root>]
EOF
    exit 2
}

target_id=""
include_retired=0
positional=()

while [ $# -gt 0 ]; do
    case "$1" in
        --id)
            shift
            [ $# -gt 0 ] || usage
            target_id="$1"
            shift
            ;;
        --all)
            include_retired=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        --*)
            echo "Unknown flag: $1" >&2
            usage
            ;;
        *)
            positional+=("$1")
            shift
            ;;
    esac
done

PROJECT_ROOT="${positional[0]:-$PWD}"
FEATURES_FILE="$PROJECT_ROOT/features.json"

if [ ! -f "$FEATURES_FILE" ]; then
    echo "No features.json at $FEATURES_FILE" >&2
    exit 2
fi

# Validate JSON before touching anything.
if ! python3 -c "import json,sys; json.load(open('$FEATURES_FILE'))" 2>/dev/null; then
    echo "features.json is not valid JSON" >&2
    exit 1
fi

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Run via Python to keep JSON manipulation honest. Captures verification
# stdout+stderr (last 500 chars) into evidence.
python3 - "$FEATURES_FILE" "$PROJECT_ROOT" "$target_id" "$include_retired" "$timestamp" <<'PY'
import json, os, subprocess, sys, time

features_path, project_root, target_id, include_retired_str, ts = sys.argv[1:6]
include_retired = include_retired_str == "1"

with open(features_path) as f:
    data = json.load(f)

failed = 0
ran = 0

for feat in data.get("features", []):
    fid = feat["id"]
    if target_id and fid != target_id:
        continue
    if not include_retired and feat.get("state") == "retired":
        continue

    cmd = feat["verification"]
    print(f"[run-features] {fid}: {cmd}")

    proc = subprocess.run(
        cmd, shell=True, cwd=project_root,
        capture_output=True, text=True, timeout=600,
    )

    tail = (proc.stdout + proc.stderr)[-500:].strip()
    feat["evidence"] = tail or None
    feat["last_run"] = ts

    if proc.returncode == 0:
        feat["state"] = "passing"
        print(f"[run-features] {fid}: passing")
    else:
        feat["state"] = "blocked"
        failed += 1
        print(f"[run-features] {fid}: blocked (exit {proc.returncode})")

    ran += 1

with open(features_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

if ran == 0:
    print("[run-features] no matching features", file=sys.stderr)
    sys.exit(2)

print(f"[run-features] {ran} ran, {failed} blocked")
sys.exit(1 if failed else 0)
PY
