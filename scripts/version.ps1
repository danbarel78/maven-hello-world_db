<#
.SYNOPSIS
    Compute the release version for the CI/CD pipeline.

.DESCRIPTION
    Parses the Maven pom.xml to determine Major.Minor, then appends the
    supplied BuildId to produce a version string in the form Major.Minor.BuildId.

.PARAMETER BuildId
    Required. The build identifier appended after Major.Minor (e.g. GitHub run number).

.PARAMETER PomPath
    Optional. Path to the pom.xml file. Defaults to myapp/pom.xml next to this script.

.EXAMPLE
    .\version.ps1 -BuildId 42
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$BuildId,

    [Parameter()]
    [string]$PomPath
)

$ErrorActionPreference = "Stop"

# Resolve default pom path relative to this script's folder (../myapp/pom.xml).
if ([string]::IsNullOrWhiteSpace($PomPath)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $PomPath = Join-Path (Join-Path $repoRoot "myapp") "pom.xml"
}

if (-not (Test-Path $PomPath)) {
    throw "Could not locate pom.xml at '$PomPath'"
}

[xml]$pom = Get-Content -Path $PomPath -Encoding UTF8
$pomVersion = $pom.Project.version
if ([string]::IsNullOrWhiteSpace($pomVersion)) {
    $pomVersion = $pom.project.version
}

if ([string]::IsNullOrWhiteSpace($pomVersion)) {
    throw "No <version> element found in '$PomPath'"
}

# Strip Maven classifier/suffix such as -SNAPSHOT to leave only Major.Minor.
$stripped = ($pomVersion -split '-')[0]

# Validate that we have at least two numeric segments.
$segments = $stripped -split '\.'
if ($segments.Count -lt 2) {
    throw "Pom version '$pomVersion' is not in Major.Minor format"
}

[int]$major = $null
[int]$minor = $null
if (-not [int]::TryParse($segments[0], [ref]$major)) {
    throw "Major version segment '$($segments[0])' is not numeric"
}
if (-not [int]::TryParse($segments[1], [ref]$minor)) {
    throw "Minor version segment '$($segments[1])' is not numeric"
}

$version = "$major.$minor.$BuildId"
Write-Output $version
