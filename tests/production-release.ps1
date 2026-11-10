$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../scripts/Prepare-Production.ps1"
$sha = 'a' * 40
$ok = [pscustomobject]@{ id=1;head_sha=$sha;head_branch='main';name='Publish';event='push';status='completed';conclusion='success' }
Assert-MainChecks @($ok) $sha @('Publish')
foreach ($override in @(@{head_sha=('b'*40)},@{head_branch='feature'},@{event='pull_request'},@{status='in_progress'},@{conclusion='failure'})) {
    $data = @{}; $ok.PSObject.Properties | ForEach-Object { $data[$_.Name]=$_.Value }
    foreach ($key in $override.Keys) { $data[$key]=$override[$key] }
    $rejected=$false
    try { Assert-MainChecks @([pscustomobject]$data) $sha @('Publish') } catch { $rejected=$true }
    if (-not $rejected) { throw 'Unsafe or unfinished main release was accepted' }
}
$rejected=$false
try { Assert-MainChecks @($ok) $sha @('Missing') } catch { $rejected=$true }
if (-not $rejected) { throw 'Missing required workflow was accepted' }
$newerFailure = [pscustomobject]@{id=2;head_sha=$sha;head_branch='main';name='Publish';event='push';status='completed';conclusion='failure'}
$rejected=$false
try { Assert-MainChecks @($ok,$newerFailure) $sha @('Publish') } catch { $rejected=$true }
if (-not $rejected) { throw 'An earlier success masked a newer failure' }
Write-Output 'PASS: exact main, event, workflow coverage, pending/failure and newest-run release checks.'
