# Helm security controls — RSDSINFRA-37

## Sonar authority

CI no longer creates projects or changes their visibility. A credential-free GET
verifies the existing `rsds-infra-helm` project is public. An administrator sets
visibility manually; a failed check must not be fixed by granting CI admin rights.
SONAR_TOKEN exists only in the scanner step, with no Helm/Python/PowerShell build
scripts executed while it is available. Fork PRs remain excluded from token access;
no pull_request_target is used. A changed workflow is still a security boundary and
must be reviewed: step-scoping does not protect a malicious workflow.

Owner action: rotate any broad token outside chat. On the Free plan, use a token
belonging to a dedicated non-admin analysis identity granted Execute Analysis only
for this project, with an expiry; remove organization/project administration and
project-creation permissions. Select the least privileges actually offered by the
current Free setup, verify an analysis succeeds, then revoke the old token. Do not
buy a plan merely for token scoping. Sonar Cloud Scoped Organization Tokens are
Team/Enterprise features, so this implementation does not depend on them. Existing
GitHub secret privileges cannot be read or narrowed through source changes.

Reference: https://docs.sonarsource.com/sonarqube-cloud/administering-sonarcloud/managing-organization/scoped-organization-tokens

## Repository administrator checklist

The integration returned 403 for branch protection and does not allow the settings
endpoints for alerts/security updates. Public repository metadata did not expose
security setting state. None of these are claimed enabled merely from workflows.

Under Settings > Code security, verify Dependency Graph, Dependabot alerts and
security updates, secret scanning and push protection. Then verify native dependency
review works on a real dependency-changing PR before replacing the existing Trivy
fallback. Preserve that fallback meanwhile; an empty dependency graph is not proof.

On main require PRs, code-owner approval, dismissal of stale approval, approval after
last push, resolved conversations and strict checks. Use the exact successful check
contexts from this PR: Kubernetes schemas and Helm security policies, actionlint and
zizmor, CodeQL, Sonar analysis and quality gate, blocking Trivy/dependency scan,
Semgrep and Helm/non-root nginx smoke test. Set no bypass actors and include admins
where supported; verify with settings readback. Never weaken an existing rule. Add
an independent write-access code owner when renf7 authors changes, since authors
cannot approve their own PR. CODEOWNERS itself is protected by its ownership pattern.

## Rendered policies

Run on Linux x86_64 with bash, curl, tar, sha256sum, Python and PyYAML 6.0.3:

```bash
bash tools/security/install-tools.sh
bash tools/security/check-chart.sh
.validation/bin/actionlint -shellcheck= -pyflakes=
zizmor --offline --format plain .github/workflows
```

Tools use exact releases and upstream SHA256 checksums. Helm 3.22.1 is deliberately
retained for the existing Helm 3 release contract (not a claim that Helm 4 is absent).
Default, full local-auth and production profiles are rendered without credentials or
Kubernetes access, schema-validated strictly for Kubernetes 1.34.0 and 1.35.0, then
checked by Conftest. Unknown schemas are errors, never ignored. Schemas are fetched
over HTTPS from kubeconform's default upstream at those Kubernetes versions.

Conftest rejects privilege escalation, privileged/root containers, host/shared
namespaces, hostPath, extra capabilities, writable roots and service-account tokens.
The application chart creates no RBAC; adding RBAC requires an explicit reviewed
policy change. Negative tests prove unsafe cases fail, including init/debug containers.
Visibility tests protect public allowlist data, the mounted read-only directory,
file env path, mode, no subPath/items remapping, and no auth checksum rollout. Empty
is an intentional hide-all setting. Default/custom/empty lists must leave the auth
Deployment identical. These tests do not claim full API admission or EKS deployment
coverage. CodeQL covers Actions and Python only; templates/PowerShell remain outside
its language coverage.

## Severity and exceptions

HIGH/CRITICAL Trivy gates remain blocking, including unfixed findings. A separate
MEDIUM JSON report is retained for seven days; finding severity alone does not fail
that reporting job, but scanner failures do. Review MEDIUM findings during triage.
Do not add broad ignore directories/rules or globally ignore unfixed vulnerabilities.
Any necessary exception needs a Jira key, specific rule/CVE and exact affected scope,
owner, evidence, mitigation, expiry and independent review. Keep findings visible in
the report, and remove or renew a narrow exception only through a reviewed PR.
