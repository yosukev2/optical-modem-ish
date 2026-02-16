# Issue Create Fallback Runbook

## 何をする / 前提
- 目的: `jobs/issue-draft-<slug>/input/` の原稿から Issue を作成する。
- 3段階:
  - Fetch: このドキュメントでは不要。
  - Work: 原稿ファイルを生成・整形（ネット不要）。
  - Publish: `gh issue create`（GitHub依存）。
- 共通contract:
  - ルート: `github/temp_gh/`
  - jobパケット: `github/temp_gh/jobs/<job-id>/`
  - input/: `issue_title.txt`, `issue_body.md`, `labels.txt`
  - output/: `create_issue.md`, `next_cmd.txt`, `issue_url.txt` など
- フォールバック発火:
  - `TEMP_GH_FORCE_FILE=1`
  - `gh` コマンド不在
  - `gh auth status` 失敗
  - `gh issue create` 非0終了（401/403/network/host解決失敗を含む）
- 実行完了時に必ず `job_id` と生成ファイル一覧を表示する。

## Quickstart (bash: WSL/Linux/macOS)
```bash
# ===== 設定（ここだけ変更）=====
REPO="owner/repo"
SLUG="topic-short-name"

# ===== 共通設定 =====
ROOT="github/temp_gh"
JOB_ID="issue-draft-${SLUG}"
JOB_DIR="${ROOT}/jobs/${JOB_ID}"
INPUT_DIR="${JOB_DIR}/input"
OUTPUT_DIR="${JOB_DIR}/output"
mkdir -p "${INPUT_DIR}" "${OUTPUT_DIR}"

TITLE_FILE="${INPUT_DIR}/issue_title.txt"
BODY_FILE="${INPUT_DIR}/issue_body.md"
LABELS_FILE="${INPUT_DIR}/labels.txt"

if [ ! -f "${TITLE_FILE}" ]; then
  cat > "${TITLE_FILE}" <<'EOF'
[Draft] title here
EOF
fi

if [ ! -f "${BODY_FILE}" ]; then
  cat > "${BODY_FILE}" <<'EOF'
## Summary
- What:
- Why:

## Acceptance Criteria
- AC1:
- AC2:
EOF
fi

if [ ! -f "${LABELS_FILE}" ]; then
  : > "${LABELS_FILE}"
fi

CREATE_ISSUE_MD="${OUTPUT_DIR}/create_issue.md"
python - "${TITLE_FILE}" "${BODY_FILE}" "${LABELS_FILE}" "${CREATE_ISSUE_MD}" <<'PY'
import pathlib
import sys

title = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").strip()
body = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").rstrip() + "\n"
labels = []
for raw in pathlib.Path(sys.argv[3]).read_text(encoding="utf-8").splitlines():
    s = raw.strip()
    if s and not s.startswith("#"):
        labels.append(s)

out = []
out.append("# Issue Draft")
out.append("")
out.append("## Title")
out.append("")
out.append(title if title else "(empty)")
out.append("")
out.append("## Labels")
out.append("")
if labels:
    for x in labels:
        out.append(f"- {x}")
else:
    out.append("- (none)")
out.append("")
out.append("## Body")
out.append("")
out.append(body.rstrip())

pathlib.Path(sys.argv[4]).write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY

LABELS_CSV="$(python - "${LABELS_FILE}" <<'PY'
import pathlib
import sys
p = pathlib.Path(sys.argv[1])
labels = [x.strip() for x in p.read_text(encoding="utf-8").splitlines() if x.strip() and not x.strip().startswith("#")]
print(",".join(labels))
PY
)"

NEXT_CMD="${OUTPUT_DIR}/next_cmd.txt"
cat > "${NEXT_CMD}" <<EOF
# bash: online復旧後に1コマンドでIssue作成
REPO='${REPO}'; JOB_DIR='${JOB_DIR}'; TITLE_FILE="\$JOB_DIR/input/issue_title.txt"; BODY_FILE="\$JOB_DIR/input/issue_body.md"; LABELS_FILE="\$JOB_DIR/input/labels.txt"; LABELS_CSV="\$(python -c "import pathlib,sys; p=pathlib.Path(sys.argv[1]); print(','.join([x.strip() for x in p.read_text(encoding='utf-8').splitlines() if x.strip() and not x.strip().startswith('#')]))" "\$LABELS_FILE")"; if [ -n "\$LABELS_CSV" ]; then gh issue create -R "\$REPO" --title "\$(cat "\$TITLE_FILE")" --body-file "\$BODY_FILE" --label "\$LABELS_CSV"; else gh issue create -R "\$REPO" --title "\$(cat "\$TITLE_FILE")" --body-file "\$BODY_FILE"; fi

# PowerShell: online復旧後に1コマンドでIssue作成
\$REPO='${REPO}'; \$JOB_DIR='${JOB_DIR}'; \$TITLE_FILE=Join-Path \$JOB_DIR 'input/issue_title.txt'; \$BODY_FILE=Join-Path \$JOB_DIR 'input/issue_body.md'; \$LABELS_FILE=Join-Path \$JOB_DIR 'input/labels.txt'; \$labelsCsv=(python -c "import pathlib; p=pathlib.Path(r'${JOB_DIR}/input/labels.txt'); print(','.join([x.strip() for x in p.read_text(encoding='utf-8').splitlines() if x.strip() and not x.strip().startswith('#')]))"); if (\$labelsCsv) { gh issue create -R \$REPO --title (Get-Content -LiteralPath \$TITLE_FILE -Raw).Trim() --body-file \$BODY_FILE --label \$labelsCsv } else { gh issue create -R \$REPO --title (Get-Content -LiteralPath \$TITLE_FILE -Raw).Trim() --body-file \$BODY_FILE }
EOF

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

ISSUE_URL_FILE="${OUTPUT_DIR}/issue_url.txt"

if [ "${IS_FALLBACK}" -eq 0 ]; then
  if [ -n "${LABELS_CSV}" ]; then
    ISSUE_URL="$(gh issue create -R "${REPO}" --title "$(cat "${TITLE_FILE}")" --body-file "${BODY_FILE}" --label "${LABELS_CSV}" 2> "${OUTPUT_DIR}/gh_error.log")"
  else
    ISSUE_URL="$(gh issue create -R "${REPO}" --title "$(cat "${TITLE_FILE}")" --body-file "${BODY_FILE}" 2> "${OUTPUT_DIR}/gh_error.log")"
  fi
  if [ $? -eq 0 ]; then
    printf '%s\n' "${ISSUE_URL}" > "${ISSUE_URL_FILE}"
  else
    IS_FALLBACK=1
    FALLBACK_REASON="gh issue create failed"
  fi
fi

if [ "${IS_FALLBACK}" -eq 1 ]; then
  printf '%s\n' "${FALLBACK_REASON}" > "${OUTPUT_DIR}/fallback_reason.txt"
fi

echo "job_id=${JOB_ID}"
echo "generated:"
printf ' - %s\n' "${TITLE_FILE}" "${BODY_FILE}" "${LABELS_FILE}"
printf ' - %s\n' "${CREATE_ISSUE_MD}" "${NEXT_CMD}"
[ -f "${ISSUE_URL_FILE}" ] && printf ' - %s\n' "${ISSUE_URL_FILE}"
[ -f "${OUTPUT_DIR}/fallback_reason.txt" ] && printf ' - %s\n' "${OUTPUT_DIR}/fallback_reason.txt"

# 失敗時の次アクション: output/next_cmd.txt の bash か PowerShell 1行を貼る。
```

## Quickstart (PowerShell: Windows)
```powershell
# ===== 設定（ここだけ変更）=====
$REPO = "owner/repo"
$SLUG = "topic-short-name"

# ===== 共通設定 =====
$ROOT = "github/temp_gh"
$JOB_ID = "issue-draft-$SLUG"
$JOB_DIR = Join-Path $ROOT "jobs/$JOB_ID"
$INPUT_DIR = Join-Path $JOB_DIR "input"
$OUTPUT_DIR = Join-Path $JOB_DIR "output"
New-Item -ItemType Directory -Force -Path $INPUT_DIR, $OUTPUT_DIR | Out-Null

$TITLE_FILE = Join-Path $INPUT_DIR "issue_title.txt"
$BODY_FILE = Join-Path $INPUT_DIR "issue_body.md"
$LABELS_FILE = Join-Path $INPUT_DIR "labels.txt"

if (-not (Test-Path $TITLE_FILE)) {
  Set-Content -LiteralPath $TITLE_FILE -Value "[Draft] title here" -Encoding utf8
}
if (-not (Test-Path $BODY_FILE)) {
  @"
## Summary
- What:
- Why:

## Acceptance Criteria
- AC1:
- AC2:
"@ | Set-Content -LiteralPath $BODY_FILE -Encoding utf8
}
if (-not (Test-Path $LABELS_FILE)) {
  Set-Content -LiteralPath $LABELS_FILE -Value "" -Encoding utf8
}

$CREATE_ISSUE_MD = Join-Path $OUTPUT_DIR "create_issue.md"
$pyDraft = @'
import pathlib
import sys

title = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").strip()
body = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").rstrip() + "\n"
labels = []
for raw in pathlib.Path(sys.argv[3]).read_text(encoding="utf-8").splitlines():
    s = raw.strip()
    if s and not s.startswith("#"):
        labels.append(s)

out = []
out.append("# Issue Draft")
out.append("")
out.append("## Title")
out.append("")
out.append(title if title else "(empty)")
out.append("")
out.append("## Labels")
out.append("")
if labels:
    for x in labels:
        out.append(f"- {x}")
else:
    out.append("- (none)")
out.append("")
out.append("## Body")
out.append("")
out.append(body.rstrip())

pathlib.Path(sys.argv[4]).write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
'@
$pyDraft | python - $TITLE_FILE $BODY_FILE $LABELS_FILE $CREATE_ISSUE_MD

$LABELS_CSV = python -c "import pathlib; p=pathlib.Path(r'$LABELS_FILE'); print(','.join([x.strip() for x in p.read_text(encoding='utf-8').splitlines() if x.strip() and not x.strip().startswith('#')]))"

$NEXT_CMD = Join-Path $OUTPUT_DIR "next_cmd.txt"
@"
# bash: online復旧後に1コマンドでIssue作成
REPO='$REPO'; JOB_DIR='$JOB_DIR'; TITLE_FILE="`$JOB_DIR/input/issue_title.txt"; BODY_FILE="`$JOB_DIR/input/issue_body.md"; LABELS_FILE="`$JOB_DIR/input/labels.txt"; LABELS_CSV="`$(python -c "import pathlib,sys; p=pathlib.Path(sys.argv[1]); print(','.join([x.strip() for x in p.read_text(encoding='utf-8').splitlines() if x.strip() and not x.strip().startswith('#')]))" "`$LABELS_FILE")"; if [ -n "`$LABELS_CSV" ]; then gh issue create -R "`$REPO" --title "`$(cat "`$TITLE_FILE")" --body-file "`$BODY_FILE" --label "`$LABELS_CSV"; else gh issue create -R "`$REPO" --title "`$(cat "`$TITLE_FILE")" --body-file "`$BODY_FILE"; fi

# PowerShell: online復旧後に1コマンドでIssue作成
`$REPO='$REPO'; `$JOB_DIR='$JOB_DIR'; `$TITLE_FILE=Join-Path `$JOB_DIR 'input/issue_title.txt'; `$BODY_FILE=Join-Path `$JOB_DIR 'input/issue_body.md'; `$LABELS_FILE=Join-Path `$JOB_DIR 'input/labels.txt'; `$labelsCsv=(python -c "import pathlib; p=pathlib.Path(r'${JOB_DIR}/input/labels.txt'); print(','.join([x.strip() for x in p.read_text(encoding='utf-8').splitlines() if x.strip() and not x.strip().startswith('#')]))"); if (`$labelsCsv) { gh issue create -R `$REPO --title (Get-Content -LiteralPath `$TITLE_FILE -Raw).Trim() --body-file `$BODY_FILE --label `$labelsCsv } else { gh issue create -R `$REPO --title (Get-Content -LiteralPath `$TITLE_FILE -Raw).Trim() --body-file `$BODY_FILE }
"@ | Set-Content -LiteralPath $NEXT_CMD -Encoding utf8

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

$ISSUE_URL_FILE = Join-Path $OUTPUT_DIR "issue_url.txt"
if (-not $IS_FALLBACK) {
  if ($LABELS_CSV) {
    $issueUrl = gh issue create -R $REPO --title (Get-Content -LiteralPath $TITLE_FILE -Raw).Trim() --body-file $BODY_FILE --label $LABELS_CSV 2> (Join-Path $OUTPUT_DIR "gh_error.log")
  } else {
    $issueUrl = gh issue create -R $REPO --title (Get-Content -LiteralPath $TITLE_FILE -Raw).Trim() --body-file $BODY_FILE 2> (Join-Path $OUTPUT_DIR "gh_error.log")
  }
  if ($LASTEXITCODE -eq 0) {
    Set-Content -LiteralPath $ISSUE_URL_FILE -Value $issueUrl -Encoding utf8
  } else {
    $IS_FALLBACK = $true
    $FALLBACK_REASON = "gh issue create failed"
  }
}

if ($IS_FALLBACK) {
  Set-Content -LiteralPath (Join-Path $OUTPUT_DIR "fallback_reason.txt") -Value $FALLBACK_REASON -Encoding utf8
}

"job_id=$JOB_ID"
"generated:"
" - $TITLE_FILE"
" - $BODY_FILE"
" - $LABELS_FILE"
" - $CREATE_ISSUE_MD"
" - $NEXT_CMD"
if (Test-Path $ISSUE_URL_FILE) { " - $ISSUE_URL_FILE" }
if (Test-Path (Join-Path $OUTPUT_DIR "fallback_reason.txt")) { " - $(Join-Path $OUTPUT_DIR 'fallback_reason.txt')" }

# 失敗時の次アクション: output/next_cmd.txt の bash か PowerShell 1行を貼る。
```

## オンライン作成（gh issue create）
- `input/issue_title.txt` と `input/issue_body.md` は必須。
- `input/labels.txt` は任意（1行1label）。存在し、空でなければ `--label "a,b,c"` で付与する。
- 成功時も `output/issue_url.txt` を残す（履歴と再利用のため）。

## オフライン回避（gh失敗時）
- GitHubへアクセスせず、`output/create_issue.md` と `output/next_cmd.txt` を作って完了する。
- `next_cmd.txt` は、後日オンライン復旧後に1コマンドでPublishするための再実行コマンド。

## 生成されるファイル
- `github/temp_gh/jobs/issue-draft-<slug>/input/issue_title.txt`
- `github/temp_gh/jobs/issue-draft-<slug>/input/issue_body.md`
- `github/temp_gh/jobs/issue-draft-<slug>/input/labels.txt`（任意）
- `github/temp_gh/jobs/issue-draft-<slug>/output/create_issue.md`
- `github/temp_gh/jobs/issue-draft-<slug>/output/next_cmd.txt`
- `github/temp_gh/jobs/issue-draft-<slug>/output/issue_url.txt`（オンライン成功時）
- `github/temp_gh/jobs/issue-draft-<slug>/output/fallback_reason.txt`（フォールバック時）
