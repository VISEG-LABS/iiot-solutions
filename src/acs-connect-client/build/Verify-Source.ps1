param([string]$SolutionRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$SolutionRoot = (Resolve-Path -LiteralPath $SolutionRoot).Path
$allowedReferences = @{
    'Viseg.Connect.Core' = @()
    'Viseg.Connect.Cds' = @('Viseg.Connect.Core')
    'Viseg.Connect.Data' = @('Viseg.Connect.Core')
    'Viseg.Connect.Web' = @('Viseg.Connect.Core', 'Viseg.Connect.Cds', 'Viseg.Connect.Data')
    'Viseg.Connect.Tests' = @('Viseg.Connect.Core', 'Viseg.Connect.Web')
    'Viseg.Connect.E2E' = @('Viseg.Connect.Web')
}
foreach ($name in $allowedReferences.Keys) {
    $relativePath = if ($name -match '\.(Tests|E2E)$') { "tests/$name/$name.csproj" } else { "$name/$name.csproj" }
    [xml]$project = Get-Content -LiteralPath (Join-Path $SolutionRoot $relativePath)
    foreach ($reference in $project.SelectNodes('//ProjectReference')) {
        $target = [IO.Path]::GetFileNameWithoutExtension($reference.Include)
        if ($target -notin $allowedReferences[$name]) { throw "Forbidden dependency: $name -> $target" }
    }
    foreach ($reference in $project.SelectNodes('//PackageReference')) {
        if ($reference.HasAttribute('Version')) { throw "Use central package versions: $name / $($reference.Include)" }
        if ($name -eq 'Viseg.Connect.Core') { throw 'Core must remain free of external packages.' }
    }
}
$webRoot = Join-Path $SolutionRoot 'Viseg.Connect.Web'
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $webRoot 'Components') -Filter '*.razor' -Recurse) {
    if ((Get-Content -LiteralPath $file.FullName -Raw) -match '(?i)(?:style|fill|stroke)\s*=\s*["''][^"''>]*(?:#[0-9a-f]{3,8}\b|\brgba?\()') {
        throw "Raw inline component colour found in $($file.Name). Use semantic tokens."
    }
}
foreach ($file in Get-ChildItem -LiteralPath $SolutionRoot -File -Recurse | Where-Object {
    $_.FullName -notmatch '[/\\](?:bin|obj|artifacts|vendor)[/\\]' -and
    $_.Extension -in @('.cs', '.razor', '.js', '.css', '.ps1', '.md', '.json', '.bicep', '.bicepparam', '.props', '.slnx')
}) {
    if ((Get-Content -LiteralPath $file.FullName -Raw) -match '(?i)\bcontex[t][/\\]') {
        throw "Source depends on a local ignored planning directory: $($file.Name)"
    }
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $webRoot 'wwwroot/css') -Filter '*.css' -Recurse) {
    if ($file.Directory.Name -eq 'tokens') { continue }
    if ((Get-Content -LiteralPath $file.FullName -Raw) -match '(?i)#[0-9a-f]{3,8}\b|\b(?:rgb|rgba|hsl|hsla)\s*\(|:\s*(?:black|white|red|blue|green|orange|lime)\b') {
        throw "Raw component colour found in $($file.Name). Use semantic tokens."
    }
}
$vendorRoot = Join-Path $webRoot 'wwwroot/vendor/echarts'
$manifest = Get-Content -LiteralPath (Join-Path $vendorRoot 'manifest.json') -Raw | ConvertFrom-Json
foreach ($file in $manifest.files) {
    $actualHash = (Get-FileHash -LiteralPath (Join-Path $vendorRoot $file.file) -Algorithm SHA256).Hash
    if ($actualHash -ne $file.sha256) { throw "Vendored asset checksum differs: $($file.file)" }
}
$registration = Get-Content -LiteralPath (Join-Path $webRoot 'appsettings.json') -Raw | ConvertFrom-Json
if (!$registration.AzureAd) { throw 'The sign-in registration section belongs in Web appsettings.json.' }
Write-Output 'Source boundaries, central versions, theme tokens and vendor checksums passed.'
