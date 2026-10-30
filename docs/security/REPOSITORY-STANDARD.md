# RSDS-INFRA repository security standard

Scope: all current and future public GitHub repositories owned by renf7 whose names start with rsds-infra. Jira project: RSDSINFRA; product epic: RSDSINFRA-8. This includes the frontend, Helm/deployment repository and every new backend. Apply the same baseline with language-specific checks; do not run a scanner against a language it cannot analyze or treat an empty/skipped scan as success.

## Required PR events
Every applicable CI scanner must run on pull_request types opened, synchronize, reopened, edited and ready_for_review. synchronize covers pushed commits, force-pushes and branch updates. Do not restrict by file paths or omit drafts. Cancel superseded runs so the latest revision takes priority. This policy covers code updates and PR title/body/base edits; comments, labels and review reactions do not change code and need not rerun the scanners.

Scans must not publish Docker images or deploy production on PR events. Image publishing remains main-only after image scanning. Scan main pushes and schedule regular rescans for newly disclosed vulnerabilities. Scan the exact PR revision; never execute untrusted fork code with privileged pull_request_target credentials.

## Baseline and applicability
| Check | All repositories | Additional applicability |
| --- | --- | --- |
| Semgrep Community Edition | Enable on PR updates for supported source/configuration | Keep OSS mode, community rules and no paid platform requirement |
| Trivy | Repository vulnerabilities, configuration and secrets on PR updates | Build and scan every deliverable container image before publish |
| CodeQL | GitHub Actions workflows | Java/Kotlin in backends; JavaScript/TypeScript and Python where present |
| SonarQube Cloud | Public project, key equals repository name, organization renf7, quality-gate wait | PRs targeting main on the permanent Free plan; other targets only if supported by verified free OSS entitlement |
| Dependency review | PR dependency vulnerability checks | Dependabot alerts/security updates plus weekly version-update PRs are separate native features |
| Secret protection | Enable GitHub secret scanning/push protection | Trivy secret scanning additionally reruns on PR updates |
| ESLint | JS/React/TS repositories only | React Hooks, JSX accessibility, type-aware TypeScript recommended checks; fail on warnings |
| SpotBugs + Find Security Bugs | Java backends only | Analyze compiled classes during Maven verify or equivalent Gradle check; findings/errors fail CI |

Sonar fork PRs currently cannot receive SONAR_TOKEN and are excluded. A trusted supported fork-analysis process is required before claiming full fork coverage; do not weaken token isolation. GitHub may withhold PR runs for merge conflicts or require approval for fork/bot events. Resolve that prerequisite rather than claiming scans ran.

Use only permanently free tooling/features. Do not enable paid tiers, trials as a dependency, paid runners or paid extended support. Keep repository/project visibility public, subject to repository owner authorization. Future private repositories require a separate free/local CI eligibility review.

## New-repository acceptance checklist
1. Name the repository rsds-infra-<service>; keep one frontend and one shared NoSQL database per the architecture.
2. Copy a root AGENTS.md pointing to this standard, plus a README link. Add the standard before the first feature implementation.
3. Install the baseline and applicable language/container scanners with explicit PR triggers, minimal permissions, locked dependencies and SHA-pinned actions. Track upstream releases; document compatibility exceptions rather than forcing incompatible versions.
4. Configure a public SonarCloud project bound to the repository, its exact unprefixed key and SONAR_TOKEN secret. No SONAR_ENABLED flag or SONAR_PROJECT_KEY variable is required. Use CI-based analysis; verify main baseline and PR results separately.
5. Configure npm/pip/Maven/Docker/GitHub Actions Dependabot ecosystems that actually exist. Enable repository-level alerts, secret protection and required checks; YAML is not evidence that admin settings were enabled.
6. Verify a real PR commit/update triggers every applicable check. Keep run links and analyzed commit evidence in its bootstrap Jira issue. Never mark unexecuted/empty scans complete.
7. Require successful security checks/quality gates before merging, triage narrow exceptions with reason/owner/expiry, and preserve deployment compatibility and rollback instructions.
8. Java: adopt docs/security/spotbugs-plugin.xml; run the real compiled build and retain evidence. React: retain eslint.config.mjs, the lockfile and real TS/React types; verify Hooks, accessibility and Promise checks on actual code.
9. Keep scanner setup acceptance in each service bootstrap issue and in the epic, independent of sprint dates.

## Discoverability and ownership
This versioned document is the technical source of truth. Root AGENTS.md tells coding agents to read it at task start and copy it into new repository setup. Jira records implementation/completion; Confluence may mirror the rationale and onboarding guide but must link here and must not become a conflicting copy.

Current implementation is in frontend PR #9 and Helm PR #4. After merge, use the default-branch URL:
https://github.com/renf7/rsds-infra-helm/blob/main/docs/security/REPOSITORY-STANDARD.md

Recommended future consolidation: a dedicated public renf7/rsds-infra-ci repository containing versioned reusable GitHub workflows, and repository templates containing AGENTS.md plus small caller workflows. Keep scanner implementations centralized, pin callers to reviewed commits, and use Dependabot to propose reference updates. This is a recommendation, not an already-created repository or enforcement mechanism. A central document or Confluence page alone does not install/enforce CI.

Latest version checks and temporary compatibility exceptions are recorded in SCANNER-VERSIONS.md. Current ESLint 9 exception and Helm Sonar findings remain tracked in RSDSINFRA-24.


## Current dependency-review capability
Initial actions/dependency-review-action runs failed in both repositories because GitHub reported dependency review unavailable and requested Dependency Graph enablement. Until an administrator enables/verifies it, .github/workflows/dependency-review.yml runs a free full-manifest/lockfile Trivy vulnerability scan on every PR update instead. This does not require the graph API and is not a claim of native base/head dependency-diff review. Helm currently has no application package manifest; add Maven manifests when backend repositories are created and verify non-empty scan coverage. Keep the repository/image scans and native Dependabot/secret protection setup requirements.
