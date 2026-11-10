[CmdletBinding()]
param([string]$OutputPath = (Join-Path $PSScriptRoot '../production-images.json'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-MainChecks($Runs, [string]$Commit, [string[]]$RequiredWorkflows) {
    foreach ($name in $RequiredWorkflows) {
        $run = $Runs | Where-Object { $_.head_sha -eq $Commit -and $_.head_branch -eq 'main' -and $_.name -eq $name -and $_.event -in @('push','workflow_dispatch') } |
            Sort-Object id -Descending | Select-Object -First 1
        if (-not $run -or $run.status -ne 'completed' -or $run.conclusion -ne 'success') {
            throw "Main $Commit has no successful current '$name' run. Wait for CI/publishing; no old/latest image fallback is allowed."
        }
    }
}

function Resolve-MainImage([string]$Repository, [string[]]$Workflows) {
    $api = "https://api.github.com/repos/renf7/$Repository"
    $headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'RSDS-production-preparation' }
    $commit = (Invoke-RestMethod "$api/commits/main" -Headers $headers).sha
    if ($commit -notmatch '^[a-f0-9]{40}$') { throw "Invalid main commit for $Repository" }
    $runs = (Invoke-RestMethod "$api/actions/runs?branch=main&head_sha=$commit&per_page=100" -Headers $headers).workflow_runs
    Assert-MainChecks $runs $commit $Workflows
    $image = "renf7/${Repository}:git-$commit"
    $raw = & docker buildx imagetools inspect $image --format '{{json .Manifest}}'
    if ($LASTEXITCODE -ne 0) { throw "Published main image is unavailable: $image" }
    $digest = ($raw | ConvertFrom-Json).digest
    if ($digest -notmatch '^sha256:[a-f0-9]{64}$') { throw "Invalid registry digest for $image" }
    return @{ repository = "renf7/$Repository"; tag = "git-$commit"; digest = $digest; pullPolicy = 'IfNotPresent' }
}

function Write-ProductionImages([string]$Destination) {
    $root = Split-Path $PSScriptRoot -Parent
    $headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'RSDS-production-preparation' }
    $helmMain = (Invoke-RestMethod 'https://api.github.com/repos/renf7/rsds-infra-helm/commits/main' -Headers $headers).sha
    $localHead = (& git -C $root rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $localHead -ne $helmMain) { throw 'Use a clean checkout of current rsds-infra-helm main, then rerun preparation.' }
    $dirty = & git -C $root status --porcelain --untracked-files=no
    if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Tracked Helm files have local modifications; use the reviewed main chart.' }
    $frontend = Resolve-MainImage 'rsds-infra-company-page' @('Build and push Docker image','React build and browser regression','ESLint','Validate SEO','Security scans','CodeQL','SonarQube Cloud')
    $auth = Resolve-MainImage 'rsds-infra-auth-service' @('Publish main Docker image','Java build tests and bytecode security','Security scans','CodeQL','SonarQube Cloud')
    foreach ($entry in @(@{name='rsds-infra-company-page';image=$frontend},@{name='rsds-infra-auth-service';image=$auth})) {
        $current = (Invoke-RestMethod "https://api.github.com/repos/renf7/$($entry.name)/commits/main" -Headers $headers).sha
        if ($entry.image.tag -ne "git-$current") { throw 'A service main advanced during preparation. Rerun; no output was written.' }
    }
    $values = @{ image=$frontend; auth=@{image=$auth}; releaseProvenance=@{helmMain=$helmMain;preparedAt=[DateTimeOffset]::UtcNow.ToString('o')} }
    $values | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Destination -Encoding utf8
    Write-Output "Prepared both current main images, pinned by digest: $Destination"
    Write-Output 'Install with values-production.yaml, this image file and your private production configuration. This command does not deploy.'
}

if ($MyInvocation.InvocationName -ne '.') { Write-ProductionImages $OutputPath }
