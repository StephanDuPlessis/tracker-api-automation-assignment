# Loads settings from the .env file in the repo root into environment variables.
function Import-DotEnv {
    param([string]$Path = (Join-Path $PSScriptRoot '..\.env'))

    # No .env file (for example on the pipeline agent) is fine: there is nothing to load.
    if (-not (Test-Path $Path)) { return }

    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()

        # Skip blank lines and comments.
        if ($line -eq '' -or $line.StartsWith('#')) { continue }

        # Split on the FIRST '=' only, so a value that contains '=' stays whole.
        $index = $line.IndexOf('=')
        if ($index -lt 1) { continue }   # no name in front of the '='

        $name = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1).Trim()

        # Blank values are skipped: the API treats an empty DB_CONNECTION_STRING as an error.
        if ($value -eq '') { continue }

        # A variable that is already set wins, so pipeline variables override .env.
        if ([Environment]::GetEnvironmentVariable($name, 'Process')) { continue }

        Set-Item -Path "Env:$name" -Value $value

    }
}
