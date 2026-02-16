# Issue Read Fallback Runbook

## 作業ログ（候補と改修対象）
- 候補: `.claude/skills/skill0_issue_intake/skill0_issue_intake.ps1`（issue読み込み）
- 候補: `.claude/skills/skill9_pr_submit/skill9_pr_submit.ps1`（PR作成）
- 候補: `docs/prompt/checkAC2pr.md`（PR作成プロンプト）
- `gh issue create` の既存実装は未検出（`rg "gh issue create"` 0件）
- 今回の改修対象: `github/temp_gh/read_issues.md`, `github/temp_gh/create_issue.md`, `github/temp_gh/pr.md`

## 何をする / 前提
- 目的: Issue情報を `github/temp_gh/jobs/issue-<number>/input/` に保存する。
- 3段階:
  - Fetch: `gh issue view` で取得（使える時だけ）。
  - Work: `issue.md` をローカル生成（ネット不要）。
  - Publish: このドキュメントでは未実施。
- 共通contract:
  - ルート: `github/temp_gh/`
  - jobパケット: `github/temp_gh/jobs/<job-id>/`
  - input/: 取得データまたは手動テンプレ
  - output/: 後続工程の成果物
- フォールバック発火:
  - `TEMP_GH_FORCE_FILE=1`
  - `gh` コマンド不在
  - `gh auth status` 失敗
  - `gh issue view` 非0終了（401/403/network/host解決失敗を含む）
- 実行完了時に必ず `job_id` と生成ファイル一覧を表示する。

## Quickstart (bash: WSL/Linux/macOS)
```bash
# ===== 設定（ここだけ変更）=====
REPO="owner/repo"
ISSUE_NUMBER="123"

# ===== 共通設定 =====
ROOT="github/temp_gh"
JOB_ID="issue-${ISSUE_NUMBER}"
JOB_DIR="${ROOT}/jobs/${JOB_ID}"
INPUT_DIR="${JOB_DIR}/input"
OUTPUT_DIR="${JOB_DIR}/output"
mkdir -p "${INPUT_DIR}" "${OUTPUT_DIR}"

ISSUE_URL="https://github.com/${REPO}/issues/${ISSUE_NUMBER}"
printf '%s\n' "${ISSUE_URL}" > "${INPUT_DIR}/issue_url.txt"

IS_FALLBACK=0
FALLBACK_REASON=""

if [ "${TEMP_GH_FORCE_FILE:-0}" = "1" ]; then
  IS_FALLBACK=1
  FALLBACK_REASON="TEMP_GH_FORCE_FILE=1"
elif ! command -v gh >/dev/null 2>&1; then
  IS_FALLBACK=1
  FALLBACK_REASON="gh not found"
elif ! gh auth status >/dev/null 2>&1; then
  IS_FALLBACK=1
  FALLBACK_REASON="gh auth status failed"
fi

ISSUE_JSON="${INPUT_DIR}/issue.json"
ISSUE_MD="${INPUT_DIR}/issue.md"
COMMENTS_JSON="${INPUT_DIR}/comments.json"

if [ "${IS_FALLBACK}" -eq 0 ]; then
  if ! gh issue view "${ISSUE_NUMBER}" -R "${REPO}" --json number,title,body,labels,assignees,author,state,url,createdAt,updatedAt > "${ISSUE_JSON}" 2> "${INPUT_DIR}/gh_error.log"; then
    IS_FALLBACK=1
    FALLBACK_REASON="gh issue view failed"
  fi
fi

if [ "${IS_FALLBACK}" -eq 0 ]; then
  python - "${ISSUE_JSON}" "${ISSUE_MD}" <<'PY'
import json
import sys

issue_json_path = sys.argv[1]
issue_md_path = sys.argv[2]
obj = json.load(open(issue_json_path, "r", encoding="utf-8"))

title = obj.get("title") or "(no title)"
url = obj.get("url") or ""
body = obj.get("body") or ""
state = obj.get("state") or ""
created = obj.get("createdAt") or ""
updated = obj.get("updatedAt") or ""
author = (obj.get("author") or {}).get("login", "")
labels = [x.get("name", "") for x in (obj.get("labels") or []) if isinstance(x, dict) and x.get("name")]
assignees = [x.get("login", "") for x in (obj.get("assignees") or []) if isinstance(x, dict) and x.get("login")]

ac_lines = []
for raw in body.splitlines():
    s = raw.strip().lstrip("-* ").strip()
    low = s.lower()
    if low.startswith("ac") or "acceptance criteria" in low or "受け入れ条件" in s:
        ac_lines.append(s)

lines = []
lines.append(f"# Issue #{obj.get('number', '')}: {title}")
lines.append("")
lines.append(f"- URL: {url}")
lines.append(f"- State: {state}")
lines.append(f"- Author: {author}")
lines.append(f"- CreatedAt: {created}")
lines.append(f"- UpdatedAt: {updated}")
lines.append(f"- Labels: {', '.join(labels) if labels else '(none)'}")
lines.append(f"- Assignees: {', '.join(assignees) if assignees else '(none)'}")
lines.append("")
lines.append("## Body")
lines.append("")
lines.append(body if body else "(empty)")
lines.append("")
lines.append("## AC (auto-extracted)")
lines.append("")
if ac_lines:
    for x in ac_lines:
        lines.append(f"- {x}")
else:
    lines.append("- (not found)")

open(issue_md_path, "w", encoding="utf-8").write("\n".join(lines).rstrip() + "\n")
PY

  if gh issue view "${ISSUE_NUMBER}" -R "${REPO}" --json comments > "${COMMENTS_JSON}" 2>/dev/null; then
    :
  else
    printf '%s\n' "comments.json は任意。ghのバージョン差で comments JSON 取得が失敗するため省略可。" > "${INPUT_DIR}/comments_skipped.txt"
  fi
else
  cat > "${ISSUE_MD}" <<EOF
# Issue #${ISSUE_NUMBER}: （ブラウザから貼り付け）

- URL: ${ISSUE_URL}
- State: （OPEN/CLOSED）
- Author: （user）
- Labels: （comma separated）
- Assignees: （comma separated）
- CreatedAt: （ISO8601）
- UpdatedAt: （ISO8601）

## Body

（Issue本文をそのまま貼り付け）

## AC (手動転記)

- AC1:
- AC2:
EOF
  printf '%s\n' "${FALLBACK_REASON}" > "${INPUT_DIR}/fallback_reason.txt"
  printf '%s\n' "gh issue view \"${ISSUE_NUMBER}\" -R \"${REPO}\" --web" > "${INPUT_DIR}/open_in_browser_cmd.txt"
fi

echo "job_id=${JOB_ID}"
echo "generated:"
printf ' - %s\n' "${INPUT_DIR}/issue_url.txt"
printf ' - %s\n' "${ISSUE_MD}"
[ -f "${ISSUE_JSON}" ] && printf ' - %s\n' "${ISSUE_JSON}"
[ -f "${COMMENTS_JSON}" ] && printf ' - %s\n' "${COMMENTS_JSON}"
[ -f "${INPUT_DIR}/comments_skipped.txt" ] && printf ' - %s\n' "${INPUT_DIR}/comments_skipped.txt"
[ -f "${INPUT_DIR}/fallback_reason.txt" ] && printf ' - %s\n' "${INPUT_DIR}/fallback_reason.txt"

# 失敗時の次アクション: input/issue.md を埋めて Work工程へ進む。
```

## Quickstart (PowerShell: Windows)
```powershell
# ===== 設定（ここだけ変更）=====
$REPO = "owner/repo"
$ISSUE_NUMBER = "123"

# ===== 共通設定 =====
$ROOT = "github/temp_gh"
$JOB_ID = "issue-$ISSUE_NUMBER"
$JOB_DIR = Join-Path $ROOT "jobs/$JOB_ID"
$INPUT_DIR = Join-Path $JOB_DIR "input"
$OUTPUT_DIR = Join-Path $JOB_DIR "output"
New-Item -ItemType Directory -Force -Path $INPUT_DIR, $OUTPUT_DIR | Out-Null

$ISSUE_URL = "https://github.com/$REPO/issues/$ISSUE_NUMBER"
Set-Content -LiteralPath (Join-Path $INPUT_DIR "issue_url.txt") -Value $ISSUE_URL -Encoding utf8

$IS_FALLBACK = $false
$FALLBACK_REASON = ""

if ($env:TEMP_GH_FORCE_FILE -eq "1") {
  $IS_FALLBACK = $true
  $FALLBACK_REASON = "TEMP_GH_FORCE_FILE=1"
} elseif (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  $IS_FALLBACK = $true
  $FALLBACK_REASON = "gh not found"
} else {
  gh auth status *> $null
  if ($LASTEXITCODE -ne 0) {
    $IS_FALLBACK = $true
    $FALLBACK_REASON = "gh auth status failed"
  }
}

$ISSUE_JSON = Join-Path $INPUT_DIR "issue.json"
$ISSUE_MD = Join-Path $INPUT_DIR "issue.md"
$COMMENTS_JSON = Join-Path $INPUT_DIR "comments.json"

if (-not $IS_FALLBACK) {
  gh issue view $ISSUE_NUMBER -R $REPO --json number,title,body,labels,assignees,author,state,url,createdAt,updatedAt > $ISSUE_JSON 2> (Join-Path $INPUT_DIR "gh_error.log")
  if ($LASTEXITCODE -ne 0) {
    $IS_FALLBACK = $true
    $FALLBACK_REASON = "gh issue view failed"
  }
}

if (-not $IS_FALLBACK) {
  $py = @'
import json
import sys

issue_json_path = sys.argv[1]
issue_md_path = sys.argv[2]
obj = json.load(open(issue_json_path, "r", encoding="utf-8"))

title = obj.get("title") or "(no title)"
url = obj.get("url") or ""
body = obj.get("body") or ""
state = obj.get("state") or ""
created = obj.get("createdAt") or ""
updated = obj.get("updatedAt") or ""
author = (obj.get("author") or {}).get("login", "")
labels = [x.get("name", "") for x in (obj.get("labels") or []) if isinstance(x, dict) and x.get("name")]
assignees = [x.get("login", "") for x in (obj.get("assignees") or []) if isinstance(x, dict) and x.get("login")]

ac_lines = []
for raw in body.splitlines():
    s = raw.strip().lstrip("-* ").strip()
    low = s.lower()
    if low.startswith("ac") or "acceptance criteria" in low or "受け入れ条件" in s:
        ac_lines.append(s)

lines = []
lines.append(f"# Issue #{obj.get('number', '')}: {title}")
lines.append("")
lines.append(f"- URL: {url}")
lines.append(f"- State: {state}")
lines.append(f"- Author: {author}")
lines.append(f"- CreatedAt: {created}")
lines.append(f"- UpdatedAt: {updated}")
lines.append(f"- Labels: {', '.join(labels) if labels else '(none)'}")
lines.append(f"- Assignees: {', '.join(assignees) if assignees else '(none)'}")
lines.append("")
lines.append("## Body")
lines.append("")
lines.append(body if body else "(empty)")
lines.append("")
lines.append("## AC (auto-extracted)")
lines.append("")
if ac_lines:
    for x in ac_lines:
        lines.append(f"- {x}")
else:
    lines.append("- (not found)")

open(issue_md_path, "w", encoding="utf-8").write("\n".join(lines).rstrip() + "\n")
'@
  $py | python - $ISSUE_JSON $ISSUE_MD

  gh issue view $ISSUE_NUMBER -R $REPO --json comments > $COMMENTS_JSON 2> $null
  if ($LASTEXITCODE -ne 0) {
    Set-Content -LiteralPath (Join-Path $INPUT_DIR "comments_skipped.txt") -Value "comments.json は任意。ghのバージョン差で comments JSON 取得が失敗するため省略可。" -Encoding utf8
  }
} else {
  @"
# Issue #${ISSUE_NUMBER}: （ブラウザから貼り付け）

- URL: $ISSUE_URL
- State: （OPEN/CLOSED）
- Author: （user）
- Labels: （comma separated）
- Assignees: （comma separated）
- CreatedAt: （ISO8601）
- UpdatedAt: （ISO8601）

## Body

（Issue本文をそのまま貼り付け）

## AC (手動転記)

- AC1:
- AC2:
"@ | Set-Content -LiteralPath $ISSUE_MD -Encoding utf8

  Set-Content -LiteralPath (Join-Path $INPUT_DIR "fallback_reason.txt") -Value $FALLBACK_REASON -Encoding utf8
  Set-Content -LiteralPath (Join-Path $INPUT_DIR "open_in_browser_cmd.txt") -Value "gh issue view $ISSUE_NUMBER -R $REPO --web" -Encoding utf8
}

"job_id=$JOB_ID"
"generated:"
" - $(Join-Path $INPUT_DIR 'issue_url.txt')"
" - $ISSUE_MD"
if (Test-Path $ISSUE_JSON) { " - $ISSUE_JSON" }
if (Test-Path $COMMENTS_JSON) { " - $COMMENTS_JSON" }
if (Test-Path (Join-Path $INPUT_DIR "comments_skipped.txt")) { " - $(Join-Path $INPUT_DIR 'comments_skipped.txt')" }
if (Test-Path (Join-Path $INPUT_DIR "fallback_reason.txt")) { " - $(Join-Path $INPUT_DIR 'fallback_reason.txt')" }

# 失敗時の次アクション: input/issue.md を埋めて Work工程へ進む。
```

## オンライン取得（gh）
- `gh` が有効なら `issue.json` を正本として取得し、`python` で `issue.md` を生成する。
- `comments.json` は任意。`gh` のバージョン差で `comments` フィールド取得が失敗する場合があるため、その場合は `comments_skipped.txt` を残して先へ進む。

## オフライン回避（gh失敗時）
- `input/issue.md` テンプレを自動生成する。
- ブラウザでIssueページを開いて本文を貼り付ければ、Fetch未達でも Work を継続できる。
- 参照用コマンドは `input/open_in_browser_cmd.txt` に残す。

## 生成されるファイル（input側）
- `github/temp_gh/jobs/issue-<number>/input/issue_url.txt`
- `github/temp_gh/jobs/issue-<number>/input/issue.json`（オンライン成功時）
- `github/temp_gh/jobs/issue-<number>/input/issue.md`
- `github/temp_gh/jobs/issue-<number>/input/comments.json`（取得できた場合）
- `github/temp_gh/jobs/issue-<number>/input/comments_skipped.txt`（comments省略時）
- `github/temp_gh/jobs/issue-<number>/input/fallback_reason.txt`（フォールバック時）
