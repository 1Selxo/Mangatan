param(
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$server = Join-Path $repo 'third_party\mihon_server'
if (-not $env:JAVA_HOME) {
    throw 'JAVA_HOME must point to JDK 21 or newer.'
}
$java = Join-Path $env:JAVA_HOME 'bin\java.exe'
$jlink = Join-Path $env:JAVA_HOME 'bin\jlink.exe'
if (-not (Test-Path $java) -or -not (Test-Path $jlink)) {
    throw 'JAVA_HOME must provide java.exe and jlink.exe.'
}
$versionText = (& $java -version 2>&1 | Select-Object -First 1) -join ''
if ($versionText -notmatch 'version "(?<major>\d+)') {
    throw "Could not determine Java version from: $versionText"
}
if ([int]$Matches.major -lt 21) {
    throw "JDK 21 or newer is required; found $($Matches.major)."
}

$outputPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Output))
if (Test-Path $outputPath) { Remove-Item -Recurse -Force $outputPath }
New-Item -ItemType Directory -Force $outputPath | Out-Null

Push-Location $server
try {
    & .\gradlew.bat :server:clean :server:shadowJar --no-daemon --stacktrace
    if ($LASTEXITCODE -ne 0) { throw "Gradle failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$jars = @(Get-ChildItem (Join-Path $server 'server\build\MExtensionServer-*.jar') -File)
if ($jars.Count -ne 1) {
    throw "Expected exactly one server JAR, found $($jars.Count)."
}
# Keep the Gradle archive name; see the matching comment in the bash script. The
# `vX.Y.Z` in the basename is what the app parses for the installed version.
$serverJar = Join-Path $outputPath $jars[0].Name
Copy-Item $jars[0].FullName $serverJar
Copy-Item (Join-Path $server 'LICENSE') (Join-Path $outputPath 'M-Extension-Server-LICENSE.txt')
Copy-Item (Join-Path $server 'README.md') (Join-Path $outputPath 'M-Extension-Server-README.md')
$newPipe = Join-Path $repo 'third_party\newpipe_extractor'
Copy-Item (Join-Path $newPipe 'LICENSE') (Join-Path $outputPath 'NewPipe-Extractor-LICENSE.txt')
Copy-Item (Join-Path $newPipe 'VENDORED.md') (Join-Path $outputPath 'NewPipe-Extractor-SOURCE.txt')
# See the matching comment in the bash script: the shaded JAR carries more than
# MPL/GPL code, and logback ships no license text of its own.
Copy-Item (Join-Path $server 'BUNDLED_NOTICES.md') (Join-Path $outputPath 'THIRD_PARTY_NOTICES.md')

$modules = @(
    'java.base','java.compiler','java.datatransfer','java.desktop','java.instrument',
    'java.logging','java.management','java.naming','java.prefs','java.scripting','java.se',
    'java.security.jgss','java.security.sasl','java.sql','java.transaction.xa','java.xml',
    'jdk.attach','jdk.crypto.ec','jdk.jdi','jdk.management','jdk.net','jdk.unsupported',
    'jdk.unsupported.desktop','jdk.zipfs','jdk.accessibility'
) -join ','
& $jlink --add-modules $modules --output (Join-Path $outputPath 'jre') `
    --strip-debug --no-man-pages --no-header-files --compress=zip-6
if ($LASTEXITCODE -ne 0) { throw "jlink failed with exit code $LASTEXITCODE" }
if (-not (Test-Path (Join-Path $outputPath 'jre\bin\java.exe'))) {
    throw 'The bundled JRE is missing java.exe.'
}
Write-Host "Built vendored Mihon server bundle at $outputPath"
Write-Host "Server JAR: $serverJar"
