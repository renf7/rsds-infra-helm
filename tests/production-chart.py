"""Production rendering contracts: no cloud credentials or deployments."""
import os
import subprocess
import yaml

helm = os.environ.get('HELM', 'helm')
chart = 'charts/company-page'
base = [helm, 'template', 'production-test', chart, '-f', chart + '/values-production.yaml']
pins = ['--set', 'image.tag=git-' + 'a' * 40, '--set', 'image.digest=sha256:' + 'a' * 64,
        '--set', 'auth.image.tag=git-' + 'b' * 40, '--set', 'auth.image.digest=sha256:' + 'b' * 64]

def render(args, succeeds):
    result = subprocess.run(base + args, capture_output=True, text=True, check=False)
    assert (result.returncode == 0) == succeeds, result.stderr
    return list(yaml.safe_load_all(result.stdout)) if succeeds else []

render([], False)
docs = [d for d in render(pins, True) if d]
deployments = [d for d in docs if d['kind'] == 'Deployment']
assert len(deployments) == 2
assert {d['spec']['template']['spec']['containers'][0]['image'] for d in deployments} == {
    'renf7/rsds-infra-company-page@sha256:' + 'a' * 64,
    'renf7/rsds-infra-auth-service@sha256:' + 'b' * 64}
assert not any('rsds-infra-local' in str(d) for d in docs)
auth = next(d for d in deployments if d['metadata']['name'].endswith('-auth'))
pod = auth['spec']['template']['spec']
assert pod['serviceAccountName'] == 'rsds-infra-auth'
env = {e['name']: e['value'] for e in pod['containers'][0]['env']}
assert env['RSDS_AUTH_PROVIDER_MODE'] == 'live'
assert env['RSDS_AUTH_LOCAL'] == 'false'
assert env['RSDS_AUTH_PUBLIC_BASE_URL'] == 'https://www.rsdsoftware.eu'
assert env['RSDS_AUTH_DYNAMO_ENDPOINT'] == ''
assert env['SPRING_PROFILES_ACTIVE'] == 'production'
config = next(d for d in docs if d['kind'] == 'ConfigMap')['data']['nginx.conf']
assert 'location /__test/' not in config
assert 'proxy_set_header X-Forwarded-Proto https;' in config
assert 'return 308 https://www.rsdsoftware.eu$request_uri' in config
for override in ['auth.enabled=false', 'auth.local=true', 'idp.enabled=true',
                 'dynamodb.enabled=true', 'mailpit.enabled=true', 'auth.providerMode=fixture',
                 'auth.publicBaseUrl=http://localhost:18443', 'auth.providerSecretName=',
                 'auth.serviceAccountName=', 'image.tag=latest', 'auth.image.digest=',
                 'production.host=localhost;injected']:
    render(pins + ['--set', override], False)
print('PASS: two immutable production services; live auth; no local fixtures; unsafe overrides rejected.')
