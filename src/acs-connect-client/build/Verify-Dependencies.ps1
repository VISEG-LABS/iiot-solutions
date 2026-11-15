param(
    [string]$SolutionRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts/dependencies')
)
$ErrorActionPreference = 'Stop'
$SolutionRoot = (Resolve-Path -LiteralPath $SolutionRoot).Path
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
Push-Location $SolutionRoot
try {
    $graphJson = & dotnet list Viseg.Connect.slnx package --include-transitive --no-restore --format json
    if ($LASTEXITCODE -ne 0) { throw 'Dependency graph query failed.' }
    $graphJson | Set-Content -LiteralPath (Join-Path $OutputDirectory 'dependency-graph.json') -Encoding utf8
    $graph = $graphJson -join [Environment]::NewLine | ConvertFrom-Json
    $cacheOutput = & dotnet nuget locals global-packages --list
    if ($LASTEXITCODE -ne 0) { throw 'NuGet cache query failed.' }
    $cache = $cacheOutput.Substring($cacheOutput.IndexOf(':') + 1).Trim()
    $policy = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'dependency-policy.json') -Raw | ConvertFrom-Json -AsHashtable
    $allPackages = foreach ($project in $graph.projects) {
        foreach ($framework in $project.frameworks) { @($framework.topLevelPackages) + @($framework.transitivePackages) }
    }
    $directIds = foreach ($project in $graph.projects) {
        foreach ($framework in $project.frameworks) { $framework.topLevelPackages.id }
    }
    $inventory = foreach ($package in $allPackages | Sort-Object id,resolvedVersion -Unique) {
        $name = $package.id.ToLowerInvariant()
        $nuspecPath = Join-Path $cache "$name/$($package.resolvedVersion)/$name.nuspec"
        [xml]$nuspec = Get-Content -LiteralPath $nuspecPath
        $author = [string]$nuspec.package.metadata.authors
        $exception = $policy.transitiveExceptions[$package.id]
        if ($author -notmatch '^Microsoft(?:\b| Corporation)' -and ($package.id -in $directIds -or $exception -ne $package.resolvedVersion)) {
            throw "Unapproved package author/version: $($package.id) $($package.resolvedVersion) ($author)"
        }
        [pscustomobject]@{ Id = $package.id; Version = $package.resolvedVersion; Authors = $author }
    }
    $inventory | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'package-authors.json') -Encoding utf8
    $vulnerabilityJson = & dotnet list Viseg.Connect.slnx package --vulnerable --include-transitive --no-restore --format json
    if ($LASTEXITCODE -ne 0) { throw 'Vulnerability query failed.' }
    $vulnerabilityJson | Set-Content -LiteralPath (Join-Path $OutputDirectory 'vulnerabilities.json') -Encoding utf8
    $report = $vulnerabilityJson -join [Environment]::NewLine | ConvertFrom-Json
    foreach ($project in $report.projects) {
        foreach ($framework in $project.frameworks) {
            foreach ($package in @($framework.topLevelPackages) + @($framework.transitivePackages)) {
                if ($package.vulnerabilities) { throw "Known vulnerable dependency: $($package.id)" }
            }
        }
    }
    Write-Output "Dependency policy passed for $($inventory.Count) package/version entries; no known vulnerabilities reported."
} finally { Pop-Location }
