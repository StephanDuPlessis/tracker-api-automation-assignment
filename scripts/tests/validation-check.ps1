Clear-Host
$baseUrl = 'http://localhost:5080'
$apiKey  = $env:API_KEY
$outFile = Join-Path $PSScriptRoot '..\docs\evidence\validation-after-fix.txt'

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'API_KEY is not set in this PowerShell session.'
}

# A valid position. Each test case changes only the field it wants to break.
function New-Body($overrides) {
    $body = [ordered]@{
        id         = 'pos-test-val-00'
        deviceId   = 'TEST-N-30001'
        occurredAt = '2025-01-15T12:34:56Z'
        latitude   = -33.9249
        longitude  = 18.4241
        speedKph   = 60.5
        headingDeg = 90
    }
    foreach ($key in $overrides.Keys) { $body[$key] = $overrides[$key] }
    return $body
}

# Each case: a name, the status code we expect, and the fields to change.
$cases = @(
    @{ Name = 'speedKph 1000000 (too big for column)'; Expected = 400; Overrides = @{ id = 'pos-test-val-01'; speedKph = 1000000 } },
    @{ Name = 'speedKph 5000 (fits column, unrealistic)'; Expected = 400; Overrides = @{ id = 'pos-test-val-02'; speedKph = 5000 } },
    @{ Name = 'speedKph -10 (negative)'; Expected = 400; Overrides = @{ id = 'pos-test-val-03'; speedKph = -10 } },
    @{ Name = 'headingDeg 10000 (too big for column)'; Expected = 400; Overrides = @{ id = 'pos-test-val-04'; headingDeg = 10000 } },
    @{ Name = 'headingDeg 500 (fits column, over 360)'; Expected = 400; Overrides = @{ id = 'pos-test-val-05'; headingDeg = 500 } },
    @{ Name = 'id of 101 characters'; Expected = 400; Overrides = @{ id = 'pos-test-' + ('a' * 92) } },
    @{ Name = 'deviceId of 51 characters'; Expected = 400; Overrides = @{ id = 'pos-test-val-07'; deviceId = 'TEST-' + ('a' * 46) } },
    @{ Name = 'latitude with 8 decimals (known limitation, rounded)'; Expected = 201; Overrides = @{ id = 'pos-test-val-08'; latitude = -33.92491234 } },
    @{ Name = 'speedKph 0 (lower boundary)'; Expected = 201; Overrides = @{ id = 'pos-test-val-09'; speedKph = 0 } },
    @{ Name = 'speedKph 1000 (upper boundary)'; Expected = 201; Overrides = @{ id = 'pos-test-val-10'; speedKph = 1000 } },
    @{ Name = 'headingDeg 0 (lower boundary)'; Expected = 201; Overrides = @{ id = 'pos-test-val-11'; headingDeg = 0 } },
    @{ Name = 'headingDeg 360 (upper boundary)'; Expected = 201; Overrides = @{ id = 'pos-test-val-12'; headingDeg = 360 } },
    @{ Name = 'id of 100 characters (boundary)'; Expected = 201; Overrides = @{ id = 'pos-test-' + ('a' * 91) } },
    @{ Name = 'deviceId of 50 characters (boundary)'; Expected = 201; Overrides = @{ id = 'pos-test-val-14'; deviceId = 'TEST-' + ('a' * 45) } }
)

# Sends one POST /positions and returns the status code and response text.
function Send-Position($body) {
    $bodyFile = Join-Path $env:TEMP 'validation-body.json'
    $respFile = Join-Path $env:TEMP 'validation-response.txt'

    $body | ConvertTo-Json | Set-Content -Path $bodyFile -Encoding ascii

    $status = curl.exe -s -o $respFile -w "%{http_code}" -X POST "$baseUrl/positions" `
        -H "X-Api-Key: $apiKey" -H "Content-Type: application/json" --data-binary "@$bodyFile"

    [pscustomobject]@{ Status = [int]$status; Body = (Get-Content $respFile -Raw) }
}

# Remove old test data first, so the script can be run again and again.
$sqlServer = '(localdb)\MSSQLLocalDB'
$database  = 'PositionsDb'
$cleanup   = Join-Path $PSScriptRoot '..\db\99_cleanup.sql'

sqlcmd -S $sqlServer -d $database -i $cleanup
if ($LASTEXITCODE -ne 0) { throw 'Cleanup failed. Is the database reachable?' }

# Put the known seed data back (3 devices, 12 positions).
$seed = Join-Path $PSScriptRoot '..\db\02_seed.sql'

sqlcmd -S $sqlServer -d $database -i $seed
if ($LASTEXITCODE -ne 0) { throw 'Seed failed.' }

# Run every case, compare the real status with the expected one, collect the lines.
$lines    = @()
$failures = 0
$number   = 0

foreach ($case in $cases) {
    $number++
    $result   = Send-Position (New-Body $case.Overrides)
    $bodyText = "$($result.Body)".Trim()

    if ($result.Status -eq $case.Expected) { $verdict = 'PASS' }
    else { $verdict = 'FAIL'; $failures++ }

    $lines += "$number $($case.Name)"
    $lines += "$($result.Status) (expected $($case.Expected)) $verdict $bodyText"
    $lines += ''
}

$summary = "Failures: $failures of $($cases.Count)"
$lines
$summary
($lines + $summary) | Set-Content -Path $outFile -Encoding ascii