<#
.SYNOPSIS
    Compute the release version for the CI/CD pipeline.

.DESCRIPTION
    Parses the Maven pom.xml to determine Major.Minor, then appends the
    supplied BuildId to produce a version string in the form Major.Minor.BuildId.

.PARAMETER BuildId
    Required. The build identifier appended after Major.Minor (e.g. GitHub run number).
    Omitting it fails immediately instead of prompting, so the script is safe to
    call non-interactively.

.PARAMETER PomPath
    Optional. Path to the pom.xml file (a folder containing pom.xml also works).
    Relative paths are resolved against the current directory. When omitted, the
    script probes the usual layouts: `<base>/myapp/pom.xml` and `<base>/pom.xml`,
    where `<base>` is this script's parent folder, the current folder and this
    script's own folder, in that order.

.EXAMPLE
    .\version.ps1 -BuildId 42
#>
param(
    [Parameter()]
    [string]$BuildId,

    [Parameter()]
    [string]$PomPath
)

$ErrorActionPreference = "Stop"

# Fail fast with a non-zero exit code rather than prompting for a missing value.
if ([string]::IsNullOrWhiteSpace($BuildId)) {
    throw "BuildId is required. Usage: .\version.ps1 -BuildId <value> [-PomPath <path>]"
}

# A bash-style "--name" token is not a PowerShell parameter. PowerShell would bind
# it positionally instead, so the typo would silently become the BuildId and push
# the real value into the pom path, failing later with a misleading message.
if ($BuildId.StartsWith("-")) {
    throw "'$BuildId' looks like a mis-typed parameter: it was bound to -BuildId. PowerShell uses a single dash, e.g. .\version.ps1 -BuildId 1"
}

# Locate this script's own folder without assuming anything about the caller's
# working directory. $PSScriptRoot is empty when the file content is executed
# instead of the file itself, so keep a fallback.
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir) -and $MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = (Get-Location).Path
}
$scriptParent = Split-Path -Parent $scriptDir
$cwd = (Get-Location).Path

# Return the full path of the first entry that is a pom.xml (or a folder holding
# one), or $null when nothing matches.
function Resolve-PomFile {
    param([string[]]$CandidatePath)

    foreach ($candidate in $CandidatePath) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        foreach ($leaf in @($candidate, (Join-Path $candidate "pom.xml"))) {
            if (Test-Path -LiteralPath $leaf -PathType Leaf) {
                return (Get-Item -LiteralPath $leaf).FullName
            }
        }
    }

    return $null
}

if (-not [string]::IsNullOrWhiteSpace($PomPath)) {
    # An explicit path is authoritative: never fall back to a different pom.
    $resolved = Resolve-PomFile @($PomPath)
    if (-not $resolved) {
        throw "Could not locate pom.xml at '$PomPath' (from '$cwd')"
    }
    $PomPath = $resolved
}
else {
    # The layout is not guaranteed: the repo root may sit above the script, the
    # pom may live next to the script, or the script may have been copied
    # elsewhere. Probe the well-known locations instead of trusting one guess,
    # preferring the documented "repo root with an app subfolder" layout.
    $bases = @($scriptParent, $cwd, $scriptDir) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    $candidates = @()
    foreach ($base in $bases) {
        $candidates += (Join-Path (Join-Path $base "myapp") "pom.xml")
    }
    foreach ($base in $bases) {
        $candidates += (Join-Path $base "pom.xml")
    }

    $PomPath = Resolve-PomFile $candidates
    if (-not $PomPath) {
        throw ("Could not locate pom.xml, so the project version cannot be read." +
            [Environment]::NewLine + [Environment]::NewLine +
            "Looked for:" + [Environment]::NewLine +
            (($candidates | ForEach-Object { "  $_" }) -join [Environment]::NewLine) +
            [Environment]::NewLine + [Environment]::NewLine +
            "Script folder:  $scriptDir" + [Environment]::NewLine +
            "Current folder: $cwd" + [Environment]::NewLine +
            "Pass -PomPath to point at the file explicitly.")
    }
}

[xml]$pom = Get-Content -LiteralPath $PomPath -Raw -Encoding UTF8

# The XML object model keeps the project's own <version> distinct from the
# <parent> one, so no parent-skipping pass is needed here.
$pomVersion = [string]$pom.Project.version
if ([string]::IsNullOrWhiteSpace($pomVersion)) {
    throw "No <version> element found in '$PomPath'"
}
$pomVersion = $pomVersion.Trim()

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
