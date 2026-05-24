# k8s-gitops

GitOps repository for Kubernetes cluster. The repository is structured around Argo CD and uses an app-of-apps pattern to bootstrap cluster controllers, configure infrastructure, and deploy workloads — entirely through Git.

**Maintainer:** [luvis@luzero.io](mailto:luvis@luzero.io)

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Layout](#repository-layout)
- [Bootstrap](#bootstrap)
- [Sync Wave Order](#sync-wave-order)
- [Argo CD Projects](#argo-cd-projects)
- [Infrastructure Controllers](#infrastructure-controllers)
- [Workload Applications](#workload-applications)
- [Image Update Automation](#image-update-automation)
- [Networking and Ingress](#networking-and-ingress)
- [Storage](#storage)
- [Monitoring](#monitoring)
- [External nginx Proxy](#external-nginx-proxy)
- [Upgrade Automation](#upgrade-automation)
- [Day-to-day Workflow](#day-to-day-workflow)
- [Runtime Prerequisites](#runtime-prerequisites)

---

## Architecture Overview

```
Internet
  └── nginx reverse proxy (luzeroserver2 · 115.246.211.179)
        └── MetalLB VIP (192.168.29.100)
              └── Istio Gateway (luzero-gateway)
                    └── HTTPRoutes → Services
```

All cluster state is declared in this repository. Argo CD pulls from `main`, applies changes automatically, and self-heals any drift. No imperative `kubectl apply` is required outside of the one-time bootstrap step.

---

## Repository Layout

```text
bootstrap/
  root-application.yaml            # Argo CD entrypoint — apply once, manually
  appprojects.yaml                 # AppProject definitions for all layers
  infrastructure-controllers.yaml  # App-of-apps: wave 1
  infrastructure-configs.yaml      # App-of-apps: wave 2
  apps.yaml                        # App-of-apps: wave 3 (workloads)
  monitoring-controllers.yaml      # App-of-apps: wave 3
  monitoring-configs.yaml          # App-of-apps: wave 4

charts/
  Chart.yaml                       # Shared Helm chart for Sirpi microservices
  values.yaml                      # Default values
  templates/
    deployment.yaml
    service.yaml
    _helpers.tpl

apps/
  <app-name>/
    application.yaml               # Argo CD Application (multi-source)
    image-updater.yaml             # ImageUpdater CRD for automated image updates
    namespace.yaml
    values.yaml                    # Helm values for this workload

infrastructure/
  controllers/
    kustomization.yaml             # Kustomize entrypoint listing all controller Applications
    <controller>/
      application.yaml             # Argo CD Application
      values.yaml                  # Helm values
      resources/
        kustomization.yaml
        namespace.yaml
        [additional manifests]
  configs/
    istio/                         # Gateway, AuthorizationPolicy, Envoy filters
    kubeflow/                      # Routing, security, service patches, user config
    certificates/                  # Certificate, Namespace, ReferenceGrant
    cert-manager/                  # ClusterIssuers
    metallb/                       # IPAddressPool, L2Advertisement
    n8n/                           # HTTPRoutes
    [others]

monitoring/
  controllers/
    kustomization.yaml
    <controller>/
      application.yaml
      values.yaml
      resources/
  configs/
    routing/                       # Monitoring HTTPRoutes (Grafana, etc.)
    dashboards/                    # Grafana dashboard ConfigMaps
```

---

## Bootstrap

This repository assumes a working Kubernetes cluster with an initial Argo CD installation. It does not provision the cluster or install Argo CD from scratch.

**One-time bootstrap:**

```bash
kubectl apply -f bootstrap/root-application.yaml
```

That single command gives Argo CD a pointer to the `bootstrap/` directory. From that point on, Argo CD reconciles everything else — including its own Helm release — from Git.

**Full sequence:**

1. Provision a Kubernetes cluster with a CNI plugin.
2. Install Argo CD manually (`kubectl apply -f` or Helm).
3. Create required secrets (see [Runtime Prerequisites](#runtime-prerequisites)).
4. Apply `bootstrap/root-application.yaml`.
5. Argo CD takes over and drives all remaining sync waves.

---

## Sync Wave Order

| Wave | Application | Contents |
|------|-------------|----------|
| 0 | appprojects | AppProject definitions |
| 1 | infrastructure-controllers | CRDs, controllers, namespaces |
| 2 | infrastructure-configs | Gateway, HTTPRoutes, Certificates, MetalLB config |
| 3 | apps | Workload applications |
| 3 | monitoring-controllers | kube-prometheus-stack, GPU exporter |
| 4 | monitoring-configs | Grafana dashboards, routing |

---

## Argo CD Projects

| Project | Purpose | Source Repos |
|---------|---------|--------------|
| `bootstrap` | App-of-apps layer | This repo only |
| `infrastructure` | Cluster controllers and config | This repo + upstream Helm chart repos |
| `apps` | Workload applications | This repo only |
| `monitoring` | Monitoring stack | This repo + prometheus-community |

---

## Infrastructure Controllers

All controllers live under `infrastructure/controllers/` and are installed via Helm. Each controller follows the same structure:

```
infrastructure/controllers/<name>/
  application.yaml    # Argo CD Application pointing at an upstream chart
  values.yaml         # Helm values
  resources/          # Extra Kubernetes manifests (Namespace, ExternalSecret, etc.)
    kustomization.yaml
```

| Controller | Chart Source | Notes |
|------------|-------------|-------|
| `argocd` | argoproj/argo-helm | Self-managed; includes Image Updater |
| `argocd-image-updater` | argoproj/argo-helm | 30s poll interval; CRD-based |
| `cert-manager` | jetstack | DNS-01 via DigitalOcean |
| `external-dns` | kubernetes-sigs | Cloudflare DNS sync for luzero.online |
| `external-dns-route53` | kubernetes-sigs | Route53 DNS sync |
| `gateway-api` | kubernetes-sigs | Gateway API CRDs |
| `istio-base` | istio-release | Istio CRDs and base |
| `istiod` | istio-release | Istio control plane |
| `longhorn` | charts.longhorn.io | Default storage class |
| `metallb` | metallb | Bare-metal LoadBalancer |
| `metrics-server` | kubernetes-sigs | `--kubelet-insecure-tls` for bare-metal |
| `argo-rollouts` | argoproj/argo-helm | Progressive delivery |
| `n8n` | community-charts | Workflow automation |

---

## Workload Applications

Workload applications live under `apps/`. Each application follows this structure:

```
apps/<name>/
  application.yaml      # Argo CD Application (multi-source: charts/ + values ref)
  image-updater.yaml    # ImageUpdater CRD — automated digest tracking
  namespace.yaml        # Namespace for the workload
  values.yaml           # Helm values; updated automatically by image updater
```

### Adding a New Application

1. Create `apps/<name>/` with the files above.
2. The `bootstrap/apps.yaml` Application watches `apps/` recursively — no additional wiring is needed.
3. Argo CD will pick up the new `Application` manifest on its next sync.

**Application template (multi-source):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <name>
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: apps
  sources:
    - repoURL: https://github.com/luzero-io/k8s-gitops.git
      path: charts
      targetRevision: main
      helm:
        releaseName: <name>
        valueFiles:
          - $values/apps/<name>/values.yaml
    - repoURL: https://github.com/luzero-io/k8s-gitops.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: <name>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
```

### Current Applications

| Application | Image | Namespace |
|-------------|-------|-----------|
| `small-go-webserver` | `ghcr.io/luzero-luvis/small-go-webserver` | `small-go-webserver` |

---

## Image Update Automation

Image updates are handled by **ArgoCD Image Updater v1.2.1** using the CRD-based approach (`ImageUpdater` kind). The updater runs every **30 seconds** and writes changes back directly to `apps/<name>/values.yaml` via a Git commit.

### How It Works

1. Image Updater polls the container registry for changes on the configured tag.
2. When a new digest is detected on a pinned tag, it commits the updated image reference to `values.yaml` in this repository.
3. Argo CD detects the commit and syncs the Application, triggering a rolling update.

### ImageUpdater CR Structure

Each application that requires automated image updates has an `ImageUpdater` CR in its directory:

```yaml
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: <app-name>
  namespace: argocd
spec:
  applicationRefs:
    - namePattern: <app-name>
      writeBackConfig:
        method: git
        gitConfig:
          writeBackTarget: helmvalues:/apps/<app-name>/values.yaml
      images:
        - alias: app
          imageName: ghcr.io/<org>/<repo>:<tag>
          commonUpdateSettings:
            allowTags: "regexp:^<tag>$"
            updateStrategy: digest
            pullSecret: pullsecret:argocd/ghcr-credentials
          manifestTargets:
            helm:
              spec: image.name
```

**Key fields:**

| Field | Description |
|-------|-------------|
| `updateStrategy: digest` | Tracks SHA changes on the same tag (not semver) |
| `writeBackTarget: helmvalues:/path` | Writes directly to `values.yaml`, not `.argocd-source-*.yaml` |
| `allowTags` | Regexp filter — restricts which tags the updater considers |
| `pullSecret` | Registry credentials secret reference |
| `manifestTargets.helm.spec` | Helm values key that holds the full `image:tag` string |

### Required Secrets

The following secrets must exist in the `argocd` namespace before Image Updater will function:

| Secret | Purpose |
|--------|---------|
| `ghcr-credentials` | Pull secret for `ghcr.io` |
| `argocd-image-updater-secret` | Git credentials for write-back commits |

The Image Updater git commit identity is configured in the `argocd-image-updater-config` ConfigMap:

```yaml
git.user: luvis-luzero
git.email: luvis@luzero.io
```

---

## Networking and Ingress

All ingress flows through a shared Istio Gateway and Gateway API `HTTPRoute` resources.

**Gateway:** `infrastructure/configs/istio/gateway/gateway.yaml`  
**Listeners:**

| Listener name | Port | Protocol | Domains |
|---------------|------|----------|---------|
| `luzerofy-http` | 80 | HTTP | `*.luzero.online` |
| `luzerofy-https` | 443 | HTTPS | `*.luzero.online` |
| `slicearrow-http` | 80 | HTTP | `*.slicearrow.com` |
| `slicearrow-https` | 443 | HTTPS | `*.slicearrow.com` |

> **Important:** nginx terminates TLS externally and always forwards to MetalLB on port 80. HTTPRoutes for slicearrow.com services must attach to the `slicearrow-http` listener (port 80), not `slicearrow-https`.

**TLS certificates** are issued by cert-manager using Let's Encrypt DNS-01 (DigitalOcean) and stored in the `certificates` namespace. A `ReferenceGrant` allows `istio-system` to reference these secrets cross-namespace.

**DNS** is managed by `external-dns`, which watches Gateway routes and publishes records automatically.

### Active Hostnames

| Hostname | Service |
|----------|---------|
| `argocd.luzero.online` | Argo CD UI |
| `grafana.luzero.online` | Grafana |
| `kubeflow.luzero.online` | Kubeflow dashboard |
| `argo-rollouts.luzero.online` | Argo Rollouts dashboard |
| `n8n-csr-interns.slicearrow.com` | n8n workflow automation |

---

## Storage

- **Longhorn** is the default `StorageClass` for persistent volumes.

---

## Monitoring

Monitoring is managed from `monitoring/controllers/`:

| Component | Purpose |
|-----------|---------|
| `kube-prometheus-stack` | Prometheus, Alertmanager, and Grafana |
| `nvidia-gpu-exporter` | GPU metrics for nodes labeled `gpu=true` |

Grafana dashboards are loaded via labeled `ConfigMap` resources in `monitoring/configs/dashboards/`. The NVIDIA GPU dashboard is included at `monitoring/configs/dashboards/nvidia-gpu.yaml`.

Grafana is accessible at `grafana.luzero.online`.

---

## External nginx Proxy

Traffic from the internet hits `luzeroserver2` (`115.246.211.179`) which acts as a TLS-terminating reverse proxy in front of the cluster MetalLB VIP (`192.168.29.100`).

### Nginx Site Configs

| File | Domains |
|------|---------|
| `/etc/nginx/sites-available/k8s-luzerofy` | `*.luzero.online` |
| `/etc/nginx/sites-available/k8s-slicearrow` | `*.slicearrow.com` |

Both configs proxy all traffic to `192.168.29.100:80` with proper `Host`, `X-Forwarded-For`, `X-Forwarded-Proto`, and WebSocket upgrade headers. Symlinks in `sites-enabled/` activate them.

### TLS Certificate Sync

Wildcard certificates are issued inside the cluster by cert-manager and synced to the master server every 12 hours:

```
0 */12 * * * /usr/local/bin/sync-wildcard-cert.sh >> /var/log/cert-sync.log 2>&1
```

| Kubernetes Secret | Nginx cert path |
|-------------------|-----------------|
| `certificates/wildcard-tls` | `/etc/nginx/certs/luzero.online.crt` / `.key` |
| `certificates/wildcard-slicearrow-tls` | `/etc/nginx/certs/slicearrow.com.crt` / `.key` |

To force an immediate sync:

```bash
sudo bash /usr/local/bin/sync-wildcard-cert.sh
```

### SSH Access

```bash
ssh -i ~/.ssh/k8s_upgrade luzeroserver2@115.246.211.179 -p 61002
```

---

## Upgrade Automation

Renovate is configured in `renovate.json` and runs via `.github/workflows/renovate.yaml`. It opens pull requests to bump Helm chart versions and container image tags across the repository.

---

## Day-to-day Workflow

For most changes:

1. Edit the relevant manifest or `values.yaml`.
2. Commit and push to `main`.
3. Argo CD reconciles automatically (default poll interval: 3 minutes; webhook can reduce this to near-instant).

**Conventions:**

- New controllers go under `infrastructure/controllers/<name>/` and must be added to `infrastructure/controllers/kustomization.yaml`.
- Controller-owned support manifests (Namespace, ExternalSecret, etc.) go under `<controller>/resources/` and are listed in that directory's `kustomization.yaml`.
- New plain manifests go under the matching `configs/` tree, grouped by responsibility (`routing`, `security`, `services`, `gateway`, `dashboards`).
- New workload applications go under `apps/<name>/` — no additional kustomization wiring required.
- All Applications use `syncPolicy.automated` with `prune: true` and `selfHeal: true`.

---

## Runtime Prerequisites

The following must exist before applying the bootstrap manifests:

| Requirement | Detail |
|-------------|--------|
| Kubernetes cluster | Working CNI; storage-capable nodes |
| Argo CD | Installed manually before applying `root-application.yaml` |
| DNS for `luzero.online` | Required for cert-manager DNS-01 and external-dns |
| `digitalocean-api-token` | Secret for cert-manager and external-dns |
| `ClusterSecretStore: vault-backend` | Required by all `ExternalSecret` resources |
| `ghcr-credentials` (argocd ns) | Pull secret for `ghcr.io` |
| `argocd-image-updater-secret` (argocd ns) | Git token for image updater write-back |
| `grafana-admin` | Grafana admin credentials |
| MetalLB IP `192.168.29.100/32` | Layer-2 reachable from the proxy server |
| GPU nodes labeled `gpu=true` | Required only if NVIDIA monitoring is expected |

> **Note:** External Secrets Operator is referenced by `ExternalSecret` resources in this repository but is not installed by it. Ensure ESO is present before syncing manifests that depend on it.

---

## Argo CD Access

```text
https://argocd.luzero.online
```

CLI login:

```bash
argocd login argocd.luzero.online --grpc-web
```
>>>>>>> 9343e38 (feat : argo gitops repo)
