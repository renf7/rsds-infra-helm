#!/usr/bin/env bash
set -euo pipefail
export PATH="$(pwd)/.validation/bin:$PATH"
mkdir -p .validation/rendered
helm lint charts/company-page
helm template policy charts/company-page > .validation/rendered/default.yaml
helm template policy charts/company-page --set auth.enabled=true --set auth.local=true \
  --set auth.signingSecretName=test-signing --set auth.trustSecretName=test-trust \
  --set idp.enabled=true --set idp.clientTrustSecretName=test-client --set dynamodb.enabled=true \
  --set mailpit.enabled=true > .validation/rendered/local.yaml
helm template policy charts/company-page -f charts/company-page/values-production.yaml \
  --set image.tag=git-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --set auth.image.tag=git-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  --set image.digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --set auth.image.digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  > .validation/rendered/production.yaml
for version in 1.34.0 1.35.0; do
  kubeconform -strict -summary -kubernetes-version "$version" .validation/rendered/*.yaml
done
conftest verify --policy policy
conftest test --policy policy .validation/rendered/*.yaml
python tests/provider-visibility.py
python tests/production-chart.py
