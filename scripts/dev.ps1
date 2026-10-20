[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("up", "down", "status", "reset")]
    [string]$Command
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$composeArguments = @(
    "compose",
    "--env-file", ".env.local",
    "-f", "docker-compose.local.yml"
)

function Invoke-LocalCompose {
    param([string[]]$Arguments)

    Push-Location $projectRoot
    try {
        & docker @composeArguments @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Docker Compose exited with code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

switch ($Command) {
    "up" {
        Invoke-LocalCompose @("up", "--build", "--detach", "--wait")
        Write-Host "`nLocal stack is ready:"
        Invoke-LocalCompose @("ps")
        Write-Host "`nAPI: http://localhost:8004/api/"
        Write-Host "Admin panel: http://localhost:5173/"
    }
    "down" {
        Invoke-LocalCompose @("down")
    }
    "status" {
        Invoke-LocalCompose @("ps")
    }
    "reset" {
        $confirmation = Read-Host "This permanently deletes local PostGIS and admin-panel Docker volumes. Type RESET to continue"
        if ($confirmation -ne "RESET") {
            Write-Host "Reset cancelled."
            exit 0
        }

        Invoke-LocalCompose @("down", "--volumes")
        Invoke-LocalCompose @("up", "--build", "--detach", "--wait")
        Write-Host "`nLocal stack was reset and is ready:"
        Invoke-LocalCompose @("ps")
    }
}
