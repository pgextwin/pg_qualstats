[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PgRoot,

    [Parameter(Mandatory = $true)]
    [int]$PgPort,

    [Parameter(Mandatory = $true)]
    [int]$PostgreSqlMajor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$initdb = Join-Path $PgRoot "bin\initdb.exe"
$pgCtl = Join-Path $PgRoot "bin\pg_ctl.exe"
$pgIsReady = Join-Path $PgRoot "bin\pg_isready.exe"
$psql = Join-Path $PgRoot "bin\psql.exe"

$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$dataDir = Join-Path $tempRoot "pg_qualstats-pg$PostgreSqlMajor-data"
$logFile = Join-Path $tempRoot "pg_qualstats-pg$PostgreSqlMajor.log"
$setupSql = Join-Path $tempRoot "pg_qualstats-pg$PostgreSqlMajor-setup.sql"

if (Test-Path $dataDir) {
    Remove-Item $dataDir -Recurse -Force
}
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

& $initdb -D $dataDir -U postgres -A trust --encoding=UTF8 --no-locale
if ($LASTEXITCODE -ne 0) {
    throw "initdb failed."
}

function Show-PostgresLog {
    if (Test-Path $logFile) {
        Write-Host "----- PostgreSQL log -----"
        Get-Content $logFile -Tail 300
        Write-Host "--------------------------"
    }
}

function Wait-Postgres {
    for ($i = 0; $i -lt 45; $i++) {
        & $pgIsReady -h 127.0.0.1 -p $PgPort -q
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Start-Sleep -Seconds 2
    }
    Show-PostgresLog
    throw "Temporary PostgreSQL cluster did not become ready."
}

try {
    $serverOptions = "-p $PgPort -c shared_preload_libraries=pg_qualstats -c pg_qualstats.sample_rate=1"
    & $pgCtl -D $dataDir -l $logFile -o $serverOptions start
    if ($LASTEXITCODE -ne 0) {
        Show-PostgresLog
        throw "Failed to start PostgreSQL with pg_qualstats preloaded."
    }

    Wait-Postgres

    @'
CREATE EXTENSION pg_qualstats;
SELECT pg_qualstats_reset();

CREATE TABLE public.pgextwin_pgqs_probe (
    id integer PRIMARY KEY,
    payload integer NOT NULL
);

INSERT INTO public.pgextwin_pgqs_probe
SELECT g, g % 10
FROM generate_series(1, 1000) AS g;

SELECT count(*) FROM public.pgextwin_pgqs_probe WHERE payload = 3;
SELECT count(*) FROM public.pgextwin_pgqs_probe WHERE payload = 7;
SELECT count(*) FROM public.pgextwin_pgqs_probe WHERE id > 900;
'@ | Set-Content -Path $setupSql -Encoding utf8

    & $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -v ON_ERROR_STOP=1 -f $setupSql
    if ($LASTEXITCODE -ne 0) {
        Show-PostgresLog
        throw "pg_qualstats functional SQL failed."
    }

    $qualCount = ((& $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -Atqc "SELECT count(*) FROM pg_qualstats WHERE lrelid = 'public.pgextwin_pgqs_probe'::regclass;") | Select-Object -Last 1).Trim()
    if ([int]$qualCount -lt 1) {
        throw "pg_qualstats did not collect predicates for the probe table."
    }

    $payloadCount = ((& $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -Atqc "SELECT count(*) FROM pg_qualstats WHERE lrelid = 'public.pgextwin_pgqs_probe'::regclass AND lattnum = 2;") | Select-Object -Last 1).Trim()
    if ([int]$payloadCount -lt 1) {
        throw "pg_qualstats did not collect the payload predicate."
    }

    $prettyCount = ((& $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -Atqc "SELECT count(*) FROM pg_qualstats_pretty WHERE left_table = 'pgextwin_pgqs_probe';") | Select-Object -Last 1).Trim()
    if ([int]$prettyCount -lt 1) {
        throw "pg_qualstats_pretty did not expose the collected predicate."
    }

    & $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -v ON_ERROR_STOP=1 -c "DROP TABLE public.pgextwin_pgqs_probe; DROP EXTENSION pg_qualstats;"
    if ($LASTEXITCODE -ne 0) {
        throw "pg_qualstats smoke-test cleanup failed."
    }
}
catch {
    Show-PostgresLog
    throw
}
finally {
    if (Test-Path (Join-Path $dataDir "postmaster.pid")) {
        & $pgCtl -D $dataDir -m fast stop
    }
}
