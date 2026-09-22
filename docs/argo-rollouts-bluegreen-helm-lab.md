# Argo Rollouts blue/green Helm lab

This runbook tests the repository's shared Helm chart with the official Argo
Rollouts color application. It installs blue as the active version, upgrades
to green or yellow, tests the preview with k6 and Prometheus, and automatically
switches the active Service only after the checks pass.

The lab is intentionally separate from `small-go-webserver` and uses:

- Namespace: `rollouts-lab`
- Helm release and Rollout: `rollouts-helm`
- Active Service and HTTPRoute backend: `rollouts-helm`
- Preview Service: `rollouts-helm-preview`
- Public lab URL: `http://rollouts-helm.example.com`
- Dashboard: `https://argo-rollouts.example.com/rollouts/`
- Values: [`rollouts-helm-lab-values.yaml`](rollouts-helm-lab-values.yaml)

The lab uses HTTP only. It demonstrates rollout behavior, not a production TLS
configuration.

## 1. Understand the traffic flow

During a rollout, users and tests use different Services:

```text
Users -> HTTPRoute -> rollouts-helm         -> current active pods
k6    -> cluster DNS -> rollouts-helm-preview -> new preview pods
```

For a blue-to-green update:

```text
Before upgrade:
  active  -> blue
  preview -> blue

While preview analysis runs:
  active  -> blue
  preview -> green

After successful promotion:
  active  -> green
  preview -> green
```

Both Services pointing to green after promotion is expected. A preview pod is
not a special type of pod: the same green ReplicaSet that was preview becomes
active. Argo Rollouts leaves the preview Service on that ReplicaSet until the
next update. On the next update, active stays on green while preview moves to
the next ReplicaSet.

The external HTTPRoute always targets only the active Service. Users do not
reach the preview Service unless someone exposes or port-forwards it explicitly.

Blue/green changes the Service selector in one operation; it does not gradually
mix application traffic. Existing connections can finish on the old pods while
new connections use the promoted pods. The old ReplicaSet is retained for
`scaleDownDelaySeconds` and is then scaled to zero.

## 2. Prerequisites

Run every command from the repository root:

```bash
cd ~/platform/k8s-gitops
```

Select the local cluster in the current shell:

```bash
kube-local
kubectl config current-context
```

Expected context:

```text
kubernetes-admin@kubernetes
```

`kube-local` is a shell alias that exports
`KUBECONFIG=$HOME/.kube/local.yaml`. For scripts or a new non-interactive
shell, set it explicitly:

```bash
export KUBECONFIG="$HOME/.kube/local.yaml"
```

Confirm the required tools and cluster components:

```bash
helm version --short
kubectl version --client
kubectl get crd rollouts.argoproj.io analysistemplates.argoproj.io analysisruns.argoproj.io
kubectl -n argo-rollouts get deployment argo-rollouts argo-rollouts-dashboard
kubectl -n monitoring get service kube-prometheus-stack-prometheus
kubectl -n agentgateway-system get gateway agentgateway
```

This runbook was verified with Helm 4. Helm 4 uses server-side apply by
default, but Argo Rollouts dynamically owns
`spec.selector.rollouts-pod-template-hash` on the active and preview Services.
Every Helm install, upgrade, and rollback command in this runbook therefore
uses `--server-side=false`.

Do not replace that flag with `--force-conflicts`. Forcing ownership can make
Helm overwrite a selector that Argo Rollouts is actively managing, temporarily
causing incorrect or mixed endpoints.

## 3. Inspect what cleanup will remove

The reset in the next section deletes the entire `rollouts-lab` namespace.
Confirm that it contains only disposable lab resources:

```bash
kubectl get all,rollout,analysisrun,analysistemplate,httproute -n rollouts-lab
helm list -n rollouts-lab
```

If the namespace contains anything that must be retained, stop and delete only
the old lab release/resources instead of deleting the namespace.

## 4. Reset the lab

The following commands permanently remove everything in `rollouts-lab` and
recreate an empty namespace:

```bash
helm uninstall rollouts-helm -n rollouts-lab --ignore-not-found || true
kubectl delete namespace rollouts-lab --ignore-not-found --wait=true
kubectl create namespace rollouts-lab
```

Confirm that it is empty:

```bash
kubectl get all -n rollouts-lab
helm list -n rollouts-lab
```

## 5. Validate the chart before installation

Lint and render the exact lab configuration:

```bash
helm lint ./charts \
  --values docs/rollouts-helm-lab-values.yaml
```

```bash
helm template rollouts-helm ./charts \
  --namespace rollouts-lab \
  --values docs/rollouts-helm-lab-values.yaml \
  > /tmp/rollouts-helm-rendered.yaml
```

Confirm that the render contains the Rollout, two Services, AnalysisTemplate,
k6 ConfigMap, and HTTPRoute:

```bash
rg '^kind: (Rollout|Service|AnalysisTemplate|ConfigMap|HTTPRoute)$' \
  /tmp/rollouts-helm-rendered.yaml
```

The expected important resources are:

```text
ConfigMap/rollouts-helm-k6
Service/rollouts-helm
Service/rollouts-helm-preview
AnalysisTemplate/rollouts-helm-gate
HTTPRoute/rollouts-helm
Rollout/rollouts-helm
```

## 6. Install blue

Install the chart with blue as the initial version:

```bash
helm install rollouts-helm ./charts \
  --namespace rollouts-lab \
  --values docs/rollouts-helm-lab-values.yaml \
  --server-side=false
```

Inspect the release and workload:

```bash
helm status rollouts-helm -n rollouts-lab
helm get values rollouts-helm -n rollouts-lab
kubectl get rollout,replicaset,pod,service,analysistemplate,httproute \
  -n rollouts-lab -o wide
```

Wait until the initial Rollout is healthy:

```bash
until [ "$(kubectl get rollout rollouts-helm -n rollouts-lab \
  -o jsonpath='{.status.phase}')" = "Healthy" ]; do
  kubectl get rollout rollouts-helm -n rollouts-lab
  sleep 2
done
```

Verify that the active Service returns blue through the Kubernetes API proxy:

```bash
kubectl get --raw \
  '/api/v1/namespaces/rollouts-lab/services/http:rollouts-helm:80/proxy/color'
```

Expected response:

```text
"blue"
```

## 7. Verify the HTTPRoute and DNS

Check the route attachment:

```bash
kubectl get httproute rollouts-helm -n rollouts-lab -o wide
kubectl describe httproute rollouts-helm -n rollouts-lab
```

The parent status must show `Accepted=True` and `ResolvedRefs=True`.

Confirm DNS and the public response:

```bash
getent hosts rollouts-helm.example.com
curl --fail --show-error http://rollouts-helm.example.com/color
```

Expected response:

```text
"blue"
```

If DNS has not propagated but the request is being made from the local network,
test the Gateway directly while preserving the required Host header:

```bash
curl --fail --show-error \
  --header 'Host: rollouts-helm.example.com' \
  http://192.168.1.100/color
```

## 8. Start the uninterrupted user-traffic check

Open a separate terminal, select the cluster with `kube-local`, and keep this
loop running throughout the upgrade:

```bash
while true; do
  printf '%s ' "$(date '+%H:%M:%S.%3N')"

  curl \
    --silent \
    --show-error \
    --connect-timeout 1 \
    --max-time 2 \
    --write-out ' HTTP=%{http_code} TIME=%{time_total}s\n' \
    http://rollouts-helm.example.com/color || echo ' REQUEST_FAILED'

  sleep 0.05
done
```

Before the upgrade, every successful request should show blue and HTTP 200:

```text
"blue" HTTP=200 TIME=0.00...s
```

The test's zero-downtime acceptance condition is zero failed user requests:

- No `HTTP=000`
- No `4xx` or `5xx`
- No timeout
- No `REQUEST_FAILED`
- Responses change directly from blue to green/yellow without alternating

Blue/green minimizes deployment interruption, but no system can promise
literal zero-millisecond latency across DNS, the network, Gateway, nodes, and
clients. Measure zero failed requests and track latency separately.

## 9. Upgrade blue to green

Keep the curl loop running. In another terminal, run:

```bash
kube-local
```

```bash
helm upgrade rollouts-helm ./charts \
  --namespace rollouts-lab \
  --reuse-values \
  --server-side=false \
  --set image.name=argoproj/rollouts-demo:green
```

Watch the Rollout:

```bash
kubectl get rollout rollouts-helm -n rollouts-lab --watch
```

In another terminal, watch the AnalysisRun and k6 Job:

```bash
kubectl get analysisrun,job,pod -n rollouts-lab --watch
```

While analysis is running, verify the split explicitly:

```bash
printf 'active:  '
kubectl get --raw \
  '/api/v1/namespaces/rollouts-lab/services/http:rollouts-helm:80/proxy/color'
printf '\npreview: '
kubectl get --raw \
  '/api/v1/namespaces/rollouts-lab/services/http:rollouts-helm-preview:80/proxy/color'
printf '\n'
```

Expected before promotion:

```text
active:  "blue"
preview: "green"
```

The generated pre-promotion AnalysisRun performs both checks:

1. k6 sends load to `rollouts-helm-preview.rollouts-lab.svc.cluster.local`
   at `/color` for 30 seconds. It requires an error rate below 5% and p95
   latency below 1000 ms.
2. Prometheus checks that at least two containers in the preview ReplicaSet are
   ready according to kube-state-metrics.

Because `autoPromotionEnabled=true`, successful analysis automatically changes
the active Service selector to the green ReplicaSet. There is no manual Promote
step.

After promotion, verify the public response:

```bash
curl --fail --show-error http://rollouts-helm.example.com/color
```

Expected:

```text
"green"
```

Verify the final state:

```bash
kubectl get rollout rollouts-helm -n rollouts-lab \
  -o jsonpath='phase={.status.phase}{"\n"}stableRS={.status.stableRS}{"\n"}currentHash={.status.currentPodHash}{"\n"}'
```

```bash
kubectl get service rollouts-helm rollouts-helm-preview \
  -n rollouts-lab \
  -o custom-columns=NAME:.metadata.name,HASH:.spec.selector.rollouts-pod-template-hash
```

Both Services should now show the same green hash. After the 30-second
scale-down delay, the blue ReplicaSet should have zero desired pods:

```bash
kubectl get replicaset,pod -n rollouts-lab -o wide
```

## 10. Upgrade green to yellow

Use the same client-side-apply flag for every later upgrade:

```bash
helm upgrade rollouts-helm ./charts \
  --namespace rollouts-lab \
  --reuse-values \
  --server-side=false \
  --set image.name=argoproj/rollouts-demo:yellow
```

The expected sequence is:

```text
active green / preview yellow
analysis running
analysis successful
active yellow / preview yellow
old green ReplicaSet scaled to zero after 30 seconds
```

## 11. Use the Argo Rollouts dashboard

Open:

```text
https://argo-rollouts.example.com/rollouts/
```

Use namespace `rollouts-lab` and select `rollouts-helm`.

The Basic Authentication username is stored in the `.htaccess` entry of this
Secret:

```bash
kubectl get secret argo-rollouts-dashboard-basic-auth \
  -n argo-rollouts \
  -o jsonpath='{.data.\.htaccess}' | base64 -d | cut -d: -f1
```

The rest of the entry is a one-way bcrypt hash, not the password. Retrieve the
password from the team's password manager. If it is lost, reset the Secret;
the original password cannot be decoded from the hash. Never commit the raw
password or generated `.htaccess` file to Git.

## 12. Manual promotion variant

The primary lab uses automatic promotion because it tests k6 and Prometheus as
a gate. To pause for a human decision instead, disable both automatic promotion
and the built-in analysis during an upgrade:

```bash
helm upgrade rollouts-helm ./charts \
  --namespace rollouts-lab \
  --reuse-values \
  --server-side=false \
  --set rollout.blueGreen.autoPromotionEnabled=false \
  --set rollout.analysis.enabled=false \
  --set image.name=argoproj/rollouts-demo:green
```

Verify the preview, then click **Promote** in the dashboard. The chart rejects
`rollout.analysis.enabled=true` together with manual promotion because its
built-in analysis is specifically an automatic pre-promotion gate.

To restore automatic gated promotion on the next upgrade:

```bash
helm upgrade rollouts-helm ./charts \
  --namespace rollouts-lab \
  --reuse-values \
  --server-side=false \
  --set rollout.blueGreen.autoPromotionEnabled=true \
  --set rollout.analysis.enabled=true
```

## 13. Failure and rollback test

The official demo publishes `bad-*` images that return errors. Keep the
continuous curl loop running, then deploy a failing preview:

```bash
helm upgrade rollouts-helm ./charts \
  --namespace rollouts-lab \
  --reuse-values \
  --server-side=false \
  --set image.name=argoproj/rollouts-demo:bad-red
```

Expected behavior:

- The preview Service selects `bad-red`.
- k6 reports failures and the AnalysisRun fails.
- Automatic promotion does not happen.
- The active Service continues serving the previous healthy color.
- The public curl loop remains HTTP 200 on the previous color.

Inspect the failure:

```bash
kubectl get rollout,analysisrun,job,pod -n rollouts-lab
kubectl describe rollout rollouts-helm -n rollouts-lab
kubectl describe analysisrun -n rollouts-lab
```

Restore the last healthy desired image, replacing `yellow` if another color was
last promoted:

```bash
helm upgrade rollouts-helm ./charts \
  --namespace rollouts-lab \
  --reuse-values \
  --server-side=false \
  --set image.name=argoproj/rollouts-demo:yellow
```

Review Helm revisions when a chart rollback is preferable:

```bash
helm history rollouts-helm -n rollouts-lab
```

Then roll back to a known successful revision, still disabling server-side
apply:

```bash
helm rollback rollouts-helm <REVISION> \
  --namespace rollouts-lab \
  --server-side=false
```

## 14. Troubleshooting

### Helm upgrade conflicts on Service selectors

Symptom:

```text
conflict with "rollouts-controller" using v1: .spec.selector
```

Cause: Helm 4 server-side apply and Argo Rollouts both encounter the Service
selector. Argo Rollouts must own the dynamic `rollouts-pod-template-hash` key.

Safe retry:

```bash
helm upgrade rollouts-helm ./charts \
  --namespace rollouts-lab \
  --reuse-values \
  --server-side=false \
  --set image.name=argoproj/rollouts-demo:green
```

Do not use `--force-conflicts` for this case.

### The Rollout remains paused

Inspect the phase, message, and AnalysisRun:

```bash
kubectl get rollout rollouts-helm -n rollouts-lab \
  -o jsonpath='phase={.status.phase}{"\n"}message={.status.message}{"\n"}'
kubectl get analysisrun -n rollouts-lab
kubectl describe analysisrun -n rollouts-lab
```

Common causes include preview pods not becoming ready, k6 threshold failures,
Prometheus being unavailable, or kube-state-metrics not yet scraping the new
pods.

### The HTTPRoute does not work

Check the route, Gateway listener, endpoints, and DNS:

```bash
kubectl describe httproute rollouts-helm -n rollouts-lab
kubectl get gateway agentgateway -n agentgateway-system
kubectl get endpointslice -n rollouts-lab \
  -l kubernetes.io/service-name=rollouts-helm
getent hosts rollouts-helm.example.com
```

The route must reference Gateway `agentgateway` in namespace
`agentgateway-system`, section `http`, and backend Service `rollouts-helm`.
It must never expose `rollouts-helm-preview` as the user-facing backend.

### Active and preview point to the same pods

This is correct after promotion. During the next update, preview moves to the
new ReplicaSet while active remains on the last promoted ReplicaSet. Do not
manually edit Service selectors; the Rollouts controller owns them and will
reconcile manual changes.

### Completed k6 pods remain visible

Completed pods named like `*.k6-preview-load.*` are AnalysisRun Job history.
They are not selected by either application Service and receive no user
traffic. For a disposable lab, remove completed analysis history with:

```bash
kubectl delete analysisrun --all -n rollouts-lab
```

Do not run that command where AnalysisRun history must be retained for audit.

### The demo pods never become ready

The demo serves health responses at `/`, not `/healthz`. Confirm that the lab
values override both probe paths. The demo image is also built from `scratch`
and has no shell, which is why the lab values set `lifecycle: null` to disable
the chart's default `/bin/sh` pre-stop command.

## 15. Final cleanup

Inspect the namespace before deleting it:

```bash
kubectl get all,rollout,analysisrun,analysistemplate,httproute -n rollouts-lab
helm list -n rollouts-lab
```

Remove only the Helm release while keeping the namespace:

```bash
helm uninstall rollouts-helm \
  --namespace rollouts-lab
```

Or remove the entire disposable lab namespace:

```bash
kubectl delete namespace rollouts-lab --wait=true
```

Confirm that the HTTPRoute, Services, Rollout, AnalysisRuns, Jobs, and pods are
gone before considering the test complete.

