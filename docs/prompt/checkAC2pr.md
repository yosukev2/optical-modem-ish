あなたは実行エージェント。PR作成は「ACゲートがALL PASSの時だけ」許可される。
入力は ISSUE_NUMBER のみ。判定対象は “ローカル差分（未コミット含む・未追跡も含む）”。
禁止：Issue更新、rebase/merge、ファイル改変（レポート/PR本文の一時ファイル作成はOK）。
テンプレ必須：.github/pull_request_template.md が無ければPR作成しない。

ISSUE_NUMBER=<ここに番号>

# ===== 共通前提 =====
$ErrorActionPreference = "Stop"
gh auth status
$REPO = gh repo view --json nameWithOwner -q .nameWithOwner
git status -sb
if (!(Test-Path ".github/pull_request_template.md")) { Write-Host "テンプレ無し。PR作成中止"; exit 0 }

# ★差分判定：未追跡も含めて検出（git diff ではなく status を使う）
$porcelain = (git status --porcelain) | Out-String
if ([string]::IsNullOrWhiteSpace($porcelain)) { Write-Host "変更なし（未追跡も含めて0）。PR作成中止"; exit 0 }

# ★(B) TEMPは使わない：ワークスペース内 .codex/ に出力
$CODIR = Join-Path (Get-Location) ".codex"
New-Item -ItemType Directory -Force -Path $CODIR | Out-Null
$AC_REPORT = Join-Path $CODIR "ac_report_$ISSUE_NUMBER.txt"
$BODY      = Join-Path $CODIR "pr_body_$ISSUE_NUMBER.md"

# ===== 1) ACチェック（必須）→ レポート出力 =====
$ISSUE = gh issue view $ISSUE_NUMBER --repo "$REPO" --json number,title,url,body -q .
$lines = @()
$lines += "repo: $REPO"
$lines += "issue: #$($ISSUE.number)"
$lines += "url: $($ISSUE.url)"
$lines += ""
# ここで Issue本文からACを抽出し、ローカル変更（git status --porcelain と必要ならファイル内容）を根拠に判定して、
# 必ず次の形式の行を $lines に追加すること：
# - AC行は `AC1: PASS` のように 1行1AC（PASS/FAIL/UNKNOWNのみ）
# - 最終行は `AC_GATE: PASS` か `AC_GATE: FAIL`
# - もしACが本文に無い場合は FAIL 扱い（= AC_GATE: FAIL）
#
# その上で、$txt を作って Out-File で $AC_REPORT を作成せよ。

$txt = ($lines -join "`n")
$txt | Out-File -FilePath $AC_REPORT -Encoding utf8

# ===== 2) ゲート検証（機械的に / (C) 後続の別コマンドを出さず、この塊で完結） =====
# ★読み直しGet-Contentは使わず、今ある $txt をそのまま検証する
if ($txt -match ':\s+(FAIL|UNKNOWN)\b') {
  Write-Host "ACゲート不通過（FAIL/UNKNOWNあり）。PR作成中止。レポート: $AC_REPORT"
  exit 0
}
if ($txt -notmatch '(?m)^AC\d+:\s+PASS$') {
  Write-Host "AC行が見つからない（出力不備/未実施）。PR作成中止。レポート: $AC_REPORT"
  exit 0
}
if ($txt -notmatch '(?m)^AC_GATE:\s+PASS$') {
  Write-Host "AC_GATEがPASSではない。PR作成中止。レポート: $AC_REPORT"
  exit 0
}

# ===== 3) ここから先は“全PASS確定”した場合のみ =====
$ISSUE_TITLE = $ISSUE.title
# slugは英数字とハイフンのみ、空白→ハイフン、40文字程度に短縮
$SLUG = <Codexが生成>
$BRANCH = "m0/issue-$ISSUE_NUMBER-$SLUG"
$TITLE  = "M0 #$ISSUE_NUMBER: $ISSUE_TITLE"

# ブランチ作成/移動
if (git show-ref --verify --quiet "refs/heads/$BRANCH") { git switch $BRANCH } else { git switch -c $BRANCH }

# add/commit/push
git add -A
$staged = (git diff --cached --name-status) | Out-String
if ([string]::IsNullOrWhiteSpace($staged)) { Write-Host "ステージが空。PR作成中止"; exit 0 }
git commit -m "$TITLE"
git push -u origin $BRANCH

# PR本文（テンプレ埋め）
$T = Get-Content -Raw ".github/pull_request_template.md"
# テンプレ見出しは維持、置換できなければ各見出し直下に追記でOK：
# What: staged変更要約
# Why: Issueタイトル要約
# Evidence: "AC: PASS (gated)" + "ACレポート: $AC_REPORT"
# Impact: 推定でチェック
# 関連Issue: "Closes #<ISSUE_NUMBER>"
$T_filled | Out-File $BODY -Encoding utf8

# PR作成（base=main）
gh pr create --repo "$REPO" --base main --head "$BRANCH" --title "$TITLE" --body-file "$BODY"

# 出力
"AC_REPORT: $AC_REPORT"
"PR_BODY:   $BODY"
"BRANCH:    $BRANCH"
"SHA:       $(git rev-parse HEAD)"
"PR:        $(gh pr view --repo "$REPO" --json url -q .url)"
``
::contentReference[oaicite:0]{index=0}
