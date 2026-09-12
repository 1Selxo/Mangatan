Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
    @'
Build the Windows app and open it by default.

Usage:
  .\scripts\build_windows.ps1 [debug|profile|release] [options]

Options:
  --debug       Build a debug app. This is the default.
  --profile     Build a profile app.
  --release     Build a release app.
  --clean       Run flutter clean before building.
  --no-open     Build only; do not open the app afterward.
  --open        Open the app after building. This is the default.
  -h, --help    Show this help text.

Examples:
  .\scripts\build_windows.ps1
  .\scripts\build_windows.ps1 --release
  .\scripts\build_windows.ps1 --clean --no-open

Extra Flutter build flags can be passed after --:
  .\scripts\build_windows.ps1 --release -- --verbose
'@
}

function Fail([string]$Message) {
    throw "[windows-build] error: $Message"
}

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail "command failed with exit code $LASTEXITCODE`: $Command $($Arguments -join ' ')"
    }
}

function Add-ToPath([string]$Directory) {
    if ([string]::IsNullOrWhiteSpace($Directory) -or -not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return $false
    }

    if (($env:PATH -split ';') -notcontains $Directory) {
        $env:PATH = "$Directory;$env:PATH"
        return $true
    }

    return $false
}

$buildMode = 'debug'
$openApp = $true
$cleanFirst = $false
$flutterArgs = @()
$passThrough = $false

foreach ($argument in $args) {
    if ($passThrough) {
        $flutterArgs += $argument
        continue
    }

    switch -Regex ($argument) {
        '^--$' { $passThrough = $true }
        '^-{0,2}(debug|profile|release)$' { $buildMode = $Matches[1].ToLowerInvariant() }
        '^--?open$' { $openApp = $true }
        '^--?no-open$' { $openApp = $false }
        '^--?clean$' { $cleanFirst = $true }
        '^(-h|--?help)$' { Show-Usage; exit 0 }
        default { Fail "unknown option: $argument" }
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoRoot

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
foreach ($userPathEntry in ($userPath -split ';')) {
    $null = Add-ToPath $userPathEntry
}

if ($env:OS -ne 'Windows_NT') {
    Fail 'Windows builds must be run on Windows.'
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutterCommand) {
    Fail 'flutter was not found on PATH.'
}

$flutterExecutable = $flutterCommand.Source
if ([string]::IsNullOrWhiteSpace($flutterExecutable)) {
    $flutterExecutable = $flutterCommand.Definition
}

$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if ($null -eq (Get-Command rustup.exe -ErrorAction SilentlyContinue) -and
    (Test-Path -LiteralPath (Join-Path $cargoBin 'rustup.exe') -PathType Leaf)) {
    if (Add-ToPath $cargoBin) {
        Write-Host "[windows-build] Added Rust to PATH: $cargoBin"
    }
}

if ($null -eq (Get-Command rustup.exe -ErrorAction SilentlyContinue)) {
    Fail 'rustup was not found on PATH. Install Rust through rustup and restart PowerShell.'
}

$visualStudioRoot = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio'
$cmakeCommand = Get-Command cmake.exe -ErrorAction SilentlyContinue
if ($null -eq $cmakeCommand) {
    $cmakeCandidate = Get-ChildItem -LiteralPath $visualStudioRoot -Filter 'cmake.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\Common7\\IDE\\CommonExtensions\\Microsoft\\CMake\\CMake\\bin\\cmake\.exe$' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if ($null -ne $cmakeCandidate) {
        $cmakeBin = Split-Path -Parent $cmakeCandidate.FullName
        if (Add-ToPath $cmakeBin) {
            Write-Host "[windows-build] Added Visual Studio CMake to PATH: $cmakeBin"
        }
        $cmakeCommand = Get-Command cmake.exe -ErrorAction SilentlyContinue
    }
}

if ($null -eq $cmakeCommand) {
    Fail 'cmake.exe was not found on PATH or in Visual Studio. Install the CMake tools for Windows component.'
}

if ($null -eq (Get-Command nuget.exe -ErrorAction SilentlyContinue)) {
    Fail 'nuget.exe was not found on PATH. Install the NuGet CLI and add its directory to PATH.'
}

$atlHeader = Get-ChildItem -LiteralPath $visualStudioRoot -Filter 'atlstr.h' -File -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($null -eq $atlHeader) {
    Fail 'Visual Studio C++ ATL is required (atlstr.h). Add the C++ ATL component to the Desktop development with C++ workload.'
}

$requiredSubmoduleFiles = @(
    'third_party/hoshidicts/CMakeLists.txt',
    'third_party/hoshidicts/external/glaze/CMakeLists.txt',
    'third_party/hoshidicts/external/zstd/CMakeLists.txt',
    'third_party/hoshidicts/external/unordered_dense/CMakeLists.txt',
    'third_party/hoshidicts/external/libdeflate/CMakeLists.txt',
    'third_party/hoshidicts/external/utf8proc/CMakeLists.txt',
    'third_party/hoshidicts/external/utfcpp/source/utf8.h',
    'third_party/hoshidicts/external/xxHash/xxhash.h'
)
foreach ($submoduleFile in $requiredSubmoduleFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $submoduleFile) -PathType Leaf)) {
        Fail 'Git submodules are not initialized. Run: git submodule update --init --recursive'
    }
}

if ([string]::IsNullOrWhiteSpace($env:PUB_CACHE)) {
    $env:PUB_CACHE = Join-Path $repoRoot '.pub-cache'
    Write-Host "[windows-build] Using project-local Pub cache: $env:PUB_CACHE"
}

$configuration = switch ($buildMode) {
    'debug' { 'Debug' }
    'profile' { 'Profile' }
    'release' { 'Release' }
    default { Fail "unsupported build mode: $buildMode" }
}

if ($cleanFirst) {
    Write-Host '[windows-build] Cleaning Flutter build output'
    Invoke-Checked $flutterExecutable @('clean')
}

Write-Host "[windows-build] Building Windows $buildMode app"
$buildArguments = @('build', 'windows', "--$buildMode") + $flutterArgs
Invoke-Checked $flutterExecutable $buildArguments

$binaryName = 'mangayomi'
$cmakePath = Join-Path $repoRoot 'windows/CMakeLists.txt'
$binaryNameMatch = Select-String -LiteralPath $cmakePath -Pattern '^\s*set\(BINARY_NAME\s+"([^"]+)"\)' |
    Select-Object -First 1
if ($null -ne $binaryNameMatch) {
    $binaryName = $binaryNameMatch.Matches[0].Groups[1].Value
}

$runnerDirectory = Join-Path $repoRoot "build/windows/x64/runner/$configuration"
$executablePath = Join-Path $runnerDirectory "$binaryName.exe"
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    Fail "built app was not found: $executablePath"
}

Write-Host "[windows-build] Built $executablePath"

if ($openApp) {
    Write-Host '[windows-build] Opening app'
    Start-Process -FilePath $executablePath -WorkingDirectory $runnerDirectory
}
