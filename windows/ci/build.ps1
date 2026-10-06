[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PgRoot,

    [Parameter(Mandatory = $true)]
    [string]$UpstreamDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
$vswhere = Join-Path $programFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe was not found: $vswhere"
}

$vsRoot = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1).Trim()
if ([string]::IsNullOrWhiteSpace($vsRoot)) {
    throw "Visual Studio with the C++ x64 toolchain was not found."
}

$vsDevCmd = Join-Path $vsRoot "Common7\Tools\VsDevCmd.bat"
if (-not (Test-Path $vsDevCmd)) {
    throw "VsDevCmd.bat was not found: $vsDevCmd"
}

$controlPath = Join-Path $UpstreamDir "pg_qualstats.control"
$sourcePath = Join-Path $UpstreamDir "pg_qualstats.c"
$control = Get-Content $controlPath -Raw
if ($control -notmatch "default_version\s*=\s*'([^']+)'") {
    throw "Could not determine pg_qualstats version from pg_qualstats.control."
}
$version = $Matches[1]
if ($version -ne "2.1.4") {
    throw "Unexpected pg_qualstats version: $version"
}

$source = Get-Content $sourcePath -Raw

# pg_qualstats 2.1.4 added a compatibility macro for PostgreSQL < 19:
#   #define ShmemInitHash(n, nelem, i, f) ...
# Later in pgqs_shmem_startup(), a preprocessor #if/#else appears inside a
# ShmemInitHash() argument list. GCC accepts that layout, but MSVC treats '#'
# as an invalid token while collecting macro arguments. Preserve the exact
# flags while moving the conditional outside the macro invocation in the
# disposable CI checkout.
$hashCallOld = @'
	pgqs_query_examples_hash = ShmemInitHash("pg_qualqueryexamples_hash",
											 pgqs_max,
											 &queryinfo,

/* On PG > 9.5, use the HASH_BLOBS optimization for uint32 keys. */
#if PG_VERSION_NUM >= 90500
											 HASH_ELEM | HASH_BLOBS | HASH_FIXED_SIZE);
#else
											 HASH_ELEM | HASH_FUNCTION | HASH_FIXED_SIZE);
#endif
'@

$hashCallNew = @'
/* On PG > 9.5, use the HASH_BLOBS optimization for uint32 keys. */
#if PG_VERSION_NUM >= 90500
	{
		int query_hash_flags = HASH_ELEM | HASH_BLOBS | HASH_FIXED_SIZE;
#else
	{
		int query_hash_flags = HASH_ELEM | HASH_FUNCTION | HASH_FIXED_SIZE;
#endif

		pgqs_query_examples_hash = ShmemInitHash("pg_qualqueryexamples_hash",
											 pgqs_max,
											 &queryinfo,
											 query_hash_flags);
	}
'@

if (-not $source.Contains($hashCallOld)) {
    throw "Expected pg_qualstats 2.1.4 ShmemInitHash block was not found; review upstream before continuing."
}
$source = $source.Replace($hashCallOld, $hashCallNew)
[IO.File]::WriteAllText($sourcePath, $source, [Text.UTF8Encoding]::new($false))

$exports = @("Pg_magic_func", "_PG_init")
foreach ($match in [regex]::Matches($source, 'PG_FUNCTION_INFO_V1\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)')) {
    $functionName = $match.Groups[1].Value
    $exports += $functionName
    $exports += "pg_finfo_$functionName"
}
$exports = @($exports | Sort-Object -Unique)

$defPath = Join-Path $UpstreamDir "pg_qualstats.pgextwin.def"
(@("LIBRARY pg_qualstats", "EXPORTS") + @($exports | ForEach-Object { "    $_" })) |
    Set-Content -Path $defPath -Encoding ascii

$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$cmdFile = Join-Path $tempRoot "pg_qualstats-build.cmd"

@"
@echo off
call "$vsDevCmd" -arch=x64 -host_arch=x64
if errorlevel 1 exit /b %errorlevel%
cd /d "$UpstreamDir"

cl /nologo /O2 /MD /DWIN32 /DWIN32_NO_STATUS /D_CRT_SECURE_NO_WARNINGS ^
  /I"$PgRoot\include\server\port\win32_msvc" ^
  /I"$PgRoot\include\server\port\win32" ^
  /I"$PgRoot\include\server" ^
  /I"$PgRoot\include" ^
  /c "$sourcePath" /Fo"$UpstreamDir\pg_qualstats.obj"
if errorlevel 1 exit /b %errorlevel%

link /nologo /DLL /OUT:"$UpstreamDir\pg_qualstats.dll" /DEF:"$defPath" ^
  "$UpstreamDir\pg_qualstats.obj" ^
  "$PgRoot\lib\postgres.lib" ^
  "$PgRoot\lib\libintl.lib"
if errorlevel 1 exit /b %errorlevel%
"@ | Set-Content -Path $cmdFile -Encoding ascii

& cmd.exe /d /c $cmdFile
if ($LASTEXITCODE -ne 0) {
    throw "pg_qualstats MSVC build failed with exit code $LASTEXITCODE."
}

$dll = Join-Path $UpstreamDir "pg_qualstats.dll"
if (-not (Test-Path $dll)) {
    throw "Expected pg_qualstats.dll was not produced: $dll"
}

$dumpCmd = Join-Path $tempRoot "pg_qualstats-dump-exports.cmd"
@"
@echo off
call "$vsDevCmd" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 exit /b %errorlevel%
dumpbin /nologo /exports "$dll"
"@ | Set-Content -Path $dumpCmd -Encoding ascii

$exportOutput = @(& cmd.exe /d /c $dumpCmd)
if ($LASTEXITCODE -ne 0) {
    throw "dumpbin failed while validating pg_qualstats.dll exports."
}
$exportText = $exportOutput -join [Environment]::NewLine
foreach ($requiredExport in $exports) {
    if ($exportText -notmatch "(?m)\b$([regex]::Escape($requiredExport))\b") {
        throw "Required DLL export was not found: $requiredExport"
    }
}

Write-Host "Built pg_qualstats $version with exports: $($exports -join ', ')"
