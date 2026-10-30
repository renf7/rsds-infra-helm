# SonarQube Cloud setup (free use only)

This workflow is prepared for the existing renf7 organization at https://sonarcloud.io. Analysis is always enabled for the configured events; SONAR_TOKEN must be an Actions secret. No enable flag is required. Missing configuration fails with an explicit error instead of silently skipping. Fork PRs remain skipped because they cannot receive the token. A skipped job is not analysis evidence.

## One-time setup
1. In SonarCloud organization renf7, import/bind this exact GitHub repository. Verify the organization's permanent free/OSS plan supports analysis of this public project and PRs targeting main. Do not start a paid subscription, trial-dependent integration or paid advanced-security feature. Public projects require review of free/OSS eligibility and any license requirements.
2. Set the bound SonarCloud project's key to exactly rsds-infra-helm (no renf7_ prefix). For an existing project use its Administration > Update Key option; do not delete/recreate it and lose history. Verify the project is bound to this repository before renaming. If this key is already taken, resolve the collision before scanning.
3. Choose CI-based analysis and disable Automatic Analysis for this project to avoid duplicate/conflicting analysis.
4. Create a least-privilege, expiring analysis token in SonarCloud and store it directly in GitHub Settings > Secrets and variables > Actions as secret SONAR_TOKEN. Never put the token in chat, files or repository variables.
5. No SONAR_PROJECT_KEY Actions variable is needed: the workflow derives sonar.projectKey from github.event.repository.name. Organization remains renf7. Changing GitHub configuration does not rename the server-side Sonar project; perform step 2 before expecting scans to succeed.
6. No SONAR_ENABLED secret or variable is required; any existing value is unused. Merge the configuration and run workflow_dispatch on main for a baseline before expecting useful new-code comparisons. PR scans then run for every commit/update, reopening, metadata edit and ready-for-review event.
7. Verify main and PR analyses in SonarCloud and GitHub. Only after a real successful run, require the Sonar check/quality gate in branch rules. Confirm that missing configuration cannot satisfy your required security policy.

The scanner explicitly waits for the quality gate (five-minute gate timeout) and fails the job on a failed gate. Standard ubuntu-latest runners and the scanner do not require a paid scanner subscription; SonarCloud account/plan eligibility must be checked separately. The Free plan documents PR analysis targeting main; do not promise arbitrary target branches without OSS-plan entitlement.

## Scope and limits
Frontend: HTML/CSS/JavaScript and Python scripts are analyzed. No frontend application build/test coverage exists yet; add LCOV and Python coverage when real tests exist. Never invent coverage or exclude production code to make the gate pass.
Helm: scan YAML/Kubernetes where supported; Trivy remains the dedicated Helm/security scanner. Confirm actual analyzed files because templated YAML support can differ. Sonar is an additional check, not a replacement for CodeQL, Semgrep, Trivy or authorization tests.

Fork PRs deliberately skip this token-based job because repository secrets are unavailable. Use SonarCloud's supported GitHub integration or a separately reviewed trusted process for those PRs; do not switch to pull_request_target and execute untrusted PR code with credentials. No paid upgrade is authorized.

For future Spring Boot repositories use SonarScanner for Maven/Gradle with compiled classes and JaCoCo coverage, rather than copying this generic scanner unchanged.


## Public visibility and finding PR results
Projects must be public, matching these public GitHub repositories. sonar.projectVisibility=public requests public visibility on creation. Before scanning, CI checks the existing project and requests a public visibility update if needed. If the analysis token lacks project-admin rights, an administrator must change Administration > Permissions > Public once; ordinary analysis tokens can continue after that. Do not broaden CI token privileges merely to automate administration.

PR runs upload PR analyses and wait for their quality gate. View results using dashboard?id=<repository-name>&pullRequest=<PR-number> or the project's Pull Requests tab. The default overview shows main, which is populated when main is analyzed after the workflow is merged (or via a separate trusted baseline run). Absence of main results does not mean PR scans did not execute. The workflow explicitly runs on opened/synchronize/reopened/edited/ready_for_review events targeting main; synchronize includes each pushed commit or force-push. Fork PRs remain excluded from token-based analysis.


## Helm activation verification
After adding or rotating the Helm repository's SONAR_TOKEN secret, push a PR update and verify the SonarQube Cloud run reaches analysis and reports its quality gate. For this setup PR, inspect the project's Pull Requests entry for PR #4; main-branch results are separate. A missing-token error, skipped job or queued run is not proof of successful analysis.
