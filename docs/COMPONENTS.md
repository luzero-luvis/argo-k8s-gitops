# Components

Components are grouped by operational ownership and reconciliation order.

## Platform (wave 10)

Networking, storage, delivery, security, compute, and CI runner controllers.

## Services (wave 20)

Shared services such as identity, caching, messaging, automation, and databases.

## Monitoring (wave 30)

Prometheus, Loki, Jaeger, OpenTelemetry collectors, blackbox probing, and GPU
metrics. Jaeger is retained at `monitoring/jaeger`.

## Workloads (wave 40)

Product-facing deployments. `workloads` is used instead of `apps` to avoid
confusing Kubernetes workloads with Argo CD `Application` objects.
