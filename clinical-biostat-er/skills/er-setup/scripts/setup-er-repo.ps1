param(
    [string]$Root = ".",
    [ValidateSet("global", "project", "both")]
    [string]$ClaudeTarget = "global",
    [ValidateSet("windows", "current", "mac", "linux")]
    [string]$VscodeRPlatform = "current",
    [switch]$NoConfigureVscode,
    [switch]$NoCheckRuntimes,
    [switch]$NoBranchCheck,
    [switch]$InstallMissingRPackages,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Resolve-Python {
    $candidates = @("python3", "python")
    foreach ($candidate in $candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }
    return $null
}

$python = Resolve-Python
if (-not $python) {
    Write-Host "[ERROR] Python was not found on PATH."
    Write-Host "Install Python from https://www.python.org/downloads/ or with winget:"
    Write-Host "  winget install Python.Python.3.12"
    Write-Host "Then re-run this setup command from the repo root."
    exit 1
}

$scriptPath = Join-Path $PSScriptRoot "setup_er_repo.py"
$argsList = @(
    $scriptPath,
    "--root", $Root,
    "--claude-target", $ClaudeTarget,
    "--vscode-r-platform", $VscodeRPlatform
)

if ($NoConfigureVscode) { $argsList += "--no-configure-vscode" }
if ($NoCheckRuntimes) { $argsList += "--no-check-runtimes" }
if ($NoBranchCheck) { $argsList += "--no-branch-check" }
if ($InstallMissingRPackages) { $argsList += "--install-missing-r-packages" }
if ($DryRun) { $argsList += "--dry-run" }

& $python @argsList
exit $LASTEXITCODE
