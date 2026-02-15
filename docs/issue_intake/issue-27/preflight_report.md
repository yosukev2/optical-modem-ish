# Preflight Report: Issue #27

- Repo: yosukev2/optical-modem-ish
- Branch: chore/issue-27-intake
- Worktree: .worktrees/issue-27-intake
- Generated: 2026-02-15 10:41:43 +09:00
- Overall: **PASS**

| ID | Check | Status | Evidence | Notes |
|---|---|---|---|---|
| 5-1 | SoT exists: docs/hw/nets.yml | **OK** | docs/hw/nets.yml | required file found |
| 5-1 | SoT exists: docs/hw/interface_contract.yml | **OK** | docs/hw/interface_contract.yml | required file found |
| 5-1 | SoT exists: docs/hw/circuit_synth_policy.md | **OK** | docs/hw/circuit_synth_policy.md | required file found |
| 5-2 | SoT references in docs | **OK** | docs\kicad_llm_workflow.md:69:正本: `docs/hw/nets.yml`（この節は運用説明）。; docs\kicad_git_workflow.md:21:    nets.yml # ネット名辞書の正本（canonical）; docs\kicad_git_workflow.md:22:    interface_contract.yml # Step間I/F契約の正本 | docs側に参照導線あり |
| 5-3 | ERC changed gate script exists | **OK** | erc_changed_gate.sh | gate script found |
| 5-4 | Workflow calls erc_changed_gate | **OK** | .github/workflows\kicad-pr-artifacts.yml:8:      - "scripts/ci/erc_changed_gate.sh"; .github/workflows\kicad-pr-artifacts.yml:54:          bash scripts/ci/erc_changed_gate.sh "$BASE_SHA" "$HEAD_SHA" | workflow integration found |
| 5-5 | Dry-run erc_changed_gate at BASE=HEAD | **OK** | 2897331 | 差分0件で成功終了 |
| 5-6 | kicad-cli availability | **NOTE** | 9.0.6 | ローカル再現で利用可能（参考情報） |

## Dry-run output (erc_changed_gate)
```text
erc_changed_gate: base_sha=2897331b888ab61c867cedb7831514a847db5483 head_sha=2897331b888ab61c867cedb7831514a847db5483
erc_changed_gate: no changed schematics under hw/*.kicad_sch, skip.
```

## 判定
- Preflight PASS。Step1 extract_interface へ進行可能。
