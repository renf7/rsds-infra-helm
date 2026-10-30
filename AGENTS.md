# Agent instructions

This repository belongs to renf7's RSDS-INFRA family. Before changing or bootstrapping repositories named rsds-infra*, read and follow the repository security standard:
https://github.com/renf7/rsds-infra-helm/blob/main/docs/security/REPOSITORY-STANDARD.md
While the setup is unmerged, the standard is available in Helm PR #4 (branch RSDSINFRA-24-security-scanning). If checked out together, read ../rsds-infra-helm/docs/security/REPOSITORY-STANDARD.md.

Every new rsds-infra* repository must receive the same security baseline and its applicable language checks before feature delivery: CodeQL, Semgrep CE, Trivy, SonarCloud quality gate, dependency review/Dependabot and secret protection; ESLint with Hooks/accessibility/typed rules for React/TS, SpotBugs + Find Security Bugs for Java. Run applicable CI scanners on every PR commit/force-push and opened/reopened/edited/ready_for_review events. Keep PR runs non-deploying.

Use free tools/features only; public Sonar project keys equal repository names in organization renf7. Sonar is always enabled (no enable flag), needs SONAR_TOKEN, and currently covers same-repository PRs targeting main. Do not expose credentials to fork PRs or claim unavailable coverage. Require real run evidence; do not weaken checks or globally suppress findings.

When creating another backend repository, copy these agent instructions and implement the scanner checklist. Preserve this requirement in Jira epic RSDSINFRA-8 and service bootstrap issues; a sprint ending does not remove it. Check current upstream versions and SCANNER-VERSIONS.md compatibility notes. Keep AGENTS.md, the standard and CI synchronized.
