"""Rendered visibility contract and negative policy mutations; no Kubernetes access."""
from copy import deepcopy
from pathlib import Path
import subprocess
import tempfile
import yaml

chart = 'charts/company-page'
base = ['helm', 'template', 'contract', chart, '--set', 'auth.enabled=true', '--set', 'auth.local=true',
        '--set', 'auth.signingSecretName=test-signing', '--set', 'auth.trustSecretName=test-trust']

def render(extra):
    return [item for item in yaml.safe_load_all(subprocess.check_output(base + extra, text=True)) if item]

reference = None
for value in ['{facebook,microsoft,google,github}', '{google,github}', '{}']:
    docs = render(['--set-json', 'auth.visibleProviders=[]'] if value == '{}' else ['--set', 'auth.visibleProviders=' + value])
    config = next(item for item in docs if item['kind'] == 'ConfigMap' and item['metadata']['name'].endswith('-provider-visibility'))
    expected = value.strip('{}')
    assert config['data'] == {'visible-providers': expected}
    auth = next(item for item in docs if item['kind'] == 'Deployment' and item['metadata']['name'].endswith('-auth'))
    if reference is None:
        reference = auth
    else:
        assert reference == auth, 'Visibility must not alter auth Deployment or roll pods'
    with tempfile.TemporaryDirectory() as temporary:
        document = Path(temporary) / 'auth.yaml'
        document.write_text(yaml.safe_dump(auth), encoding='utf-8')
        subprocess.run(['conftest', 'test', '--policy', 'policy', str(document)], check=True)
        for mutation in ['subPath', 'subPathExpr', 'writable', 'wrong-directory', 'wrong-file', 'wrong-config', 'checksum', 'missing-volume']:
            changed = deepcopy(auth)
            spec = changed['spec']['template']['spec']
            container = spec['containers'][0]
            mount = next(item for item in container['volumeMounts'] if item['name'] == 'provider-visibility')
            if mutation in ['subPath', 'subPathExpr']:
                mount[mutation] = 'visible-providers'
            elif mutation == 'writable':
                mount['readOnly'] = False
            elif mutation == 'wrong-directory':
                mount['mountPath'] = '/run/other'
            elif mutation == 'wrong-file':
                next(item for item in container['env'] if item['name'] == 'RSDS_AUTH_PROVIDER_VISIBILITY_FILE')['value'] = '/other'
            elif mutation == 'wrong-config':
                next(item for item in spec['volumes'] if item['name'] == 'provider-visibility')['configMap']['name'] = 'other'
            elif mutation == 'checksum':
                changed['spec']['template']['metadata']['annotations'] = {'checksum/provider': 'changing'}
            else:
                spec['volumes'] = [item for item in spec['volumes'] if item['name'] != 'provider-visibility']
            document.write_text(yaml.safe_dump(changed), encoding='utf-8')
            result = subprocess.run(['conftest', 'test', '--policy', 'policy', str(document)], capture_output=True, text=True, check=False)
            assert result.returncode == 1, (mutation, result.stdout, result.stderr)

invalid = subprocess.run(base + ['--set', 'auth.visibleProviders={google,apple}'], capture_output=True, text=True, check=False)
assert invalid.returncode != 0
print('PASS: default/custom/empty allowlists; unchanged Deployment; 24 unsafe mount mutations denied; Apple rejected')
