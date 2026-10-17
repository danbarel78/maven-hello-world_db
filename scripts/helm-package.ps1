<#
.SYNOPSIS
    Package the Helm chart into a .tgz whose file name follows the chart version.

.DESCRIPTION
    Reads the chart name and version from Chart.yaml and runs `helm package`,
    producing <OutputDir>/<ChartName>-<ChartVersion>.tgz.

.PARAMETER ChartPath
    Optional. Path to the Helm chart directory. Defaults to ../myapp/helm next to this script.

.PARAMETER OutputDir
    Optional. Directory for the packaged chart. Defaults to ../outputs/helm next to this script.

.EXAMPLE
    .\helm-package.ps1

.EXAMPLE
    .\helm-package.ps1 -ChartPath .\myapp\helm -OutputDir .\outputs\helm
#>
param(
    [Parameter()]
    [string]$ChartPath,

    [Parameter()]
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($ChartPath)) {
    $ChartPath = Join-Path (Join-Path $repoRoot "myapp") "helm"
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot "outputs\helm"
}

if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    throw "helm was not found on PATH."
}

$chartFile = Join-Path $ChartPath "Chart.yaml"
if (-not (Test-Path $chartFile)) {
    throw "Could not locate Chart.yaml at '$chartFile'"
}

# Parse name/version from Chart.yaml.
$chartName = $null
$chartVersion = $null
foreach ($line in Get-Content -Path $chartFile -Encoding UTF8) {
    if (-not $chartName -and $line -match '^name:\s*(\S+)')       { $chartName    = $Matches[1] }
    if (-not $chartVersion -and $line -match '^version:\s*(\S+)') { $chartVersion = $Matches[1] }
}

if ([string]::IsNullOrWhiteSpace($chartName) -or [string]::IsNullOrWhiteSpace($chartVersion)) {
    throw "Could not parse name/version from '$chartFile'"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Get-ChildItem -Path (Join-Path $OutputDir "$chartName-*.tgz") -ErrorAction SilentlyContinue | Remove-Item -Force

& helm package $ChartPath --destination $OutputDir | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "helm package failed with exit code $LASTEXITCODE"
}

Write-Output (Join-Path $OutputDir "$chartName-$chartVersion.tgz")
