# Build and Test Script for DX.TOML
# Builds all projects and runs tests using the universal Build-DPROJ.ps1 script

param(
    [string]$Config = "Debug",
    [string]$Platform = "Win32",
    [switch]$SkipTests
)

function Write-InfoMsg($Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-SuccessMsg($Message) { Write-Host $Message -ForegroundColor Green }
function Write-WarningMsg($Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-ErrorMsg($Message) { Write-Host $Message -ForegroundColor Red }

Write-InfoMsg "========================================="
Write-InfoMsg "DX.TOML Build and Test"
Write-InfoMsg "========================================="
Write-Host ""

$BuildScript = Join-Path $PSScriptRoot "Build-DPROJ.ps1"

if (-not (Test-Path $BuildScript)) {
    Write-ErrorMsg "Universal build script not found: $BuildScript"
    exit 1
}

$TestAdapterProject = "Tests\toml-test-adapter\DX.TOML.TestAdapter.dproj"
$TestsProject = "Tests\DX.TOML.Tests.dproj"

$BuildFailed = $false

Write-WarningMsg "Building TestAdapter..."
& $BuildScript -ProjectFile $TestAdapterProject -Config $Config -Platform $Platform
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "TestAdapter build failed!"
    $BuildFailed = $true
}
Write-Host ""

Write-WarningMsg "Building Unit Tests..."
& $BuildScript -ProjectFile $TestsProject -Config $Config -Platform $Platform
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Unit Tests build failed!"
    $BuildFailed = $true
}
Write-Host ""

if ($BuildFailed) {
    Write-ErrorMsg "Build failed!"
    exit 1
}

Write-SuccessMsg "All builds completed successfully!"
Write-Host ""

if ($SkipTests) {
    Write-InfoMsg "Skipping tests (SkipTests flag set)"
    exit 0
}

Write-InfoMsg "========================================="
Write-InfoMsg "Running Unit Tests"
Write-InfoMsg "========================================="
Write-Host ""

$TestExe = "Win32\Debug\DX.TOML.Tests.exe"
if ($Config -eq "Release") {
    $TestExe = "Win32\Release\DX.TOML.Tests.exe"
}

if (Test-Path $TestExe) {
    Write-WarningMsg "Executing: $TestExe"
    Write-Host ""
    & $TestExe
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-SuccessMsg "Unit tests passed!"
        Write-Host ""
    } else {
        Write-Host ""
        Write-ErrorMsg "Unit tests failed!"
        Write-Host ""
        exit 1
    }
} else {
    Write-ErrorMsg "Test executable not found: $TestExe"
    exit 1
}

Write-InfoMsg "========================================="
Write-InfoMsg "Running toml-test Suite"
Write-InfoMsg "========================================="
Write-Host ""

$TomlTest = "C:\tools\toml-test.exe"
$Adapter = "Tests\toml-test-adapter\DX.TOML.TestAdapter.exe"

if (-not (Test-Path $TomlTest)) {
    Write-WarningMsg "toml-test not found at: $TomlTest"
    Write-WarningMsg "Skipping toml-test suite"
    exit 0
}

if (-not (Test-Path $Adapter)) {
    Write-ErrorMsg "Test adapter not found: $Adapter"
    exit 1
}

Write-WarningMsg "Running toml-test..."
Write-Host ""
& $TomlTest $Adapter
Write-Host ""

if ($LASTEXITCODE -eq 0) {
    Write-SuccessMsg "toml-test completed!"
} else {
    Write-WarningMsg "toml-test completed with exit code: $LASTEXITCODE"
}

Write-Host ""
Write-InfoMsg "========================================="
Write-SuccessMsg "Build and Test Complete!"
Write-InfoMsg "========================================="
