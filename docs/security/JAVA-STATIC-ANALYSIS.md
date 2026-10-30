# Free Java static analysis baseline

Apply docs/security/spotbugs-plugin.xml inside build/plugins of each new Spring Boot service's pom.xml:
- renf7/rsds-infra-auth-service
- renf7/rsds-infra-job-offer-service
- renf7/rsds-infra-competence-service

SpotBugs examines compiled bytecode; Find Security Bugs adds security detectors, including Spring/Jakarta patterns. Both run locally/CI without a hosted scanner account or subscription. This fragment is a template, not proof that a nonexistent backend has been scanned.

## Build and CI
Use a committed Maven Wrapper and run ./mvnw --batch-mode --no-transfer-progress verify on every PR opened/synchronize/reopened/edited/ready_for_review event, pushes to main and a weekly schedule. Select the supported JDK agreed by architecture; verify bytecode compatibility before adopting a newer Java release. Pin workflow actions to verified commit SHAs and keep workflow permissions at contents: read.

The template binds spotbugs:check to verify with Max effort, Medium priority threshold and failOnError=true. Keep XML reports in CI (target/spotbugsXml.xml by default) and inspect failures. Confirm an intentionally insecure fixture is detected during initial integration, then remove the fixture from application source. Keep detector/configuration errors fatal.

Do not suppress findings globally or disable Find Security Bugs to make the build pass. Review narrow exceptions with rule/class, justification, owner and expiry. Add Maven Dependabot updates so scanner/plugin dependencies are monitored.

Keep CodeQL, Semgrep, Trivy and Sonar in addition to this build-time check. Run each tool as a visible check; do not report SpotBugs as active until a real backend build has passed with it. Integrate these requirements into RSDSINFRA-16, RSDSINFRA-20 and RSDSINFRA-22.

References:
- https://spotbugs.github.io/
- https://spotbugs.github.io/spotbugs-maven-plugin/
- https://find-sec-bugs.github.io/
