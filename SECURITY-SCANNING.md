# Security checks

GitHub Actions runs Trivy and Semgrep Community Edition on pull requests, main pushes, weekly schedules and manual dispatches. Trivy blocks on HIGH/CRITICAL vulnerabilities, secrets and infrastructure misconfigurations, including findings without a fix. Semgrep uses community p/default rules, explicitly selects the OSS engine and disables metrics; no Semgrep account/token is required. Review findings rather than adding blanket exclusions.

The frontend additionally runs CodeQL for JavaScript/TypeScript, Python tooling and GitHub Actions and scans its built image. Helm has no Java/JS application code: Trivy scans chart configuration and Semgrep scans applicable rules. Do not interpret a scanner with no applicable code as proof of safety.

## Repository settings to verify after merging
At Settings > Advanced Security (the exact UI label may vary):
- Enable dependency graph, Dependabot alerts and Dependabot security updates.
- Verify secret scanning and secret-scanning push protection are enabled.
- CodeQL uses this repository's advanced workflow; disable default setup if already enabled to avoid conflicting modes.
- After initial runs, require Security scans jobs and applicable CodeQL checks in the main branch ruleset. Do not require a job before it has reported once.
These settings are not enabled by committing YAML. Keep all repositories public for the planned free GitHub code-scanning features; reassess eligibility before changing visibility.

Dependabot checks GitHub Actions weekly; the frontend also checks Docker base images. Add npm at / when the React package.json is introduced and Maven at / in each new Spring Boot repository. No npm/Maven manifest currently exists in these two repositories.

## New backend repositories
Apply this workflow baseline when rsds-infra-auth-service, rsds-infra-job-offer-service and rsds-infra-competence-service are created. Configure CodeQL for java-kotlin and actions with the selected Java toolchain/build mode, Maven Dependabot, and a built-image scan. Enable the settings above individually.

## Findings and exceptions
Investigate each failure. Fix the root cause; any suppression must name the finding, justification, owner and expiry. Never commit signing keys, OAuth secrets, database credentials or personal offer/CV data. Scheduled runs catch newly published advisories. Passing scans do not replace JWT/role/ownership security tests.

The first successful CI run must be verified before claiming the setup is operational. Community Semgrep coverage is narrower than its paid engine. Security scans need network access for rules and vulnerability feeds.
