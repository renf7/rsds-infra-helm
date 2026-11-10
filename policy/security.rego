package main
import rego.v1

podspec := input.spec if input.kind == "Pod"
podspec := input.spec.template.spec if input.kind in {"Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "Job"}
podspec := input.spec.jobTemplate.spec.template.spec if input.kind == "CronJob"

containers contains container if {
    collection := ["containers", "initContainers", "ephemeralContainers"][_]
    container := object.get(podspec, collection, [])[_]
}

deny contains "Service account token automount must be explicitly false" if {
    object.get(podspec, "automountServiceAccountToken", null) != false
}
deny contains sprintf("Host/shared namespace forbidden: %s", [field]) if {
    field := ["hostNetwork", "hostPID", "hostIPC", "shareProcessNamespace"][_]
    object.get(podspec, field, false) == true
}
deny contains "hostPath volumes are forbidden" if { podspec.volumes[_].hostPath }
deny contains "RBAC resources require a separately reviewed policy change; this application chart needs none" if {
    input.kind in {"Role", "ClusterRole", "RoleBinding", "ClusterRoleBinding"}
}
deny contains sprintf("Privileged container: %s", [c.name]) if {
    c := containers[_]; object.get(object.get(c, "securityContext", {}), "privileged", false) == true
}
deny contains sprintf("Privilege escalation must be disabled: %s", [c.name]) if {
    c := containers[_]; object.get(object.get(c, "securityContext", {}), "allowPrivilegeEscalation", null) != false
}
deny contains sprintf("Read-only root filesystem required: %s", [c.name]) if {
    c := containers[_]; object.get(object.get(c, "securityContext", {}), "readOnlyRootFilesystem", false) != true
}
deny contains sprintf("Drop ALL capabilities: %s", [c.name]) if {
    c := containers[_]; not "ALL" in object.get(object.get(object.get(c, "securityContext", {}), "capabilities", {}), "drop", [])
}
deny contains sprintf("Additional capabilities forbidden: %s", [c.name]) if {
    c := containers[_]; count(object.get(object.get(object.get(c, "securityContext", {}), "capabilities", {}), "add", [])) > 0
}
deny contains "Pod must require non-root execution" if {
    object.get(object.get(podspec, "securityContext", {}), "runAsNonRoot", false) != true
}
deny contains "Pod cannot select root user" if {
    object.get(object.get(podspec, "securityContext", {}), "runAsUser", -1) == 0
}
deny contains "Explicit service account token projection is forbidden" if {
    podspec.volumes[_].projected.sources[_].serviceAccountToken
}
deny contains sprintf("Container cannot override non-root execution: %s", [c.name]) if {
    c := containers[_]; context := object.get(c, "securityContext", {})
    object.get(context, "runAsUser", -1) == 0
}
deny contains sprintf("Container cannot disable non-root execution: %s", [c.name]) if {
    c := containers[_]; object.get(object.get(c, "securityContext", {}), "runAsNonRoot", true) == false
}

valid_visibility_mount if {
    c := podspec.containers[_]; c.name == "auth"
    mount := c.volumeMounts[_]; mount.name == "provider-visibility"
    mount.mountPath == "/run/provider-visibility"; mount.readOnly == true
    not mount.subPath; not mount.subPathExpr
    volume := podspec.volumes[_]; volume.name == mount.name
    volume.configMap.name == sprintf("%s-provider-visibility", [trim_suffix(input.metadata.name, "-auth")])
    volume.configMap.defaultMode == 292
    not volume.configMap.items
    object.get(volume.configMap, "optional", false) == false
    env := c.env[_]; env.name == "RSDS_AUTH_PROVIDER_VISIBILITY_FILE"
    env.value == "/run/provider-visibility/visible-providers"
}
deny contains "Auth visibility must use the expected read-only directory ConfigMap mount and file env, without subPath" if {
    input.kind == "Deployment"; endswith(input.metadata.name, "-auth")
    not valid_visibility_mount
}
deny contains "Runtime visibility changes must not force auth rollout through checksum annotations" if {
    input.kind == "Deployment"; endswith(input.metadata.name, "-auth")
    annotations := object.get(input.spec.template.metadata, "annotations", {})
    some key in object.keys(annotations); contains(lower(key), "checksum")
}
deny contains "Visibility ConfigMap must contain only its public allowlist" if {
    input.kind == "ConfigMap"; endswith(input.metadata.name, "-provider-visibility")
    object.keys(input.data) != {"visible-providers"}
}
deny contains "Visibility ConfigMap must not contain binary data" if {
    input.kind == "ConfigMap"; endswith(input.metadata.name, "-provider-visibility")
    input.binaryData
}
deny contains "Visibility ConfigMap allows only supported lowercase IDs or an explicit empty value" if {
    input.kind == "ConfigMap"; endswith(input.metadata.name, "-provider-visibility")
    value := input.data["visible-providers"]; value != ""
    some item in split(value, ","); not item in {"facebook", "microsoft", "google", "github"}
}
