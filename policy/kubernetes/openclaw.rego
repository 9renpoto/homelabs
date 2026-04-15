package main

# --- Common helper functions ---

workload_kind(kind) {
  kind == "Pod"
} else {
  kind == "Deployment"
} else {
  kind == "StatefulSet"
} else {
  kind == "DaemonSet"
} else {
  kind == "Job"
} else {
  kind == "CronJob"
}

pod_spec(obj) = spec {
  workload_kind(obj.kind)
  obj.kind == "Pod"
  spec := obj.spec
} else = spec {
  workload_kind(obj.kind)
  obj.kind == "CronJob"
  spec := obj.spec.jobTemplate.spec.template.spec
} else = spec {
  workload_kind(obj.kind)
  obj.kind != "Pod"
  obj.kind != "CronJob"
  spec := obj.spec.template.spec
}

all_containers(spec) := containers {
  containers := array.concat(
    object.get(spec, "initContainers", []),
    object.get(spec, "containers", []),
  )
}

# --- Deny rules ---

# 1. Secrets must not be committed
deny[msg] {
  input.kind == "Secret"
  msg := sprintf("Secret %s must not be committed to the public repository", [input.metadata.name])
}

# 2. Namespace openclaw-system must enforce pod-security restricted
deny[msg] {
  input.kind == "Namespace"
  input.metadata.name == "openclaw-system"
  input.metadata.labels["pod-security.kubernetes.io/enforce"] != "restricted"
  msg := "Namespace openclaw-system must enforce pod-security restricted"
}

# 3. Disallowed Service types
deny[msg] {
  input.kind == "Service"
  service_type := object.get(input.spec, "type", "ClusterIP")
  disallowed_service_type(service_type)
  msg := sprintf("Service %s must not use %s", [input.metadata.name, service_type])
}

disallowed_service_type(service_type) {
  service_type == "NodePort"
} else {
  service_type == "LoadBalancer"
}

# 4. hostPath volumes are generally disallowed
deny[msg] {
  spec := pod_spec(input)
  volume := object.get(spec, "volumes", [])[_]
  volume.hostPath
  not allowed_hostpath_volume(input, volume)
  msg := sprintf("%s/%s must not use hostPath volume %s", [input.kind, input.metadata.name, volume.name])
}

allowed_hostpath_volume(obj, volume) {
  nvidia_device_plugin(obj)
  volume.name == "kubelet-device-plugins-dir"
  volume.hostPath.path == "/var/lib/kubelet/device-plugins"
  volume.hostPath.type == "Directory"
}

# 5. Image tags must not be latest (explicitly or implicitly)
deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  is_latest_tag(container.image)
  msg := sprintf("%s/%s must not use latest tag in container %s", [input.kind, input.metadata.name, container.name])
}

is_latest_tag(image) {
  endswith(image, ":latest")
} else {
  not contains(image, ":")
}

# 6. Pod Security Standards: Restricted profile requirements

# runAsNonRoot: true
deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  not is_run_as_non_root(spec, container)
  not allowed_missing_run_as_non_root(input, container)
  msg := sprintf("%s/%s container %s must set runAsNonRoot: true", [input.kind, input.metadata.name, container.name])
}

is_run_as_non_root(spec, container) {
  object.get(object.get(container, "securityContext", {}), "runAsNonRoot", false) == true
} else {
  object.get(object.get(spec, "securityContext", {}), "runAsNonRoot", false) == true
}

allowed_missing_run_as_non_root(obj, container) {
  nvidia_device_plugin(obj)
  container.name == "nvidia-device-plugin-ctr"
}

# allowPrivilegeEscalation: false
deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  object.get(object.get(container, "securityContext", {}), "allowPrivilegeEscalation", true)
  msg := sprintf("%s/%s container %s must set allowPrivilegeEscalation: false", [input.kind, input.metadata.name, container.name])
}

# privileged: false
deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  object.get(object.get(container, "securityContext", {}), "privileged", false)
  msg := sprintf("%s/%s container %s must not run privileged", [input.kind, input.metadata.name, container.name])
}

# Capabilities: must drop ALL
deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  dropped := object.get(object.get(object.get(container, "securityContext", {}), "capabilities", {}), "drop", [])
  not dropped_all(dropped)
  msg := sprintf("%s/%s container %s must drop ALL capabilities", [input.kind, input.metadata.name, container.name])
}

dropped_all(dropped) {
  dropped[_] == "ALL"
}

# seccompProfile: must be RuntimeDefault or Localhost
deny[msg] {
  spec := pod_spec(input)
  not valid_seccomp_profile(spec)
  msg := sprintf("%s/%s must set seccompProfile to RuntimeDefault or Localhost", [input.kind, input.metadata.name])
}

valid_seccomp_profile(spec) {
  profile := object.get(object.get(spec, "securityContext", {}), "seccompProfile", {})
  is_valid_profile_type(profile.type)
} else {
  # Also check at container level if not set at pod level?
  # PSS restricted says pod-level OR container-level. For simplicity, we can check containers too.
  containers := all_containers(spec)
  all_containers_have_seccomp(containers)
}

all_containers_have_seccomp(containers) {
  count([c | c := containers[_]; is_valid_profile_type(object.get(object.get(c, "securityContext", {}), "seccompProfile", {}).type)]) == count(containers)
}

is_valid_profile_type(type) {
  type == "RuntimeDefault"
} else {
  type == "Localhost"
}

# readOnlyRootFilesystem: true (Recommended for restricted)
deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  not object.get(object.get(container, "securityContext", {}), "readOnlyRootFilesystem", false)
  not nvidia_device_plugin(input) # Exception for some system-ish tools if needed
  msg := sprintf("%s/%s container %s must set readOnlyRootFilesystem: true", [input.kind, input.metadata.name, container.name])
}

# --- ArgoCD specific rules ---

deny[msg] {
  input.kind == "Application"
  input.metadata.namespace != "argocd"
  msg := sprintf("ArgoCD Application %s must live in namespace argocd", [input.metadata.name])
}

deny[msg] {
  input.kind == "Application"
  input.spec.source.targetRevision != "main"
  msg := sprintf("ArgoCD Application %s must pin targetRevision to main", [input.metadata.name])
}

deny[msg] {
  input.kind == "Application"
  input.metadata.name == "openclaw-core"
  input.spec.project != "openclaw-core"
  msg := "ArgoCD Application openclaw-core must use project openclaw-core"
}

deny[msg] {
  input.kind == "Application"
  input.metadata.name == "openclaw-core"
  input.spec.destination.namespace != "openclaw-system"
  msg := "ArgoCD Application openclaw-core must deploy to openclaw-system"
}

deny[msg] {
  input.kind == "Application"
  input.metadata.name == "openclaw-bootstrap"
  input.spec.project != "default"
  msg := "ArgoCD Application openclaw-bootstrap must use project default"
}

deny[msg] {
  input.kind == "Application"
  input.metadata.name == "openclaw-bootstrap"
  input.spec.destination.namespace != "argocd"
  msg := "ArgoCD Application openclaw-bootstrap must deploy to argocd namespace"
}

deny[msg] {
  input.kind == "Application"
  input.metadata.name == "openclaw-bootstrap"
  input.spec.source.path != "gitops/argocd"
  msg := "ArgoCD Application openclaw-bootstrap must target gitops/argocd"
}

deny[msg] {
  input.kind == "AppProject"
  input.metadata.namespace != "argocd"
  msg := sprintf("ArgoCD AppProject %s must live in namespace argocd", [input.metadata.name])
}

deny[msg] {
  input.kind == "AppProject"
  input.metadata.name == "openclaw-core"
  not repo_allowed(input.spec.sourceRepos)
  msg := "ArgoCD AppProject openclaw-core must only allow the homelabs repository"
}

deny[msg] {
  input.kind == "AppProject"
  input.metadata.name == "openclaw-core"
  not destination_allowed(input.spec.destinations, "openclaw-system")
  msg := "ArgoCD AppProject openclaw-core must allow destination namespace openclaw-system"
}

deny[msg] {
  input.kind == "AppProject"
  input.metadata.name == "openclaw-core"
  not destination_allowed(input.spec.destinations, "argocd")
  msg := "ArgoCD AppProject openclaw-core must allow destination namespace argocd"
}

repo_allowed(source_repos) {
  count(source_repos) == 1
  source_repos[0] == "https://github.com/9renpoto/homelabs.git"
}

destination_allowed(destinations, namespace) {
  destination := destinations[_]
  destination.namespace == namespace
  destination.server == "https://kubernetes.default.svc"
}

nvidia_device_plugin(obj) {
  obj.kind == "DaemonSet"
  obj.metadata.namespace == "kube-system"
  obj.metadata.name == "nvidia-device-plugin-daemonset"
}
