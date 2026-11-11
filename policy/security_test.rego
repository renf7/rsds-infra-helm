package main
import rego.v1

safe_document := {
    "kind": "Deployment", "metadata": {"name": "frontend"},
    "spec": {"template": {"metadata": {}, "spec": {
        "automountServiceAccountToken": false, "securityContext": {"runAsNonRoot": true},
        "containers": [{"name": "frontend", "securityContext": {
            "allowPrivilegeEscalation": false, "readOnlyRootFilesystem": true, "capabilities": {"drop": ["ALL"]}
        }}], "volumes": [{"name": "tmp", "emptyDir": {}}]
    }}}
}
test_safe_workload_allowed if {
    failures := deny with input as safe_document; count(failures) == 0
}
test_dangerous_workload_mutations_denied if {
    every patch in [
        {"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true},
        {"op": "add", "path": "/spec/template/spec/hostPID", "value": true},
        {"op": "add", "path": "/spec/template/spec/hostIPC", "value": true},
        {"op": "add", "path": "/spec/template/spec/securityContext/runAsUser", "value": 0},
        {"op": "add", "path": "/spec/template/spec/volumes/0/projected", "value": {"sources": [{"serviceAccountToken": {"path": "token"}}]}},
        {"op": "add", "path": "/spec/template/spec/shareProcessNamespace", "value": true},
        {"op": "replace", "path": "/spec/template/spec/automountServiceAccountToken", "value": true},
        {"op": "remove", "path": "/spec/template/spec/automountServiceAccountToken"},
        {"op": "add", "path": "/spec/template/spec/volumes/0/hostPath", "value": {"path": "/"}},
        {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/privileged", "value": true},
        {"op": "replace", "path": "/spec/template/spec/containers/0/securityContext/allowPrivilegeEscalation", "value": true},
        {"op": "remove", "path": "/spec/template/spec/containers/0/securityContext/readOnlyRootFilesystem"},
        {"op": "replace", "path": "/spec/template/spec/containers/0/securityContext/capabilities/drop", "value": []},
        {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": ["SYS_ADMIN"]},
        {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/runAsUser", "value": 0},
        {"op": "add", "path": "/spec/template/spec/initContainers", "value": [{"name": "unsafe-init"}]},
        {"op": "add", "path": "/spec/template/spec/ephemeralContainers", "value": [{"name": "unsafe-debug"}]}
    ] {
        document := json.patch(safe_document, [patch])
        failures := deny with input as document; count(failures) > 0
    }
}
test_rbac_denied if {
    every kind in ["Role", "ClusterRole", "RoleBinding", "ClusterRoleBinding"] {
        failures := deny with input as {"kind": kind}; count(failures) > 0
    }
}
test_visibility_values if {
    every value in ["", "google,github", "facebook,microsoft,google,github"] {
        failures := deny with input as {"kind": "ConfigMap", "metadata": {"name": "test-provider-visibility"}, "data": {"visible-providers": value}}
        count(failures) == 0
    }
    every value in ["apple", "google,typo", "google,", "GitHub"] {
        failures := deny with input as {"kind": "ConfigMap", "metadata": {"name": "test-provider-visibility"}, "data": {"visible-providers": value}}
        count(failures) > 0
    }
}
