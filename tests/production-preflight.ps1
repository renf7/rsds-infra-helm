$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../scripts/Test-Production.ps1" -KubeContext test-context
$script:commands = [Collections.Generic.List[string]]::new()
$script:missingKey = $false
$script:admissionFails = $false
function Invoke-Checked([string]$Tool, [string[]]$Arguments) {
    $command = "$Tool $($Arguments -join ' ')"
    $script:commands.Add($command)
    if ($Tool -eq 'helm') { return '# rendered' }
    if ($command -match 'create --dry-run=client') {
        return (@{items=@(
            @{apiVersion='apps/v1';kind='Deployment';metadata=@{name='company-page'};spec=@{template=@{spec=@{volumes=@();containers=@(@{name='frontend'})}}}},
            @{apiVersion='apps/v1';kind='Deployment';metadata=@{name='company-page-auth'};spec=@{template=@{spec=@{
                serviceAccountName='rsds-infra-auth';
                volumes=@(@{name='signing';secret=@{secretName='signing'}},@{name='trust';secret=@{secretName='trust'}});
                containers=@(@{name='auth';envFrom=@(@{secretRef=@{name='providers'}})})
            }}}},
            @{apiVersion='v1';kind='Service';metadata=@{name='company-page'};spec=@{ports=@(@{port=80})}}
        )} | ConvertTo-Json -Depth 30)
    }
    if ($command -match 'get secret signing -o json') {
        $data = if ($script:missingKey) { @{} } else { @{'private.pem'='PRIVATE-SENTINEL'} }
        return (@{metadata=@{name='signing'};data=$data} | ConvertTo-Json)
    }
    if ($command -match 'get secret trust -o json') { return '{"metadata":{"name":"trust"},"data":{"active.crt":"CERT-SENTINEL"}}' }
    if ($command -match 'get Deployment/company-page-auth --ignore-not-found') { return '' }
    if ($command -match 'get Deployment/company-page --ignore-not-found') { return '{"metadata":{"resourceVersion":"123"}}' }
    if ($command -match 'get Service/company-page --ignore-not-found') {
        return '{"metadata":{"resourceVersion":"456"},"spec":{"clusterIP":"10.0.0.1","clusterIPs":["10.0.0.1"],"ipFamilies":["IPv4"],"ipFamilyPolicy":"SingleStack"}}'
    }
    if ($command -match 'replace --dry-run=server') {
        $object = Get-Content -LiteralPath $Arguments[-1] -Raw | ConvertFrom-Json
        if (-not $object.metadata.resourceVersion) { throw 'Replacement needs current revision' }
        if ($object.kind -eq 'Service' -and $object.spec.clusterIP -ne '10.0.0.1') { throw 'Allocated Service address lost' }
    }
    if ($command -match '--dry-run=server' -and $script:admissionFails) { throw 'Admission rejected' }
    return 'existing'
}
$output = Test-Production 3>&1 | Out-String
if ($output -notmatch 'PASS:' -or $output -match 'PRIVATE-SENTINEL|CERT-SENTINEL') { throw 'Unexpected preflight output' }
foreach ($expected in @('replace --dry-run=server', 'create --dry-run=server', 'get serviceaccount rsds-infra-auth', 'get secret providers')) {
    if (-not @($script:commands | Where-Object { $_.Contains($expected) }).Count) { throw "Missing check: $expected" }
}
if (@($script:commands | Where-Object { $_ -match ' apply | upgrade | delete | restart ' }).Count) { throw 'Preflight mutated cluster' }
if (@($script:commands | Where-Object { $_ -like 'kubectl*' -and $_ -notlike '*--context test-context --namespace rsds*' }).Count) { throw 'Implicit Kubernetes target' }
foreach ($failure in @('missingKey','admissionFails')) {
    Set-Variable -Scope Script -Name $failure -Value $true
    $rejected = $false
    try { Test-Production | Out-Null } catch { $rejected = $true }
    Set-Variable -Scope Script -Name $failure -Value $false
    if (-not $rejected) { throw "Failure not propagated: $failure" }
}
Write-Output 'PASS: preflight validates existing/new resources, prerequisites and failures without mutations or secret output.'
