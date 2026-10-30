# Scanner version audit — 30 October 2026

Latest stable upstream releases were checked against GitHub Releases and npm registry metadata. Pins remain reproducible; no rolling latest tags or paid upgrades are introduced.

| Component | Configured version | Result |
| --- | --- | --- |
| Trivy CLI | 0.76.1 | Latest stable |
| Trivy Action | 0.36.0, commit ed142fd0673e97e23eac54620cfb913e5ce36c25 | Updated from 0.35.0 |
| Semgrep CE | 1.183.0 | Updated from 1.159.0; tools/security/requirements.txt is monitored by Dependabot |
| CodeQL Action | 4.39.1, commit 9b3254085494b55a0f7c4c2b3d2d52cc712ce370 | Already current; do not confuse action releases with codeql-bundle releases |
| Sonar scan action | 8.4.0 | Already current |
| SonarScanner CLI | 8.3.0.16463 (bundled by action) | Latest stable checked |
| SpotBugs Maven template | 4.10.5.0 (engine 4.10.5) | Already current; pending actual backend adoption |
| Find Security Bugs template | 1.14.0 | Already current; pending actual backend adoption |
| React Hooks ESLint plugin | 7.1.1 | Latest npm stable |
| JSX accessibility plugin | 6.10.2 | Latest npm stable; excludes ESLint 10 from its peer range |
| typescript-eslint | 8.72.1 | Latest npm stable; supports TypeScript >=4.8.4 <6.1.0 |
| ESLint / @eslint/js | 9.39.5 | Compatibility exception: latest ESLint is 10.13.0 and @eslint/js is 10.0.1, but jsx-a11y does not declare ESLint 10 support |
| TypeScript | 6.0.3 | Updated from 5.9.3; latest npm stable 7.0.2 is outside typescript-eslint's supported range |
| globals | 17.13.0 | Updated from 16.5.0 |

ESLint 9 is EOL upstream. This is an explicit temporary compatibility exception, not a claim that all tools are at the latest major. Upgrade to ESLint 10 once jsx-a11y declares support, or separately review/test a maintained accessibility alternative. Do not install paid extended support, force peer dependency resolution or disable accessibility checks without review.

ESLint locally passed with the updated lockfile; a temporary unhandled-Promise probe confirmed type-aware scanning with TypeScript 6.0.3. GitHub PR runs validate the updated scanner action and Semgrep. See the PR checks for final results; existing Sonar quality-gate findings are separate from tool-version compatibility.

References:
- https://github.com/aquasecurity/trivy/releases
- https://github.com/aquasecurity/trivy-action/releases
- https://github.com/semgrep/semgrep/releases
- https://github.com/github/codeql-action/releases
- https://github.com/SonarSource/sonarqube-scan-action/releases
- https://github.com/SonarSource/sonar-scanner-cli/releases
- https://github.com/spotbugs/spotbugs-maven-plugin/releases
- https://github.com/find-sec-bugs/find-sec-bugs/releases
- https://eslint.org/version-support/
- https://typescript-eslint.io/users/dependency-versions/
- https://registry.npmjs.org/eslint-plugin-jsx-a11y/latest

## Dependency consolidation — RSDSINFRA-27

Combined Dependabot PRs #5 (setup-python 7.1.0), #6 (setup-helm action 5.0.1) and #7 (checkout 7.0.1). Action references remain pinned to the original Dependabot-proposed immutable commit SHAs. The setup-helm action upgrade does not itself change the configured Helm CLI version.

Tracking: https://rsdsoftware.atlassian.net/browse/RSDSINFRA-27. Validate both consolidated PR heads with the local runner and explicit --e2e; browser tests stay disabled by default. PR workflows remain non-deploying.

