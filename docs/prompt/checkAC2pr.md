```text
あなたは実行エージェント。PR作成は「ACゲートがALL PASSの時だけ」許可される。
入力は ISSUE_NUMBER のみ。判定対象は “ローカル差分（未コミット含む）”。
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

# ===== 1) ACチェック（必須）→ レポート出力 =====
$ISSUE = gh issue view $ISSUE_NUMBER --repo "$REPO" --json number,title,url,body -q .
$AC_REPORT = Join-Path $env:TEMP "ac_report_$ISSUE_NUMBER.txt"

# ここで Issue本文からACを抽出し、ローカル変更（git status --porcelain と必要ならファイル内容）を根拠に判定して、
# 必ず次の形式で $AC_REPORT に書き出すこと（Out-Fileで実際に作成せよ）：
# - 先頭に対象情報（repo/issue/url）
# - AC行は必ず `AC1: PASS` のように 1行1ACで出す（PASS/FAIL/UNKNOWNのみ）
# - 最終行は必ず `AC_GATE: PASS` か `AC_GATE: FAIL`
# - もしACが本文に無い場合は FAIL 扱いにして `AC_GATE: FAIL` にする（勝手にPR作らない）

# ===== 2) ゲート検証（機械的に / ファイル読み取りは1回だけ） =====
if (!(Test-Path $AC_REPORT)) {
  Write-Host "ACレポートが無い。PR作成中止。レポート: $AC_REPORT"
  exit 0
}

$txt = Get-Content -Raw $AC_REPORT

# FAIL/UNKNOWNが1つでもあれば中止
if ($txt -match ':\s+(FAIL|UNKNOWN)\b') {
  Write-Host "ACゲート不通過（FAIL/UNKNOWNあり）。PR作成中止。レポート: $AC_REPORT"
  exit 0
}
# AC行が1つも無い場合も中止（チェック未実施/出力不備）
if ($txt -notmatch '(?m)^AC\d+:\s+PASS$') {
  Write-Host "AC行が見つからない（出力不備）。PR作成中止。レポート: $AC_REPORT"
  exit 0
}
# 最終ゲートがPASSでなければ中止
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
$BODY = Join-Path $env:TEMP "pr_body_$ISSUE_NUMBER.md"
$T_filled | Out-File $BODY -Encoding utf8

# PR作成（base=main）
gh pr create --repo "$REPO" --base main --head "$BRANCH" --title "$TITLE" --body-file "$BODY"

# 出力
"AC_REPORT: $AC_REPORT"
"BRANCH:    $BRANCH"
"SHA:       $(git rev-parse HEAD)"
"PR:        $(gh pr view --repo "$REPO" --json url -q .url)"

