# Runtime login-button visibility (RSDSINFRA-33)

Deploy the matching auth-service and company-page changes before expecting this policy
to affect buttons. OAuth registrations/secrets remain independent. Hiding a button
does **not** revoke existing sessions, cancel callbacks or block direct OAuth URLs.
Apple remains deferred; this switch cannot enable it or an unconfigured provider.

The chart mounts `company-page-provider-visibility` as a read-only directory. Auth
reads its `visible-providers` file for every discovery request; the open login modal
refreshes every five seconds. No rebuild, Helm upgrade or pod restart is needed for
subsequent visibility changes. Kubernetes projection may take around two minutes
(cluster sync/cache settings determine actual delay). Do not change this to an env
variable or a `subPath` mount: neither provides these live updates.

## EKS operation

Show only Google and GitHub (run in Bash/CloudShell):

```bash
kubectl --context rsd-software-eks -n rsds patch configmap company-page-provider-visibility \
  --type merge -p '{"data":{"visible-providers":"google,github"}}'
curl --fail-with-body https://www.rsdsoftware.eu/api/auth/providers
```

Alternatively use `kubectl --context rsd-software-eks -n rsds edit configmap company-page-provider-visibility`.
Comma-separated values are `facebook,microsoft,google,github`. An empty string hides
all buttons with an EN/PL message. Unknown/malformed values or a missing configured
file hide all; correct the value to recover. `enabled` describes registration;
`visible` combines registration and this policy. Discovery never returns credentials.

Restore the default:

```bash
kubectl --context rsd-software-eks -n rsds patch configmap company-page-provider-visibility \
  --type merge -p '{"data":{"visible-providers":"facebook,microsoft,google,github"}}'
```

Helm owns this ConfigMap: a later upgrade may reconcile live edits. Persist the desired
list in private `production-config.yaml` as `auth.visibleProviders: [google, github]`
(or `[]` for none), and always pass that file during upgrades. Record the previous list
before an edit for rollback. Kubernetes RBAC controlling ConfigMap writes controls
who can operate this switch; the application needs no Kubernetes API permissions.

Reference: https://kubernetes.io/docs/tutorials/configuration/updating-configuration-via-a-configmap/

Provider names are normalized case-insensitively by the auth service (for example,
`GitHub, GOOGLE`). Unknown names are still rejected. Empty is an intentional operator
command to hide all, not a transient error. Kubernetes replaces projected files
atomically; it does not expose a partially written value during normal projection.
The policy deliberately does not fall back to showing all providers on malformed
input, since that could expose a provider deliberately hidden by the operator.
Use the restore command above to recover from a typo.
