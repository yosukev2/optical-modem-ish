#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="${1:-${BASE_SHA:-}}"
HEAD_SHA="${2:-${HEAD_SHA:-}}"
PR_LABELS_RAW="${PR_LABELS:-${GITHUB_PR_LABELS:-}}"

if [[ -z "${BASE_SHA}" || -z "${HEAD_SHA}" ]]; then
  echo "ERROR [INPUT] base_sha and head_sha are required (args or BASE_SHA/HEAD_SHA env)." >&2
  exit 2
fi

has_integration_pr_label() {
  local labels="${1:-}"
  tr ', ' '\n\n' <<<"${labels}" | sed '/^$/d' | grep -Fxq 'integration-pr'
}

check_forbidden_path() {
  local path="$1"

  if [[ "${path}" == *.kicad_prl ]]; then
    echo "ERROR [A:forbidden-kicad_prl] ${path}"
    return 0
  fi

  if [[ "${path}" =~ (^|/)[^/]+-backups/ ]]; then
    echo "ERROR [A:forbidden-backups-dir] ${path}"
    return 0
  fi

  if [[ "${path}" == *_autosave-* ]]; then
    echo "ERROR [A:forbidden-autosave] ${path}"
    return 0
  fi

  if [[ "${path}" == *.lck ]]; then
    echo "ERROR [A:forbidden-lock-file] ${path}"
    return 0
  fi

  if [[ "${path}" == hw/out/* ]]; then
    echo "ERROR [A:forbidden-hw-out] ${path}"
    return 0
  fi

  if [[ "${path}" =~ (^|/)out/ ]]; then
    echo "ERROR [A:forbidden-out-dir] ${path}"
    return 0
  fi

  return 1
}

integration_pr=false
if has_integration_pr_label "${PR_LABELS_RAW}"; then
  integration_pr=true
fi

declare -i violations=0
declare -i step00_touched=0

while IFS=$'\t' read -r status path1 path2; do
  [[ -z "${status:-}" ]] && continue

  effective_path=""
  case "${status}" in
    D*)
      effective_path="${path1:-}"
      ;;
    R*)
      effective_path="${path2:-}"
      ;;
    *)
      effective_path="${path1:-}"
      ;;
  esac

  [[ -z "${effective_path}" ]] && continue

  if check_forbidden_path "${effective_path}"; then
    violations+=1
  fi

  if [[ "${effective_path}" == "hw/hw.kicad_sch" ]]; then
    step00_touched=1
  fi

  if [[ "${status}" == A* || "${status}" == R* ]]; then
    if [[ "${effective_path}" =~ ^hw/.+\.kicad_sch$ ]] && [[ "${effective_path}" != "hw/hw.kicad_sch" ]]; then
      if [[ ! "${effective_path}" =~ ^hw/step[0-9][0-9]_[^/]+\.kicad_sch$ ]]; then
        echo "ERROR [B:invalid-step-schematic-name] ${effective_path}"
        violations+=1
      fi
    fi
  fi
done < <(git diff --name-status "${BASE_SHA}" "${HEAD_SHA}")

if [[ "${step00_touched}" -eq 1 ]] && [[ "${integration_pr}" != true ]]; then
  echo "ERROR [C:step00-change-requires-integration-pr-label] hw/hw.kicad_sch"
  violations+=1
fi

if [[ "${violations}" -gt 0 ]]; then
  echo "kicad_pr_guard: FAIL (${violations} violation(s))"
  exit 1
fi

echo "kicad_pr_guard: PASS"
