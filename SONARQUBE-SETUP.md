# SonarQube Cloud setup (free use only)

This workflow is prepared for the existing renf7 organization at https://sonarcloud.io. It is disabled until the repository variable SONAR_ENABLED is exactly true. A skipped job is not analysis evidence and must not be treated as a passing scan.

## One-time setup
1. In SonarCloud organization renf7, import/bind this exact GitHub repository. Verify the organization's permanent free/OSS plan supports analysis of this public project and PRs targeting main. Do not start a paid subscription, trial-dependent integration or paid advanced-security feature. Public projects require review of free/OSS eligibility and any license requirements.
2. Copy the actual SonarCloud project key; do not assume an older similarly named project belongs to this repository. Existing public keys observed were renf7_rsds-company-page and renf7_rsds-ai-jobs-extractor.
3. Choose CI-based analysis and disable Automatic Analysis for this project to avoid duplicate/conflicting analysis.
4. Create a least-privilege, expiring analysis token in SonarCloud and store it directly in GitHub Settings > Secrets and variables > Actions as secret SONAR_TOKEN. Never put the token in chat, files or repository variables.
5. Add repository Actions variable SONAR_PROJECT_KEY with the exact imported project's key.
6. Add repository Actions variable SONAR_ENABLED=true. Merge the configuration and run workflow_dispatch on main for a baseline before expecting useful new-code comparisons. PR scans then run for every commit/update, reopening, metadata edit and ready-for-review event.
7. Verify main and PR analyses in SonarCloud and GitHub. Only after a real successful run, require the Sonar check/quality gate in branch rules. Confirm that missing/disabled configuration cannot satisfy your required security policy.

The scanner explicitly waits for the quality gate (five-minute gate timeout) and fails the job on a failed gate. Standard ubuntu-latest runners and the scanner do not require a paid scanner subscription; SonarCloud account/plan eligibility must be checked separately. The Free plan documents PR analysis targeting main; do not promise arbitrary target branches without OSS-plan entitlement.

## Scope and limits
Frontend: HTML/CSS/JavaScript and Python scripts are analyzed. No frontend application build/test coverage exists yet; add LCOV and Python coverage when real tests exist. Never invent coverage or exclude production code to make the gate pass.
Helm: scan YAML/Kubernetes where supported; Trivy remains the dedicated Helm/security scanner. Confirm actual analyzed files because templated YAML support can differ. Sonar is an additional check, not a replacement for CodeQL, Semgrep, Trivy or authorization tests.

Fork PRs deliberately skip this token-based job because repository secrets are unavailable. Use SonarCloud's supported GitHub integration or a separately reviewed trusted process for those PRs; do not switch to pull_request_target and execute untrusted PR code with credentials. No paid upgrade is authorized.

For future Spring Boot repositories use SonarScanner for Maven/Gradle with compiled classes and JaCoCo coverage, rather than copying this generic scanner unchanged.
