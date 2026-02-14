<#
.SYNOPSIS
    Generate KiCad PR evidence (PDF/ERC/DRC) locally

.DESCRIPTION
    Generates outputs equivalent to Actions (kicad-pr-artifacts.yml):
    - Schematic PDF
    - ERC results (JSON)
    - DRC results (JSON, if pcb exists)

    Output: hw/out/
    Naming: Actions-compatible ({NAME}.pdf, {NAME}_erc_all.json, {NAME}_erc_error.json, {NAME}_drc.json)

.PARAMETER ProjectPath
    Path to KiCad project file (e.g., hw/hw.kicad_pro)

.EXAMPLE
    .\scripts\kicad\gen_evidence.ps1 -ProjectPath "hw/hw.kicad_pro"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to KiCad project file (e.g., hw/hw.kicad_pro)")]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

# --- Check kicad-cli ---
$kicadCli = Get-Command "kicad-cli" -ErrorAction SilentlyContinue
if (-not $kicadCli) {
    Write-Error @"
[ERROR] kicad-cli not found.
Install KiCad 8.0+ and ensure kicad-cli is in PATH.
(Enable 'Add to PATH' during KiCad installation, or add manually)
"@
    exit 1
}

Write-Host "[INFO] kicad-cli version: $(kicad-cli version)" -ForegroundColor Cyan

# --- Check project file ---
if (-not (Test-Path $ProjectPath)) {
    Write-Error "[ERROR] Project file not found: $ProjectPath"
    exit 1
}

$ProjectDir = Split-Path -Parent (Resolve-Path $ProjectPath)
$OutDir = Join-Path $ProjectDir "out"

# --- Create output directory ---
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    Write-Host "[INFO] Created output directory: $OutDir" -ForegroundColor Yellow
}

Write-Host "[INFO] Output directory: $OutDir" -ForegroundColor Cyan
Write-Host ""

# --- Enumerate schematic files ---
$SchFiles = Get-ChildItem -Path $ProjectDir -Filter "*.kicad_sch" | Sort-Object Name
if ($SchFiles.Count -eq 0) {
    Write-Warning "[WARN] No schematic files (*.kicad_sch) found: $ProjectDir"
    exit 0
}

Write-Host "[INFO] Target schematics: $($SchFiles.Count) file(s)" -ForegroundColor Cyan

$hasError = $false

foreach ($Sch in $SchFiles) {
    $Name = $Sch.BaseName
    Write-Host ""
    Write-Host "=== Processing: $Name ===" -ForegroundColor Green

    # --- PDF export ---
    $PdfPath = Join-Path $OutDir "$Name.pdf"
    Write-Host "  [PDF] Exporting..." -ForegroundColor Gray
    try {
        kicad-cli sch export pdf --output "$PdfPath" "$($Sch.FullName)" 2>&1 | Out-Null
        Write-Host "  [PDF] OK: $PdfPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "  [PDF] FAILED: $_"
        $hasError = $true
    }

    # --- ERC (all severities) ---
    $ErcAllPath = Join-Path $OutDir "${Name}_erc_all.json"
    Write-Host "  [ERC-ALL] Running..." -ForegroundColor Gray
    try {
        kicad-cli sch erc --format json --severity-all --output "$ErcAllPath" "$($Sch.FullName)" 2>&1 | Out-Null
        Write-Host "  [ERC-ALL] OK: $ErcAllPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "  [ERC-ALL] FAILED: $_"
        # Continue anyway - ERC can fail if there are violations
    }

    # --- ERC (errors only, gate) ---
    $ErcErrorPath = Join-Path $OutDir "${Name}_erc_error.json"
    Write-Host "  [ERC-ERROR] Running (gate)..." -ForegroundColor Gray
    $ercExitCode = 0
    try {
        # --exit-code-violations: non-zero exit if violations exist
        $output = kicad-cli sch erc --format json --severity-error --exit-code-violations --output "$ErcErrorPath" "$($Sch.FullName)" 2>&1
        $ercExitCode = $LASTEXITCODE
        if ($ercExitCode -ne 0) {
            Write-Warning "  [ERC-ERROR] VIOLATIONS FOUND (exit code: $ercExitCode): $ErcErrorPath"
            $hasError = $true
        }
        else {
            Write-Host "  [ERC-ERROR] PASS: $ErcErrorPath" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "  [ERC-ERROR] FAILED: $_"
        $hasError = $true
    }
}

# --- PCB files (DRC) ---
$PcbFiles = Get-ChildItem -Path $ProjectDir -Filter "*.kicad_pcb" -ErrorAction SilentlyContinue | Sort-Object Name
if ($PcbFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "[INFO] PCB file(s) detected: $($PcbFiles.Count) - Running DRC" -ForegroundColor Cyan

    foreach ($Pcb in $PcbFiles) {
        $Name = $Pcb.BaseName
        Write-Host ""
        Write-Host "=== DRC: $Name ===" -ForegroundColor Green

        $DrcPath = Join-Path $OutDir "${Name}_drc.json"
        Write-Host "  [DRC] Running..." -ForegroundColor Gray
        try {
            $output = kicad-cli pcb drc --format json --severity-all --exit-code-violations --output "$DrcPath" "$($Pcb.FullName)" 2>&1
            $drcExitCode = $LASTEXITCODE
            if ($drcExitCode -ne 0) {
                Write-Warning "  [DRC] VIOLATIONS FOUND (exit code: $drcExitCode): $DrcPath"
                # DRC violations are non-blocking (same as Actions)
            }
            else {
                Write-Host "  [DRC] PASS: $DrcPath" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "  [DRC] FAILED: $_"
            # DRC failures are non-blocking (same as Actions)
        }
    }
}
else {
    Write-Host ""
    Write-Host "[INFO] No PCB file (*.kicad_pcb) - Skipping DRC" -ForegroundColor Yellow
}

# --- Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Complete: $OutDir" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated files:" -ForegroundColor White
Get-ChildItem -Path $OutDir -File | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor Gray
}
Write-Host ""

if ($hasError) {
    Write-Host "[RESULT] FAIL - ERC errors detected. Fix and re-run." -ForegroundColor Red
    exit 1
}
else {
    Write-Host "[RESULT] PASS - All evidence generated successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Review contents of hw/out/" -ForegroundColor Gray
    Write-Host "  2. Confirm hw/out/ does not appear in git status" -ForegroundColor Gray
    Write-Host "  3. Attach evidence (PDF/ERC logs) to PR" -ForegroundColor Gray
    exit 0
}
