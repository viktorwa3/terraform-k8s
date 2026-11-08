# Local lint; missing tools are skipped (CI runs them).
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$failed = @()
$skipped = @()

function Invoke-Check([string]$name, [string]$tool, [string]$dir, [scriptblock]$body) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { $script:skipped += $name; Write-Host "SKIP  $name ($tool not installed)"; return }
    Push-Location (Join-Path $root $dir)
    try {
        $out = & $body 2>&1
        if ($LASTEXITCODE -ne 0) { $script:failed += $name; Write-Host "FAIL  $name"; $out | Select-Object -Last 30 | ForEach-Object { Write-Host "      $_" } }
        else { Write-Host "OK    $name" }
    } finally { Pop-Location }
}

Invoke-Check 'terraform fmt' terraform 'aws' { terraform fmt -check -recursive -diff }
Invoke-Check 'terraform validate' terraform 'aws' { terraform init -backend=false -input=false | Out-Null; terraform validate -no-color }
Invoke-Check 'tflint' tflint 'aws' { tflint --init | Out-Null; tflint --recursive --format compact }
Invoke-Check 'yamllint' yamllint '.' { yamllint ansible/ gitops/ }
Invoke-Check 'ansible-lint' ansible-lint 'ansible' { ansible-lint }
Invoke-Check 'actionlint' actionlint '.' { actionlint }

# Verify play expects root + every app.
$apps = (Get-ChildItem (Join-Path $root 'gitops/apps') -Filter *.yaml).Count
$expected = [int]((Select-String -Path (Join-Path $root 'ansible/group_vars/all.yml') -Pattern '^gitops_expected_apps:\s*(\d+)').Matches[0].Groups[1].Value)
if ($expected -ne $apps + 1) { $failed += 'gitops_expected_apps'; Write-Host "FAIL  gitops_expected_apps is $expected, gitops/apps has $apps apps (+ root = $($apps + 1))" }
else { Write-Host "OK    gitops_expected_apps ($expected)" }

if ($skipped) { Write-Host "Skipped locally (CI only): $($skipped -join ', ')" }
if ($failed) { Write-Host "CHECK FAILED: $($failed -join ', ')"; exit 1 }
Write-Host 'CHECK PASSED'
