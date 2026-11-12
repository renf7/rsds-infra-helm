# Read-only prerequisite and admission checks. No Helm upgrade or persistent writes.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$KubeContext,
    [string]$Namespace = 'rsds',
    [string]$Release = 'company-page',
    [string]$Images = (Join-Path $PSScriptRoot '../production-images.json'),
    [string]$Config
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Checked([string]$Tool, [string[]]$Arguments) {
    $result = & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool failed; preflight stopped. No deployment performed." }
    return $result
}

function Assert-SecretKeys($Secret, [string[]]$Required) {
    foreach ($key in $Required) {
        if (-not $Secret.data.Contains($key) -or -not $Secret.data[$key]) {
            throw "Secret $($Secret.metadata.name) needs a nonempty '$key' key."
        }
    }
}

function Test-Production {
    $root = Split-Path $PSScriptRoot -Parent
    $chart = Join-Path $root 'charts/company-page'
    $values = @('-f', (Join-Path $chart 'values-production.yaml'))
    if ($Config) { $values += @('-f', $Config) }
    $values += @('-f', $Images)
    $kube = @('--context', $KubeContext, '--namespace', $Namespace)
    $null = Invoke-Checked kubectl ($kube + @('get', 'namespace', $Namespace, '-o', 'name'))
    $null = Invoke-Checked helm (@('lint', $chart) + $values)
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + '.json')
    $rendered = $temporary + '.yaml'
    try {
        Invoke-Checked helm (@('template', $Release, $chart, '--namespace', $Namespace) + $values) |
            Set-Content -LiteralPath $rendered -Encoding utf8
        $json = Invoke-Checked kubectl ($kube + @('create', '--dry-run=client', '--validate=strict', '-f', $rendered, '-o', 'json'))
        $resources = ($json -join "`n" | ConvertFrom-Json -AsHashtable).items
        if (-not $resources) { throw 'Expected multiple rendered resources.' }
        $deployments = @($resources | Where-Object kind -eq Deployment)
        if ($deployments.Count -ne 2) { throw 'Production must render exactly frontend and auth.' }
        foreach ($deployment in $deployments) {
            $pod = $deployment.spec.template.spec
            if ($pod.Contains('serviceAccountName')) {
                $null = Invoke-Checked kubectl ($kube + @('get', 'serviceaccount', $pod.serviceAccountName, '-o', 'name'))
            }
            foreach ($volume in $pod.volumes) {
                if ($volume.Contains('secret')) {
                    # Secret bytes stay in memory and are never printed or written to disk.
                    $secretJson = Invoke-Checked kubectl ($kube + @('get', 'secret', $volume.secret.secretName, '-o', 'json'))
                    $secret = $secretJson -join "`n" | ConvertFrom-Json -AsHashtable
                    if ($volume.name -eq 'signing') { Assert-SecretKeys $secret @('private.pem') }
                    if ($volume.name -eq 'trust' -and -not @($secret.data.Keys | Where-Object { $_ -like '*.crt' -and $secret.data[$_] }).Count) {
                        throw 'Trust Secret needs a nonempty .crt certificate.'
                    }
                }
            }
            foreach ($container in $pod.containers) {
                if ($container.Contains('envFrom')) {
                    foreach ($source in $container.envFrom) {
                        $null = Invoke-Checked kubectl ($kube + @('get', 'secret', $source.secretRef.name, '-o', 'name'))
                    }
                }
            }
        }
        # Replacement validates the desired object directly. apply would merge the old
        # port 80 and new port 8080 by containerPort and can falsely report duplicate http names.
        foreach ($resource in $resources) {
            $existing = Invoke-Checked kubectl ($kube + @('get', "$($resource.kind)/$($resource.metadata.name)", '--ignore-not-found', '-o', 'json'))
            if ($existing) {
                $current = $existing -join "`n" | ConvertFrom-Json -AsHashtable
                $resource.metadata.resourceVersion = $current.metadata.resourceVersion
                # Preserve API-assigned Service fields for replacement validation.
                if ($resource.kind -eq 'Service') {
                    foreach ($key in @('clusterIP', 'clusterIPs', 'ipFamilies', 'ipFamilyPolicy')) {
                        if ($current.spec.Contains($key) -and -not $resource.spec.Contains($key)) {
                            $resource.spec[$key] = $current.spec[$key]
                        }
                    }
                }
            }
            $resource | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temporary -Encoding utf8
            $verb = if ($existing) { 'replace' } else { 'create' }
            $null = Invoke-Checked kubectl ($kube + @($verb, '--dry-run=server', '--validate=strict', '-f', $temporary))
            Write-Output "Validated $($resource.kind)/$($resource.metadata.name) (server dry run)."
        }
        Write-Output 'PASS: render, referenced prerequisites and API admission. No deployment performed.'
        Write-Warning 'This does not prove scheduling capacity, AWS workload identity/DynamoDB access, certificate validity/key matching, OAuth credentials or live SSO. Complete docs/PRODUCTION.md acceptance checks.'
    } finally {
        foreach ($path in @($temporary, $rendered)) {
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
        }
    }
}
if ($MyInvocation.InvocationName -ne '.') { Test-Production }
