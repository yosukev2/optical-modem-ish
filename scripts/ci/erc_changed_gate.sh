#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="${1:-${BASE_SHA:-}}"
HEAD_SHA="${2:-${HEAD_SHA:-}}"

resolve_base_sha() {
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    git merge-base origin/main HEAD
    return
  fi
  if git rev-parse --verify main >/dev/null 2>&1; then
    git merge-base main HEAD
    return
  fi
  git rev-parse HEAD~1
}

resolve_head_sha() {
  git rev-parse HEAD
}

if [[ -z "${BASE_SHA}" ]]; then
  BASE_SHA="$(resolve_base_sha)"
fi
if [[ -z "${HEAD_SHA}" ]]; then
  HEAD_SHA="$(resolve_head_sha)"
fi

echo "erc_changed_gate: base_sha=${BASE_SHA} head_sha=${HEAD_SHA}"

declare -a changed_sheets=()
while IFS=$'\t' read -r status path1 path2; do
  [[ -z "${status:-}" ]] && continue

  case "${status}" in
    D*)
      continue
      ;;
    R*|C*)
      path="${path2:-}"
      ;;
    *)
      path="${path1:-}"
      ;;
  esac

  [[ -z "${path:-}" ]] && continue

  if [[ "${path}" =~ ^hw/.+\.kicad_sch$ ]] && [[ -f "${path}" ]]; then
    changed_sheets+=("${path}")
  fi
done < <(git diff --name-status --find-renames "${BASE_SHA}" "${HEAD_SHA}")

if [[ ${#changed_sheets[@]} -eq 0 ]]; then
  echo "erc_changed_gate: no changed schematics under hw/*.kicad_sch, skip."
  exit 0
fi

mapfile -t unique_sheets < <(printf '%s\n' "${changed_sheets[@]}" | sort -u)

if ! command -v kicad-cli >/dev/null 2>&1; then
  echo "ERROR [INPUT] kicad-cli is required but not found in PATH." >&2
  exit 2
fi

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "ERROR [INPUT] python3/python is required to parse ERC JSON." >&2
  exit 2
fi

OUT_DIR="hw/out/erc"
mkdir -p "${OUT_DIR}"

declare -i failed_files=0

echo "erc_changed_gate: target files (${#unique_sheets[@]}):"
printf '  - %s\n' "${unique_sheets[@]}"
echo "erc_changed_gate: running ERC (severity-all), then enforcing error=0 and warning=0"

for sch in "${unique_sheets[@]}"; do
  base_name="$(basename "${sch}" .kicad_sch)"
  json_out="${OUT_DIR}/${base_name}_erc_changed.json"

  erc_exit=0
  if kicad-cli sch erc --format json --severity-all --output "${json_out}" "${sch}"; then
    erc_exit=0
  else
    erc_exit=$?
  fi

  if [[ ! -s "${json_out}" ]]; then
    echo "ERROR [ERC] missing ERC output JSON: ${json_out}" >&2
    exit 2
  fi

  read -r err_count warn_count < <("${PYTHON_BIN}" - "${json_out}" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

errors = 0
warnings = 0

def walk(node):
    global errors, warnings
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "severity" and isinstance(v, str):
                s = v.strip().lower()
                if s == "error":
                    errors += 1
                elif s == "warning":
                    warnings += 1
            walk(v)
    elif isinstance(node, list):
        for item in node:
            walk(item)

walk(data)
print(f"{errors} {warnings}")
PY
)

  echo "erc_changed_gate: ${sch} -> errors=${err_count}, warnings=${warn_count}, erc_exit=${erc_exit}, json=${json_out}"

  if (( err_count > 0 || warn_count > 0 )); then
    failed_files+=1
  fi
done

if (( failed_files > 0 )); then
  echo "erc_changed_gate: FAIL (${failed_files} file(s) have ERC error/warning violations)."
  exit 1
fi

echo "erc_changed_gate: PASS (all changed schematics are error=0 and warning=0)."
