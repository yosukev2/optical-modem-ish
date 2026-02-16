# PR Create Fallback Runbook

## 何をする / 前提
- 目的: PR公開に失敗しても、`output/` に PR原稿と差分を残して作業を止めない。
- 3段階:
  - Fetch: このドキュメントでは不要。
  - Work: `pr_title.txt`, `pr.md`, `changes.diff` を生成（ネット不要）。
  - Publish: `git push` + `gh pr create`（GitHub依存）。
- 共通contract:
  - ルート: `github/temp_gh/`
  - jobパケット: `github/temp_gh/jobs/<job-id>/`
  - PR job-id推奨: `pr-<branch-or-issue>`（`issue-<number>` 互換でも可）
  - output/: PR原稿、差分、復旧手順、再実行コマンド
- フォールバック発火:
  - `TEMP_GH_FORCE_FILE=1`
  - `gh` コマンド不在
  - `gh auth status` 失敗
  - `git push` 失敗
  - `gh pr create` 非0終了（401/403/network/host解決失敗を含む）
- 実行完了時に必ず `job_id` と生成ファイル一覧を表示する。

## 差分形式の選択
- このrunbookは `changes.diff` を採用する。
- 理由:
  - 人間が差分レビューしやすい。
  - `git apply changes.diff` で別環境へ復元しやすい。
  - メールヘッダ付きパッチより運用が単純。

## Quickstart (bash: WSL/Linux/macOS)
```bash
# ===== 設定（ここだけ変更）=====
REPO="owner/repo"
BASE="main"
ISSUE_NUMBER="123"   # 任意。不要なら空文字
HEAD="$(git rev-parse --abbrev-ref HEAD)"

# ===== 共通設定 =====
ROOT="github/temp_gh"
SAFE_HEAD="${HEAD//\//-}"
if [ -n "${ISSUE_NUMBER}" ]; then
  JOB_ID="pr-issue-${ISSUE_NUMBER}"
else
  JOB_ID="pr-${SAFE_HEAD}"
fi
JOB_DIR="${ROOT}/jobs/${JOB_ID}"
OUTPUT_DIR="${JOB_DIR}/output"
EVID_DIR="${OUTPUT_DIR}/evidence"
mkdir -p "${OUTPUT_DIR}" "${EVID_DIR}"

PR_TITLE_FILE="${OUTPUT_DIR}/pr_title.txt"
PR_BODY_FILE="${OUTPUT_DIR}/pr.md"
DIFF_FILE="${OUTPUT_DIR}/changes.diff"
RESTORE_FILE="${OUTPUT_DIR}/restore_steps.md"
NEXT_CMD_FILE="${OUTPUT_DIR}/next_cmd.txt"
PR_URL_FILE="${OUTPUT_DIR}/pr_url.txt"

# ===== 最小安全チェック =====
git status > "${EVID_DIR}/git_status.txt"
git diff --stat "${BASE}..${HEAD}" > "${EVID_DIR}/git_diff_stat_base_head.txt" 2> "${EVID_DIR}/git_diff_stat_error.log" || true

BASE_SHA="$(git merge-base "origin/${BASE}" "${HEAD}" 2>/dev/null || true)"
if [ -z "${BASE_SHA}" ]; then
  BASE_SHA="$(git merge-base "${BASE}" "${HEAD}" 2>/dev/null || true)"
fi
if [ -z "${BASE_SHA}" ]; then
  BASE_SHA="$(git rev-parse "${HEAD}~1" 2>/dev/null || git rev-parse "${HEAD}")"
fi
printf '%s\n' "${BASE_SHA}" > "${EVID_DIR}/base_sha.txt"

git diff "${BASE_SHA}..${HEAD}" > "${DIFF_FILE}"

TITLE_SEED="$(git log -1 --pretty=%s 2>/dev/null || echo "Update ${HEAD}")"
if [ -n "${ISSUE_NUMBER}" ]; then
  printf 'Issue #%s: %s\n' "${ISSUE_NUMBER}" "${TITLE_SEED}" > "${PR_TITLE_FILE}"
else
  printf 'PR: %s\n' "${TITLE_SEED}" > "${PR_TITLE_FILE}"
fi

{
  echo "# What"
  echo "- Describe what changed."
  echo ""
  echo "# Why"
  echo "- Describe why this change is needed."
  echo ""
  echo "# Evidence"
  echo "- git status: \`${EVID_DIR}/git_status.txt\`"
  echo "- git diff --stat: \`${EVID_DIR}/git_diff_stat_base_head.txt\`"
  echo "- diff: \`${DIFF_FILE}\`"
  echo ""
  echo "# Impact"
  echo "- Scope of affected components/files."
  echo ""
  echo "# Related Issue"
  if [ -n "${ISSUE_NUMBER}" ]; then
    echo "- Closes #${ISSUE_NUMBER}"
  else
    echo "- (none)"
  fi
  echo ""
  echo "# Checklist"
  echo "- [ ] Title and body reviewed"
  echo "- [ ] Evidence files attached"
  echo "- [ ] Risk/impact documented"
  echo "- [ ] Test results documented"
} > "${PR_BODY_FILE}"

cat > "${RESTORE_FILE}" <<EOF
# Restore Steps (Offline -> Online)

1. Clone or open target repository.
2. Checkout base branch and create restore branch.
   - \`git checkout ${BASE}\`
   - \`git pull --ff-only\`
   - \`git checkout -b restore/${SAFE_HEAD}\`
3. Apply diff from this job packet.
   - \`git apply ${DIFF_FILE}\`
4. Commit and push.
   - \`git add -A\`
   - \`git commit -m "\$(cat ${PR_TITLE_FILE})"\`
   - \`git push -u origin restore/${SAFE_HEAD}\`
5. Create PR using saved title/body.
   - \`gh pr create -R ${REPO} --base ${BASE} --head restore/${SAFE_HEAD} --title "\$(cat ${PR_TITLE_FILE})" --body-file ${PR_BODY_FILE}\`
EOF

cat > "${NEXT_CMD_FILE}" <<EOF
# bash: online復旧後に1コマンドでPublish
REPO='${REPO}'; BASE='${BASE}'; HEAD='${HEAD}'; JOB_DIR='${JOB_DIR}'; git push -u origin "\$HEAD" && gh pr create -R "\$REPO" --base "\$BASE" --head "\$HEAD" --title "\$(cat "\$JOB_DIR/output/pr_title.txt")" --body-file "\$JOB_DIR/output/pr.md"

# PowerShell: online復旧後に1コマンドでPublish
\$REPO='${REPO}'; \$BASE='${BASE}'; \$HEAD='${HEAD}'; \$JOB_DIR='${JOB_DIR}'; git push -u origin \$HEAD; if (\$LASTEXITCODE -eq 0) { gh pr create -R \$REPO --base \$BASE --head \$HEAD --title (Get-Content -LiteralPath (Join-Path \$JOB_DIR 'output/pr_title.txt') -Raw).Trim() --body-file (Join-Path \$JOB_DIR 'output/pr.md') }
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

if [ "${IS_FALLBACK}" -eq 0 ]; then
  if git push -u origin "${HEAD}" > "${EVID_DIR}/git_push.log" 2>&1; then
    PR_URL="$(gh pr create -R "${REPO}" --base "${BASE}" --head "${HEAD}" --title "$(cat "${PR_TITLE_FILE}")" --body-file "${PR_BODY_FILE}" 2> "${EVID_DIR}/gh_pr_create_error.log")"
    if [ $? -eq 0 ]; then
      printf '%s\n' "${PR_URL}" > "${PR_URL_FILE}"
    else
      IS_FALLBACK=1
      FALLBACK_REASON="gh pr create failed"
    fi
  else
    IS_FALLBACK=1
    FALLBACK_REASON="git push failed"
  fi
fi

if [ "${IS_FALLBACK}" -eq 1 ]; then
  printf '%s\n' "${FALLBACK_REASON}" > "${OUTPUT_DIR}/fallback_reason.txt"
fi

echo "job_id=${JOB_ID}"
echo "generated:"
printf ' - %s\n' "${PR_TITLE_FILE}" "${PR_BODY_FILE}" "${DIFF_FILE}" "${RESTORE_FILE}" "${NEXT_CMD_FILE}" "${EVID_DIR}"
[ -f "${PR_URL_FILE}" ] && printf ' - %s\n' "${PR_URL_FILE}"
[ -f "${OUTPUT_DIR}/fallback_reason.txt" ] && printf ' - %s\n' "${OUTPUT_DIR}/fallback_reason.txt"

# 失敗時の次アクション: output/restore_steps.md か output/next_cmd.txt をそのまま実行。
```

## Quickstart (PowerShell: Windows)
```powershell
# ===== 設定（ここだけ変更）=====
$REPO = "owner/repo"
$BASE = "main"
$ISSUE_NUMBER = "123"   # 任意。不要なら "" にする
$HEAD = (git rev-parse --abbrev-ref HEAD).Trim()

# ===== 共通設定 =====
$ROOT = "github/temp_gh"
$SAFE_HEAD = $HEAD -replace "/", "-"
if ($ISSUE_NUMBER) {
  $JOB_ID = "pr-issue-$ISSUE_NUMBER"
} else {
  $JOB_ID = "pr-$SAFE_HEAD"
}
$JOB_DIR = Join-Path $ROOT "jobs/$JOB_ID"
$OUTPUT_DIR = Join-Path $JOB_DIR "output"
$EVID_DIR = Join-Path $OUTPUT_DIR "evidence"
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR, $EVID_DIR | Out-Null

$PR_TITLE_FILE = Join-Path $OUTPUT_DIR "pr_title.txt"
$PR_BODY_FILE = Join-Path $OUTPUT_DIR "pr.md"
$DIFF_FILE = Join-Path $OUTPUT_DIR "changes.diff"
$RESTORE_FILE = Join-Path $OUTPUT_DIR "restore_steps.md"
$NEXT_CMD_FILE = Join-Path $OUTPUT_DIR "next_cmd.txt"
$PR_URL_FILE = Join-Path $OUTPUT_DIR "pr_url.txt"

# ===== 最小安全チェック =====
git status > (Join-Path $EVID_DIR "git_status.txt")
git diff --stat "$BASE..$HEAD" > (Join-Path $EVID_DIR "git_diff_stat_base_head.txt") 2> (Join-Path $EVID_DIR "git_diff_stat_error.log")

$BASE_SHA = (git merge-base "origin/$BASE" "$HEAD" 2>$null).Trim()
if (-not $BASE_SHA) {
  $BASE_SHA = (git merge-base "$BASE" "$HEAD" 2>$null).Trim()
}
if (-not $BASE_SHA) {
  $BASE_SHA = (git rev-parse "$HEAD~1" 2>$null).Trim()
}
if (-not $BASE_SHA) {
  $BASE_SHA = (git rev-parse "$HEAD").Trim()
}
Set-Content -LiteralPath (Join-Path $EVID_DIR "base_sha.txt") -Value $BASE_SHA -Encoding utf8

git diff "$BASE_SHA..$HEAD" > $DIFF_FILE

$TITLE_SEED = (git log -1 --pretty=%s 2>$null).Trim()
if (-not $TITLE_SEED) { $TITLE_SEED = "Update $HEAD" }
if ($ISSUE_NUMBER) {
  Set-Content -LiteralPath $PR_TITLE_FILE -Value "Issue #${ISSUE_NUMBER}: $TITLE_SEED" -Encoding utf8
} else {
  Set-Content -LiteralPath $PR_TITLE_FILE -Value "PR: $TITLE_SEED" -Encoding utf8
}

@"
# What
- Describe what changed.

# Why
- Describe why this change is needed.

# Evidence
- git status: `$EVID_DIR/git_status.txt`
- git diff --stat: `$EVID_DIR/git_diff_stat_base_head.txt`
- diff: `$DIFF_FILE`

# Impact
- Scope of affected components/files.

# Related Issue
$(if ($ISSUE_NUMBER) { "- Closes #$ISSUE_NUMBER" } else { "- (none)" })

# Checklist
- [ ] Title and body reviewed
- [ ] Evidence files attached
- [ ] Risk/impact documented
- [ ] Test results documented
"@ | Set-Content -LiteralPath $PR_BODY_FILE -Encoding utf8

@"
# Restore Steps (Offline -> Online)

1. Clone or open target repository.
2. Checkout base branch and create restore branch.
   - `git checkout $BASE`
   - `git pull --ff-only`
   - `git checkout -b restore/$SAFE_HEAD`
3. Apply diff from this job packet.
   - `git apply $DIFF_FILE`
4. Commit and push.
   - `git add -A`
   - `git commit -m "$(Get-Content -LiteralPath $PR_TITLE_FILE -Raw)"`
   - `git push -u origin restore/$SAFE_HEAD`
5. Create PR using saved title/body.
   - `gh pr create -R $REPO --base $BASE --head restore/$SAFE_HEAD --title "$(Get-Content -LiteralPath $PR_TITLE_FILE -Raw)" --body-file $PR_BODY_FILE`
"@ | Set-Content -LiteralPath $RESTORE_FILE -Encoding utf8

@"
# bash: online復旧後に1コマンドでPublish
REPO='$REPO'; BASE='$BASE'; HEAD='$HEAD'; JOB_DIR='$JOB_DIR'; git push -u origin "`$HEAD" && gh pr create -R "`$REPO" --base "`$BASE" --head "`$HEAD" --title "`$(cat "`$JOB_DIR/output/pr_title.txt")" --body-file "`$JOB_DIR/output/pr.md"

# PowerShell: online復旧後に1コマンドでPublish
`$REPO='$REPO'; `$BASE='$BASE'; `$HEAD='$HEAD'; `$JOB_DIR='$JOB_DIR'; git push -u origin `$HEAD; if (`$LASTEXITCODE -eq 0) { gh pr create -R `$REPO --base `$BASE --head `$HEAD --title (Get-Content -LiteralPath (Join-Path `$JOB_DIR 'output/pr_title.txt') -Raw).Trim() --body-file (Join-Path `$JOB_DIR 'output/pr.md') }
"@ | Set-Content -LiteralPath $NEXT_CMD_FILE -Encoding utf8

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

if (-not $IS_FALLBACK) {
  git push -u origin $HEAD > (Join-Path $EVID_DIR "git_push.log") 2>&1
  if ($LASTEXITCODE -eq 0) {
    $prUrl = gh pr create -R $REPO --base $BASE --head $HEAD --title (Get-Content -LiteralPath $PR_TITLE_FILE -Raw).Trim() --body-file $PR_BODY_FILE 2> (Join-Path $EVID_DIR "gh_pr_create_error.log")
    if ($LASTEXITCODE -eq 0) {
      Set-Content -LiteralPath $PR_URL_FILE -Value $prUrl -Encoding utf8
    } else {
      $IS_FALLBACK = $true
      $FALLBACK_REASON = "gh pr create failed"
    }
  } else {
    $IS_FALLBACK = $true
    $FALLBACK_REASON = "git push failed"
  }
}

if ($IS_FALLBACK) {
  Set-Content -LiteralPath (Join-Path $OUTPUT_DIR "fallback_reason.txt") -Value $FALLBACK_REASON -Encoding utf8
}

"job_id=$JOB_ID"
"generated:"
" - $PR_TITLE_FILE"
" - $PR_BODY_FILE"
" - $DIFF_FILE"
" - $RESTORE_FILE"
" - $NEXT_CMD_FILE"
" - $EVID_DIR"
if (Test-Path $PR_URL_FILE) { " - $PR_URL_FILE" }
if (Test-Path (Join-Path $OUTPUT_DIR "fallback_reason.txt")) { " - $(Join-Path $OUTPUT_DIR 'fallback_reason.txt')" }

# 失敗時の次アクション: output/restore_steps.md か output/next_cmd.txt をそのまま実行。
```

## オンラインPublish（push + gh pr create）
- 事前に `git status` と `git diff --stat <base..head>` を証跡に残す。
- PR作成は必ず `--title` と `--body-file` を使い、非対話で完走させる。
- 成功時は `output/pr_url.txt` にURLを保存する。

## オフライン回避（GitHubに触れない）
- `output/` は GitHub 非接続でも完成する。
  - `pr_title.txt`
  - `pr.md`
  - `changes.diff`
  - `restore_steps.md`
  - `next_cmd.txt`
- 後日別環境で `changes.diff` を適用し、`restore_steps.md` の手順で復旧してPublishする。

## 生成されるファイル
- `github/temp_gh/jobs/pr-<branch-or-issue>/output/pr_title.txt`
- `github/temp_gh/jobs/pr-<branch-or-issue>/output/pr.md`
- `github/temp_gh/jobs/pr-<branch-or-issue>/output/changes.diff`
- `github/temp_gh/jobs/pr-<branch-or-issue>/output/restore_steps.md`
- `github/temp_gh/jobs/pr-<branch-or-issue>/output/next_cmd.txt`
- `github/temp_gh/jobs/pr-<branch-or-issue>/output/evidence/`
- `github/temp_gh/jobs/pr-<branch-or-issue>/output/pr_url.txt`（オンライン成功時）
- `github/temp_gh/jobs/pr-<branch-or-issue>/output/fallback_reason.txt`（フォールバック時）
