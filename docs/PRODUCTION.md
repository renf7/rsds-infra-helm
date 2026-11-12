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
  GitHub/Google/Microsoft/Facebook need their appropriate production app
  registrations, consent/publication and permitted-account settings. Apple is
  deliberately deferred (RSDSINFRA-32), not a release prerequisite. Unconfigured
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
./scripts/Test-Production.ps1 -KubeContext YOUR_EKS_CONTEXT -Namespace YOUR_NAMESPACE -Config production-config.yaml
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

## Non-deploying preflight and capacity

`Test-Production.ps1` requires PowerShell 7, Helm 3 and kubectl. It always selects
the supplied context/namespace, lints/renders the production values, verifies
referenced Secrets/service accounts and signing/trust key names, and performs
strict **server dry runs** for every rendered resource. Existing resources use
replacement validation (with resourceVersion and allocated Service addresses),
avoiding the misleading duplicate `http` port produced by client-side apply when
moving an old port-80 Deployment to port 8080. The script never installs, upgrades,
restarts or deletes cluster objects. Temporary manifests contain Secret references,
not Secret values. The existing namespace must exist. Read and dry-run create/update
permissions are required; admission webhooks must support dry runs.

This is not a complete Helm upgrade simulation: immutable selectors/ownership,
concurrent changes, AWS access, scheduling, credential correctness and real login
still require operator verification. Do not feed its replacement manifests into
`kubectl replace` without dry-run; Helm remains the release owner.

Before upgrading, inspect capacity (including DaemonSets on each extra node):

```bash
kubectl --context rsd-software-eks get nodes -o custom-columns='NAME:.metadata.name,PODS:.status.allocatable.pods'
kubectl --context rsd-software-eks get pods -A -o wide
kubectl --context rsd-software-eks describe nodes
```

Allow room for both applications **and rolling-update surge pods**, CPU/memory
requests, topology and the CNI's pod/IP limits. A Ready node does not prove spare
capacity. Provision additional capacity only after checking AWS cost. Auth stays
one replica until shared OAuth session storage exists. Its startup probe allows
up to three minutes before liveness starts; production explicitly disables unused
SMTP health. Frontend probes send the canonical Host to avoid redirects.

## Diagnose an unsuccessful upgrade

While the upgrade is waiting, use a second terminal:

```bash
helm history company-page --kube-context rsd-software-eks -n rsds --max 6
kubectl --context rsd-software-eks -n rsds get deployments,pods -o wide
kubectl --context rsd-software-eks -n rsds get events --sort-by=.metadata.creationTimestamp
kubectl --context rsd-software-eks -n rsds logs deployment/company-page-auth -c auth --tail=100
kubectl --context rsd-software-eks -n rsds logs deployment/company-page-auth -c auth --previous --tail=100
```

Treat logs as private; redact cookies, authorization codes, identifiers and tokens
before sharing. Pending pods: inspect scheduling events/capacity. CrashLoopBackOff:
inspect previous logs, Secret mounts, signing certificates and DynamoDB workload
identity. Unauthorized may require renewing the operator's EKS credentials.
With Helm 3 `--atomic`, a timeout/failure rolls back: `deployed` may describe the
**old chart**, and auth can disappear entirely. Check revision/chart/images, not
just status. Do not run simultaneous upgrades, delete the working release or turn
off checks to obtain a green status. Capture diagnostics before rollback removes
the failed pods, fix the cause, refresh main image pins and retry the same upgrade.

## Shared DynamoDB backup and recovery

Keep PITR and deletion protection enabled on the single production table. Verify
with `aws dynamodb describe-continuous-backups --region eu-central-1 --table-name
rsds-infra` and `aws dynamodb describe-table`. Before a risky migration, record a
completed on-demand backup ARN (`create-backup`, then `describe-backup`). Backups
and restored tables have AWS costs; retention/deletion requires owner approval.

Recovery is an operator change, never a chart startup action:

1. Stop application writes in an agreed maintenance window and record the current
   chart/images/table configuration. Back up the current table before recovery.
2. Use DynamoDB `restore-table-to-point-in-time` or `restore-table-from-backup`
   to a **new isolated recovery table**. AWS cannot restore in place. Restrict
   recovery access; it contains personal data and authentication records.
3. Wait for ACTIVE, verify keys/record integrity and adapter reads in isolation.
   Reapply/verify PITR, deletion protection, TTL settings and least-privilege IAM;
   restored settings and permissions must not be assumed to match the original.
4. A restore can resurrect revoked sessions. Invalidate restored refresh sessions
   using the auth runbook before accepting traffic; plan forced reauthentication
   and signing-key rotation if revocation integrity cannot be established.
5. Point the deployment's `auth.table` and workload IAM at the validated recovery
   table and perform a reviewed upgrade. All active services still share exactly
   one table; the recovery copy is temporary, not another application database.
6. Verify login/logout and persistence, then resume traffic. Keep the original
   table for the agreed rollback window; never automatically delete either copy.

## Signing certificate rotation

Only auth receives `private.pem`. Verify the new public certificate matches its
RSA private key and has a valid validity window before creating versioned Secrets.
Do not print/export private keys into Git, manifests, logs or Jira.

1. Distribute a trust bundle containing old **and new** public `.crt` certificates
   to auth and each future resource service. Restart consumers if their verifier
   loads certificates only at startup. Verify the old signer still works.
2. Change auth's signing Secret to the new private key and restart auth using a
   reviewed values change. Verify new JWT signature/issuer/audience, refresh and
   logout; retain old public trust for the longest still-valid token lifetime
   plus clock skew. Use configured lifetimes, not a guessed fixed interval.
3. Remove old trust only after that interval and successful verification. For an
   exposed private key, use the incident/revocation procedure instead of normal
   overlap: reject affected tokens and force reauthentication.

Rollback must preserve trust for tokens already issued with the new signer.
Changing a Kubernetes Secret alone does not prove the running process reloaded
it. Rehearse rotation and recovery in isolated staging before production.

## RSDSINFRA-24 release acceptance ledger

Current deployable scope is frontend + auth, one external DynamoDB table, no local
runner/fixtures. Keep exact chart commit, service commits/digests, main CI run
links, preflight output, Helm revision and operator sign-off in the release record.

| Acceptance | Required evidence / remaining dependency |
| --- | --- |
| Static EN/PL pages, responsive layout, privacy page | Browser regressions plus operator desktop/tablet/mobile check |
| Auth/JWT/session/Settings/logout | Fixture E2E against real app/database plus separate live-provider sign-in |
| Provider availability | GitHub, Google and Microsoft actual production tests; Facebook requires Meta eligibility/review; Apple deferred by RSDSINFRA-32 |
| Release and recovery | Exact main images, strict preflight, observed rollout, staging backup/restore and certificate rotation rehearsal |
| Day/night parity | RSDSINFRA-14 remains To Do |
| All service roles, 401/403 and cross-user isolation | RSDSINFRA-18 remains To Do |
| Reviewed offers, auto-send idempotency, competence flow | RSDSINFRA-20 / RSDSINFRA-22 and dependent backend tasks remain To Do |

The umbrella ticket cannot be closed from this chart change alone. Neither a
fixture suite nor a successful preflight proves production SSO, restore or rotation.
