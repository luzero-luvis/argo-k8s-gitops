# Kubernetes GitOps

This repository uses Argo CD's app-of-apps pattern. The root application installs
the cluster layer, which then reconciles four bounded groups in order:

```text
bootstrap/root-application.yaml
└── cluster/
    ├── platform/    wave 10
    ├── services/    wave 20
    ├── monitoring/  wave 30
    └── workloads/   wave 40
```

## Repository layout

- `bootstrap/` contains the single entry-point Application.
- `cluster/projects/` contains one AppProject per ownership boundary.
- `cluster/applications/` contains the four wave-controlled Applications.
- `platform/`, `services/`, `monitoring/`, and `workloads/` contain components.
- `charts/microservice/` is the reusable workload chart.
- `policies/`, `backup/`, `scripts/`, and `docs/` contain operational controls.

Each component follows this convention:

```text
component/
├── application.yaml
├── values.yaml
└── resources/
    └── kustomization.yaml
```

Some components contain additional resources below `resources/`. Empty
`values.yaml` files are intentional for components that do not pass Helm values.

## Bootstrap

Apply the root application:

```sh
kubectl apply -f bootstrap/root-application.yaml
```

Run `./scripts/validate.sh` before opening a pull request.
