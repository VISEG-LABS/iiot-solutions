param([string]$BicepExecutable = '')
$ErrorActionPreference = 'Stop'
$solutionRoot = Split-Path $PSScriptRoot -Parent
$template = Join-Path $solutionRoot 'Viseg.Connect.Infrastructure/main.bicep'
$parameters = Join-Path $solutionRoot 'Viseg.Connect.Infrastructure/environments/sandbox.bicepparam'
$originalAdminId = $env:VISEG_SQL_ADMIN_OBJECT_ID
try {
    # Local compilation only: never use this placeholder to deploy resources.
    $env:VISEG_SQL_ADMIN_OBJECT_ID = '00000000-0000-0000-0000-000000000001'
    if ($BicepExecutable) {
        & $BicepExecutable build $template --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed.' }
        & $BicepExecutable build-params $parameters --stdout | Out-Null
    } else {
        & az bicep build --file $template --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed.' }
        & az bicep build-params --file $parameters --stdout | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw 'Bicep parameter compilation failed.' }
    Write-Output 'Infrastructure compiles locally; no Azure validation or deployment performed.'
} finally { $env:VISEG_SQL_ADMIN_OBJECT_ID = $originalAdminId }
