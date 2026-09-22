# charts

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

Production-grade Helm chart for Platform microservices

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Platform DevOps Team | <platform@example.com> |  |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalPorts | list | `[]` | Extra container ports beyond the primary one, e.g. `- name: metrics\n  containerPort: 9090`. |
| affinity | object | `{}` | Affinity/anti-affinity rules. |
| args | list | `[]` | Override the container args. |
| autoscaling.behavior.scaleDown.policies[0].periodSeconds | int | `60` | Time window each scale-down step applies to. |
| autoscaling.behavior.scaleDown.policies[0].type | string | `"Pods"` | Policy unit: `Pods` (absolute count) or `Percent` (percentage of current replicas). |
| autoscaling.behavior.scaleDown.policies[0].value | int | `1` | Max pods removed per scale-down step. |
| autoscaling.behavior.scaleDown.stabilizationWindowSeconds | int | `300` | Seconds the HPA waits with low utilization before it's allowed to scale down (prevents flapping). |
| autoscaling.behavior.scaleUp.policies[0].periodSeconds | int | `30` | Time window each scale-up step applies to. |
| autoscaling.behavior.scaleUp.policies[0].type | string | `"Pods"` | Policy unit: `Pods` (absolute count) or `Percent` (percentage of current replicas). |
| autoscaling.behavior.scaleUp.policies[0].value | int | `2` | Max pods added per scale-up step. |
| autoscaling.behavior.scaleUp.stabilizationWindowSeconds | int | `0` | Seconds the HPA waits before scaling up again (0 = react immediately). |
| autoscaling.enabled | bool | `false` | Create a HorizontalPodAutoscaler instead of a fixed `replicaCount`. |
| autoscaling.maxReplicas | int | `5` | Ceiling replica count the HPA will never scale above. |
| autoscaling.minReplicas | int | `1` | Floor replica count the HPA will never scale below. |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target average CPU utilization (% of the `resources.requests.cpu` value) before scaling out. |
| autoscaling.targetMemoryUtilizationPercentage | string | `""` | Target average memory utilization (% of `resources.requests.memory`). Leave empty to disable memory-based scaling. |
| command | list | `[]` | Override the container entrypoint. |
| commonLabels | object | `{}` | Extra labels applied to every resource this chart creates. |
| configMap.data | object | `{}` | Key/value data for the generated ConfigMap. |
| configMap.enabled | bool | `false` | Create a ConfigMap and mount it via `envFrom`. |
| containerPort | int | `8080` | Primary container port the app listens on. Also used as the default target for probes and the Service. |
| deploymentAnnotations."reloader.stakater.com/auto" | string | `"true"` | Triggers a rolling restart via Stakater Reloader whenever a referenced ConfigMap/Secret changes. |
| dnsConfig | object | `{}` | Custom DNS config (nameservers, search domains, options). |
| dnsPolicy | string | `"ClusterFirst"` | Pod DNS policy. |
| env | list | `[]` | Plain environment variables injected into the container. |
| envFrom | list | `[]` | `envFrom` sources (ConfigMaps/Secrets) beyond the ones this chart manages itself. |
| envFromSecret.enabled | bool | `false` | Inject all keys from an existing Secret as environment variables. |
| envFromSecret.secretName | string | `""` | Name of the existing Secret to source env vars from. Required when `envFromSecret.enabled` is true. |
| fullnameOverride | string | `""` | Override the full resource name (skips the chart name + release name concatenation). |
| global.imagePullSecrets | list | `[]` | Image pull secrets applied to every release using this chart, regardless of namespace. |
| hostAliases | list | `[]` | Extra `/etc/hosts` entries for the pod. |
| hostNetwork | bool | `false` | Use the host's network namespace. |
| httproute.enabled | bool | `false` | Create Gateway API HTTPRoute(s) to expose the Service through the shared `platform-gateway`. |
| httproute.gateway.name | string | `"platform-gateway"` | Name of the shared Gateway resource to attach to. |
| httproute.gateway.namespace | string | `"istio-system"` | Namespace the Gateway lives in. |
| httproute.gateway.sectionName | string | `"slicearrow-http"` | HTTP listener section name on the Gateway (used directly when `redirectToHttps` is false, or for the redirect route when true). |
| httproute.gateway.sectionNameHttps | string | `"slicearrow-https"` | HTTPS listener section name on the Gateway (only used when `redirectToHttps` is true). |
| httproute.hostnames | list | `[]` | Hostnames the route(s) match on, e.g. `my-service.example.com`. |
| httproute.redirectToHttps | bool | `true` | When true, creates both an HTTP→HTTPS redirect route and a separate HTTPS route. When false, creates a single route bound to `gateway.sectionName` only. |
| httproute.requestTimeout | string | `"0s"` | Request timeout applied to the HTTPS route, e.g. `30s`. `0s` means no timeout. |
| image.name | string | `""` | Full image reference, e.g. `ghcr.io/org/app:v1.0.0@sha256:...`. Required — the Deployment will fail to roll out if left empty. |
| image.pullPolicy | string | `"IfNotPresent"` | Kubelet image pull policy. |
| image.pullSecrets | list | `[]` | Per-image pull secrets, merged with `global.imagePullSecrets`. |
| lifecycle.preStop.exec.command | list | `["/bin/sh","-c","sleep 10"]` | Command run before the container receives SIGTERM. Default sleeps 10s to let in-flight requests drain and the endpoint be removed from Service/Istio routing. |
| livenessProbe.enabled | bool | `true` | Enable the liveness probe. |
| livenessProbe.exec.command | list | `[]` | Command run inside the container for an `exec` probe. |
| livenessProbe.failureThreshold | int | `6` | Consecutive failures before the pod is restarted. |
| livenessProbe.grpc.port | int | `8080` | Port checked by a `grpc` probe. |
| livenessProbe.grpc.service | string | `""` | Optional gRPC health service name. |
| livenessProbe.httpGet.httpHeaders | list | `[]` | Extra HTTP headers sent with the probe request. |
| livenessProbe.httpGet.path | string | `"/healthz"` | HTTP path checked by the probe. |
| livenessProbe.httpGet.port | int | `8080` | Port checked by the probe. |
| livenessProbe.httpGet.scheme | string | `"HTTP"` | HTTP scheme: `HTTP` or `HTTPS`. |
| livenessProbe.initialDelaySeconds | int | `60` | Seconds to wait after container start before the first probe. |
| livenessProbe.periodSeconds | int | `30` | Seconds between probe checks. |
| livenessProbe.successThreshold | int | `1` | Consecutive successes needed to mark the probe as passing. |
| livenessProbe.tcpSocket.port | int | `8080` | Port checked by a `tcpSocket` probe. |
| livenessProbe.timeoutSeconds | int | `15` | Seconds before a probe attempt times out. |
| livenessProbe.type | string | `"httpGet"` | Probe mechanism: `httpGet`, `exec`, `tcpSocket`, or `grpc`. |
| nameOverride | string | `""` | Override the chart name portion used to build resource names. |
| namespaceOverride | string | `""` | Override the namespace resources are deployed into (defaults to the release namespace). |
| networkPolicy.egress | list | `[{}]` | Egress rules. Defaults to allowing all egress — restrict this to DNS + required upstreams for actual network isolation. |
| networkPolicy.enabled | bool | `false` | Create a NetworkPolicy restricting traffic to/from the pod. Note the default egress rule below is wide open — tighten it before relying on this for real isolation. |
| networkPolicy.ingress | list | `[{"from":[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"istio-system"}}},{"podSelector":{}}]}]` | Ingress rules. Defaults to allowing traffic from the Istio sidecar namespace and same-namespace pods. |
| nodeSelector | object | `{}` | Node selector constraints for pod scheduling. |
| podAnnotations | object | `{}` | Extra annotations applied to pods only. |
| podDisruptionBudget.enabled | bool | `false` | Create a PodDisruptionBudget to keep pods available during voluntary disruptions (node drains, cluster upgrades). |
| podDisruptionBudget.minAvailable | int | `1` | Minimum pods that must stay available. Set only one of `minAvailable`/`maxUnavailable`. |
| podLabels | object | `{}` | Extra labels applied to pods only. |
| podSecurityContext.fsGroup | int | `1000` | GID applied to mounted volumes. |
| podSecurityContext.runAsGroup | int | `1000` | GID the pod runs as. |
| podSecurityContext.runAsNonRoot | bool | `true` | Require the pod to run as a non-root user. |
| podSecurityContext.runAsUser | int | `1000` | UID the pod runs as. |
| podSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` | Seccomp profile type. |
| priorityClassName | string | `""` | PriorityClass name applied to the pod. |
| rbac.clusterRules | list | `[]` | Cluster-scoped rules — creates a ClusterRole + ClusterRoleBinding. |
| rbac.enabled | bool | `false` | Create RBAC resources (Role/RoleBinding and/or ClusterRole/ClusterRoleBinding) for the pod's ServiceAccount. |
| rbac.rules | list | `[]` | Namespace-scoped rules — creates a Role + RoleBinding. |
| readinessProbe.enabled | bool | `true` | Enable the readiness probe. |
| readinessProbe.exec.command | list | `[]` | Command run inside the container for an `exec` probe. |
| readinessProbe.failureThreshold | int | `3` | Consecutive failures needed to mark the pod as not-ready. |
| readinessProbe.grpc.port | int | `8080` | Port checked by a `grpc` probe. |
| readinessProbe.grpc.service | string | `""` | Optional gRPC health service name. |
| readinessProbe.httpGet.httpHeaders | list | `[]` | Extra HTTP headers sent with the probe request. |
| readinessProbe.httpGet.path | string | `"/healthz"` | HTTP path checked by the probe. |
| readinessProbe.httpGet.port | int | `8080` | Port checked by the probe. |
| readinessProbe.httpGet.scheme | string | `"HTTP"` | HTTP scheme: `HTTP` or `HTTPS`. |
| readinessProbe.initialDelaySeconds | int | `15` | Seconds to wait after container start before the first probe. |
| readinessProbe.periodSeconds | int | `30` | Seconds between probe checks. |
| readinessProbe.successThreshold | int | `1` | Consecutive successes needed to mark the probe as passing. |
| readinessProbe.tcpSocket.port | int | `8080` | Port checked by a `tcpSocket` probe. |
| readinessProbe.timeoutSeconds | int | `15` | Seconds before a probe attempt times out. |
| readinessProbe.type | string | `"httpGet"` | Probe mechanism: `httpGet`, `exec`, `tcpSocket`, or `grpc`. |
| replicaCount | int | `1` | Number of pod replicas. Acts as the floor when `autoscaling.enabled` is true. |
| resources.limits.memory | string | `"256Mi"` | Hard memory ceiling — exceeding it gets the pod OOMKilled. No `cpu` limit is set by default; CPU limits cause throttling even when the node has spare capacity, so most production setups only request CPU and never cap it. |
| resources.requests.cpu | string | `"100m"` | Guaranteed CPU. Used by the scheduler and as the baseline for HPA CPU utilization. Intentionally has no matching limit to avoid CPU throttling — see CPU limit note below. |
| resources.requests.memory | string | `"128Mi"` | Guaranteed memory. |
| rollout.analysis.enabled | bool | `false` | Generate a k6 + Prometheus pre-promotion gate. Requires rollout.enabled and autoPromotionEnabled. |
| rollout.analysis.k6.duration | string | `"30s"` |  |
| rollout.analysis.k6.image | string | `"grafana/k6:1.0.0"` | k6 image used by the AnalysisRun Job. |
| rollout.analysis.k6.maxFailureRate | float | `0.05` | Fail if HTTP failures reach this rate or p95 latency reaches this many milliseconds. |
| rollout.analysis.k6.maxP95Ms | int | `1000` |  |
| rollout.analysis.k6.path | string | `"/"` | Safe, read-only endpoint on the preview Service to load test. |
| rollout.analysis.k6.vus | int | `5` | Number of virtual users and load test duration. |
| rollout.analysis.prometheus.address | string | `"http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"` | In-cluster Prometheus endpoint with kube-state-metrics data. |
| rollout.analysis.prometheus.initialDelay | string | `"45s"` | Wait for scrape data after the new pods become available. |
| rollout.analysis.prometheus.minReadyPods | int | `1` | Minimum number of ready preview containers seen by Prometheus. |
| rollout.blueGreen.autoPromotionEnabled | bool | `true` | Promote automatically after the preview pods and any pre-promotion analysis pass. |
| rollout.blueGreen.postPromotionAnalysis | object | `{}` |  |
| rollout.blueGreen.prePromotionAnalysis | object | `{}` | Optional AnalysisRun template references and args, created separately. |
| rollout.blueGreen.previewReplicaCount | int | `0` | Optional preview pod count; 0 means use replicaCount. |
| rollout.blueGreen.scaleDownDelaySeconds | int | `60` | Seconds to retain the old ReplicaSet after the Service switch. |
| rollout.enabled | bool | `false` | Create an Argo Rollout instead of a Deployment. |
| rollout.minReadySeconds | int | `10` | Time a new pod must stay ready before Rollouts considers it available. |
| rollout.progressDeadlineAbort | bool | `true` | Abort an update that exceeds progressDeadlineSeconds. |
| rollout.progressDeadlineSeconds | int | `600` | Maximum seconds for an update to make progress. |
| rollout.revisionHistoryLimit | int | `3` | Number of old ReplicaSets to retain for rollback. |
| rollout.strategy | object | `{}` | Advanced override for the complete spec.strategy: blueGreen or canary. Empty uses the blue/green options below. |
| runtimeClassName | string | `""` | RuntimeClass name applied to the pod (e.g. for gVisor/Kata sandboxes). |
| securityContext.allowPrivilegeEscalation | bool | `false` | Disallow privilege escalation inside the container. |
| securityContext.capabilities.drop | list | `["ALL"]` | Linux capabilities to drop from the container. |
| securityContext.readOnlyRootFilesystem | bool | `true` | Mount the container's root filesystem as read-only. |
| securityContext.runAsGroup | int | `1000` | GID the container runs as. |
| securityContext.runAsNonRoot | bool | `true` | Require the container to run as a non-root user. |
| securityContext.runAsUser | int | `1000` | UID the container runs as. |
| securityContext.seccompProfile.type | string | `"RuntimeDefault"` | Seccomp profile type. |
| service.additionalPorts | list | `[]` | Extra Service ports beyond the primary one. |
| service.annotations | object | `{}` | Extra annotations applied to the Service. |
| service.labels | object | `{}` | Extra labels applied to the Service. |
| service.loadBalancerSourceRanges | list | `[]` | CIDRs allowed to reach a `LoadBalancer` type Service. |
| service.port | int | `80` | Port the Service listens on. |
| service.protocol | string | `"TCP"` | Service port protocol. |
| service.sessionAffinity | string | `"None"` | Service session affinity: `None` or `ClientIP`. |
| service.targetPort | int | `8080` | Pod port the Service forwards traffic to. |
| service.type | string | `"ClusterIP"` | Kubernetes Service type: `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| serviceAccount.annotations | object | `{}` | Annotations applied to the ServiceAccount (e.g. for IRSA/Workload Identity). |
| serviceAccount.automountServiceAccountToken | bool | `false` | Mount the ServiceAccount token into the pod. |
| serviceAccount.create | bool | `false` | Create a dedicated ServiceAccount for the pod. Should be `true` whenever `rbac.enabled` is true, otherwise the generated RoleBinding points at a ServiceAccount that doesn't exist. |
| serviceAccount.name | string | `""` | Name of the ServiceAccount. Defaults to the chart's fullname if empty. |
| shareProcessNamespace | bool | `false` | Share the process namespace between containers in the pod. |
| startupProbe.enabled | bool | `false` | Enable the startup probe. Useful for slow-starting apps so liveness/readiness don't kill the pod prematurely. |
| startupProbe.exec.command | list | `[]` | Command run inside the container for an `exec` probe. |
| startupProbe.failureThreshold | int | `30` | Consecutive failures allowed before the pod is killed for never starting up. |
| startupProbe.grpc.port | int | `8080` | Port checked by a `grpc` probe. |
| startupProbe.grpc.service | string | `""` | Optional gRPC health service name. |
| startupProbe.httpGet.httpHeaders | list | `[]` | Extra HTTP headers sent with the probe request. |
| startupProbe.httpGet.path | string | `"/healthz"` | HTTP path checked by the probe. |
| startupProbe.httpGet.port | int | `8080` | Port checked by the probe. |
| startupProbe.httpGet.scheme | string | `"HTTP"` | HTTP scheme: `HTTP` or `HTTPS`. |
| startupProbe.initialDelaySeconds | int | `0` | Seconds to wait after container start before the first probe. |
| startupProbe.periodSeconds | int | `10` | Seconds between probe checks. |
| startupProbe.successThreshold | int | `1` | Consecutive successes needed to mark the probe as passing. |
| startupProbe.tcpSocket.port | int | `8080` | Port checked by a `tcpSocket` probe. |
| startupProbe.timeoutSeconds | int | `15` | Seconds before a probe attempt times out. |
| startupProbe.type | string | `"httpGet"` | Probe mechanism: `httpGet`, `exec`, `tcpSocket`, or `grpc`. |
| strategy.rollingUpdate.maxSurge | int | `1` | Max number of extra pods created above `replicaCount` during a rollout. |
| strategy.rollingUpdate.maxUnavailable | int | `0` | Max number of pods that can be unavailable during a rollout. |
| strategy.type | string | `"RollingUpdate"` | Deployment strategy type: `RollingUpdate` or `Recreate`. |
| terminationGracePeriodSeconds | int | `30` | Seconds the pod is given to shut down gracefully before being force-killed. |
| tmpVolume.enabled | bool | `true` | Mount an emptyDir at `/tmp`. Needed whenever `securityContext.readOnlyRootFilesystem` is true and the app needs to write temp files. |
| tmpVolume.sizeLimit | string | `"1Gi"` | Size limit of the `/tmp` emptyDir. |
| tolerations | list | `[]` | Tolerations for scheduling onto tainted nodes. |
| topologySpreadConstraints.constraints[0].maxSkew | int | `1` | Max difference in pod count allowed between topology domains. |
| topologySpreadConstraints.constraints[0].topologyKey | string | `"kubernetes.io/hostname"` | Node label used to define topology domains, e.g. `kubernetes.io/hostname` or `topology.kubernetes.io/zone`. |
| topologySpreadConstraints.constraints[0].whenUnsatisfiable | string | `"DoNotSchedule"` | What the scheduler does when the constraint can't be satisfied: `DoNotSchedule` or `ScheduleAnyway`. |
| topologySpreadConstraints.enabled | bool | `false` | Spread pod replicas across topology domains (e.g. nodes) to avoid co-locating all of them on one host. |
| volumeMounts | list | `[]` | Extra volume mounts on the main container. |
| volumes | list | `[]` | Extra volumes to attach to the pod. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
