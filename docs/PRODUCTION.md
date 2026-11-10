# Deploy both current main services to EKS

The production release contains only `rsds-infra-company-page` and
`rsds-infra-auth-service`. `rsds-infra-local`, its identity provider, DynamoDB
Local and Mailpit are never deployed. The application database is one external
durable DynamoDB table, shared through service-owned key namespaces.

Helm installs images, not Git branches. Before **each** production installation
or upgrade, resolve both main commits to their successful published `git-<full SHA>`
images and immutable registry digests. Do not use `latest`, PR tags, local builds,
or old generated release files as a substitute for current main.

## One-time production prerequisites

- Existing EKS cluster, AWS Load Balancer Controller, DNS and valid ACM certificate.
- One durable DynamoDB table (`rsds-infra`, region `eu-central-1` by default),
  string partition key `pk`, with backup/PITR and agreed retention. Production
  does not create an in-memory database or auto-create a table.
- Existing namespace-scoped service account `rsds-infra-auth`, associated with
  an EKS Pod Identity or IRSA role restricted to `dynamodb:GetItem` and
  `dynamodb:PutItem` on that table. Configure the required EKS Pod Identity agent
  or IRSA trust; never use local AWS access keys. Auth stays one replica because
  OAuth handshakes currently use process-local sessions.
- Secret `rsds-infra-auth-signing`: production RSA private key as `private.pem`.
  Secret `rsds-infra-auth-trust`: matching, valid public X.509 `.crt` certificates.
  Generate production material through your key-management process; do not reuse
  the short-lived local-testing key/certificates. Only auth mounts the private key.
- Secret `rsds-infra-auth-providers`: enabled providers' application client IDs/
  secrets and tenant/Graph-version settings, using the documented `RSDS_AUTH_...`
  environment names from the auth repository. Never commit the secret values.
  Register **production** callbacks:
  `https://www.rsdsoftware.eu/api/auth/login/oauth2/code/{provider}`.
  Existing `https://localhost:18443` registrations remain for local testing only.
  GitHub/Google/Microsoft/Facebook/Apple need their appropriate production app
  registrations, consent/publication and permitted-account settings. Apple also
  needs its private key secret and team/key IDs when enabled. Unconfigured
  providers remain disabled; the chart cannot create external OAuth registrations.
- Both public Docker Hub repositories with main-built images. The auth publisher
  needs repository Actions secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`,
  just like the frontend. The new publishing workflow must be merged and its
  successful main run must finish before production preparation can succeed.

Production API endpoints are same-origin through frontend nginx to the private
auth ClusterIP service. Apex traffic is redirected to `www.rsdsoftware.eu` before
starting OAuth so callback/state cookies use one canonical host. HTTPS forwarding
and Secure cookies stay enabled. No session tokens/codes are logged by the auth
proxy. Keep JWT refresh/revocation and certificate-rotation runbooks from auth.

## Prepare a current, reproducible main release (PowerShell 7)

Requires Git, PowerShell 7, Helm and Docker CLI with the Buildx plugin for registry
inspection. No EKS deployment is performed by the preparation command.

```powershell
git switch main
git pull --ff-only origin main
./scripts/Prepare-Production.ps1
```

This checks the Helm checkout matches GitHub main, resolves both service main
commits, requires their successful main CI and publishing workflows, verifies
the images exist and writes `production-images.json` with pinned digests. Missing,
failed or unfinished checks/images stop the command, with no old-image fallback.
It rechecks the service heads before writing. If a main advances later, rerun
preparation for the next release; an installed release remains reproducible.
GitHub API rate limiting or registry access errors must be resolved, not bypassed.

Review a private `production-config.yaml` containing real infrastructure overrides
(secret **names**, table, region, service account and certificate ARN). Do not put
secret values in it. For example:

```yaml
auth:
  table: rsds-infra
  region: eu-central-1
  serviceAccountName: rsds-infra-auth
  signingSecretName: rsds-infra-auth-signing
  trustSecretName: rsds-infra-auth-trust
  providerSecretName: rsds-infra-auth-providers
ingress:
  certificateArn: YOUR_REAL_ACM_CERTIFICATE_ARN
```

Use your existing release name/namespace and explicitly selected EKS context:

```powershell
helm lint charts/company-page -f charts/company-page/values-production.yaml -f production-config.yaml -f production-images.json
helm template company-page charts/company-page -f charts/company-page/values-production.yaml -f production-config.yaml -f production-images.json > production-rendered.yaml
# Review the two Deployments, their digests, Secret references and Ingress first.
helm upgrade --install company-page charts/company-page --kube-context YOUR_EKS_CONTEXT --namespace YOUR_NAMESPACE --create-namespace -f charts/company-page/values-production.yaml -f production-config.yaml -f production-images.json --atomic --wait --timeout 10m
```

`values-production.yaml` enables both services and rejects local fixtures, missing
digests, floating tags or a noncanonical public origin. Do not use the bare/default
chart installation as a production shortcut: defaults retain frontend-only local
and compatibility support. Do not use `--reuse-values` from a local fixture release.

Verify both deployments become ready; anonymous EN/PL pages, provider availability,
real sign-in/JWT/session/Settings/logout and certificate/database access work on
the public canonical host. Passing local fixture tests is not EKS/live-provider
acceptance. Keep the image file/chart commit as release evidence. Roll back using
the previous Helm revision and its recorded image digests; do not switch to latest.
