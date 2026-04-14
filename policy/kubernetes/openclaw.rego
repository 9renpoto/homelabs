package main

deny[msg] {
  input.kind == "Secret"
  msg := sprintf("Secret %s must not be committed to the public repository", [input.metadata.name])
}

deny[msg] {
  input.kind == "Namespace"
  input.metadata.name == "openclaw-system"
  input.metadata.labels["pod-security.kubernetes.io/enforce"] != "baseline"
  msg := "Namespace openclaw-system must enforce pod-security baseline"
}

deny[msg] {
  input.kind == "Service"
  service_type := object.get(input.spec, "type", "ClusterIP")
  disallowed_service_type(service_type)
  msg := sprintf("Service %s must not use %s", [input.metadata.name, service_type])
}

deny[msg] {
  spec := pod_spec(input)
  volume := object.get(spec, "volumes", [])[_]
  volume.hostPath
  not allowed_hostpath_volume(input, volume)
  msg := sprintf("%s/%s must not use hostPath volume %s", [input.kind, input.metadata.name, volume.name])
}

deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  endswith(container.image, ":latest")
  msg := sprintf("%s/%s must not use latest tag in container %s", [input.kind, input.metadata.name, container.name])
}

deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  not object.get(object.get(container, "securityContext", {}), "runAsNonRoot", false)
  not allowed_missing_run_as_non_root(input, container)
  msg := sprintf("%s/%s container %s must set runAsNonRoot: true", [input.kind, input.metadata.name, container.name])
}

deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  object.get(object.get(container, "securityContext", {}), "allowPrivilegeEscalation", true)
  msg := sprintf("%s/%s container %s must set allowPrivilegeEscalation: false", [input.kind, input.metadata.name, container.name])
}

deny[msg] {
  spec := pod_spec(input)
  container := all_containers(spec)[_]
  object.get(object.get(container, "securityContext", {}), "privileged", false)
  msg := sprintf("%s/%s container %s must not run privileged", [input.kind, input.metadata.name, container.name])
}

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

disallowed_service_type(service_type) {
  service_type == "NodePort"
} else {
  service_type == "LoadBalancer"
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

allowed_hostpath_volume(obj, volume) {
  nvidia_device_plugin(obj)
  volume.name == "kubelet-device-plugins-dir"
  volume.hostPath.path == "/var/lib/kubelet/device-plugins"
  volume.hostPath.type == "Directory"
}

allowed_missing_run_as_non_root(obj, container) {
  nvidia_device_plugin(obj)
  container.name == "nvidia-device-plugin-ctr"
}

nvidia_device_plugin(obj) {
  obj.kind == "DaemonSet"
  obj.metadata.namespace == "kube-system"
  obj.metadata.name == "nvidia-device-plugin-daemonset"
}

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
