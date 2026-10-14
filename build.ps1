<#
.SYNOPSIS
    Builds the myapp project and produces a versioned, runnable JAR with a manifest.

.DESCRIPTION
    1. Reads the project version from `myapp/pom.xml` if no `-Version` is supplied.
    2. Creates `outputs/<Version>/` and writes a `META-INF/MANIFEST.MF` file there.
    3. Builds `outputs/<Version>/myapp-<Version>.jar` using either:
       - Java toolchain commands (`javac` + `jar`) — **default**
       - Maven (`mvn clean package`)

.PARAMETER Version
    Optional. Version string used for the output folder and JAR file name.
    Defaults to the `<version>` declared in `myapp/pom.xml`.

.PARAMETER BuildMode
    Optional. Choose `java` or `maven`. Defaults to `java`.

.PARAMETER JavaRelease
    Optional. Target Java release for `javac --release`. Defaults to 21.

.PARAMETER MavenCommand
    Optional. Maven executable name or full path. Only used when `-BuildMode maven` is set.

.EXAMPLE
    .\build.ps1

.EXAMPLE
    .\build.ps1 -Version v11

.EXAMPLE
    .\build.ps1 -Version v11 -BuildMode maven

.EXAMPLE
    .\build.ps1 -Version v11 -BuildMode maven -MavenCommand "C:\tools\maven\bin\mvn.cmd"
#>

param(
    [Parameter()]
    [string]$Version,

    [Parameter()]
    [ValidateSet("java", "maven")]
    [string]$BuildMode = "java",

    [Parameter()]
    [string]$JavaRelease = "21",

    [Parameter()]
    [string]$MavenCommand = "mvn"
)

$ErrorActionPreference = "Stop"

# Resolve paths relative to the script location.
$repoRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$appDir     = Join-Path $repoRoot "myapp"
$pomPath    = Join-Path $appDir "pom.xml"
$srcRoot    = Join-Path $appDir "src\main\java"
$mainSource = Join-Path $srcRoot "com\myapp\App.java"
$mainClass  = "com.myapp.App"

# Sanity checks.
if (-not (Test-Path $pomPath)) {
    throw "Could not find POM file at $pomPath"
}

# Determine version from pom.xml if not supplied.
if ([string]::IsNullOrWhiteSpace($Version)) {
    [xml]$pomDoc = Get-Content -Path $pomPath -Encoding UTF8
    $pomVersion  = $pomDoc.Project.version
    if ([string]::IsNullOrWhiteSpace($pomVersion)) {
        # Some POMs use lowercase element names.
        $pomVersion = $pomDoc.project.version
    }
    $Version = $pomVersion
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "Version could not be determined. Pass -Version explicitly."
}

# Prepare the output directory.
$outputsDir   = Join-Path $repoRoot "outputs"
$versionDir   = Join-Path $outputsDir $Version
$manifestDir  = Join-Path $versionDir "META-INF"
$manifestPath = Join-Path $manifestDir "MANIFEST.MF"
$jarName      = "myapp-$Version.jar"
$jarPath      = Join-Path $versionDir $jarName
$classesDir   = Join-Path $versionDir "classes"

if (Test-Path $versionDir) {
    Remove-Item -Path $versionDir -Recurse -Force | Out-Null
}
New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null

# Write the shared manifest.
$manifestContent = @(
    "Manifest-Version: 1.0"
    "Main-Class: $mainClass"
    "Implementation-Title: myapp"
    "Implementation-Version: $Version"
    ""
) -join "`r`n"

[System.IO.File]::WriteAllText($manifestPath, $manifestContent, [System.Text.Encoding]::ASCII)
Write-Host "Manifest written to: $manifestPath" -ForegroundColor Cyan

function Assert-ToolAvailable {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Required tool '$Name' was not found on PATH. Ensure a JDK is installed and on PATH."
    }
    return $cmd
}

if ($BuildMode -eq "java") {
    # -------------------------------------------------------------------------
    # Build with Java toolchain (javac + jar)
    # -------------------------------------------------------------------------
    $javacTool = Assert-ToolAvailable -Name "javac"
    $jarTool   = Assert-ToolAvailable -Name "jar"

    Write-Host "`nBuilding with Java toolchain (release $JavaRelease)..." -ForegroundColor Cyan
    Write-Host "  javac: $($javacTool.Source)" -ForegroundColor Gray
    Write-Host "  jar:   $($jarTool.Source)" -ForegroundColor Gray

    New-Item -ItemType Directory -Path $classesDir -Force | Out-Null

    & $javacTool --release $JavaRelease -d $classesDir $mainSource
    if ($LASTEXITCODE -ne 0) {
        throw "javac compilation failed with exit code $LASTEXITCODE"
    }

    & $jarTool cfm $jarPath $manifestPath -C $classesDir .
    if ($LASTEXITCODE -ne 0) {
        throw "jar packaging failed with exit code $LASTEXITCODE"
    }
}
else {
    # -------------------------------------------------------------------------
    # Build with Maven
    # -------------------------------------------------------------------------
    $mvnResolved = Get-Command $MavenCommand -ErrorAction SilentlyContinue
    if (-not $mvnResolved) {
        throw "Maven executable '$MavenCommand' was not found on PATH. Install Maven or pass -MavenCommand with the full path."
    }
    Write-Host "`nBuilding with Maven: $($mvnResolved.Source)" -ForegroundColor Cyan

    Push-Location -Path $appDir
    try {
        & $MavenCommand clean package
        if ($LASTEXITCODE -ne 0) {
            throw "Maven build failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }

    $mavenClassesDir = Join-Path $appDir "target\classes"
    if (-not (Test-Path $mavenClassesDir)) {
        throw "Compiled classes directory not found: $mavenClassesDir"
    }

    $jarTool = Assert-ToolAvailable -Name "jar"

    & $jarTool cfm $jarPath $manifestPath -C $mavenClassesDir .
    if ($LASTEXITCODE -ne 0) {
        throw "jar packaging failed with exit code $LASTEXITCODE"
    }
}

# Summary.
Write-Host "`nBuild complete [$BuildMode mode]." -ForegroundColor Green
Write-Host "  Version directory : $versionDir"
Write-Host "  Manifest          : $manifestPath"
Write-Host "  Runnable JAR      : $jarPath"
Write-Host "`nRun with:"
Write-Host "  java -jar `"$jarPath`"" -ForegroundColor Yellow
