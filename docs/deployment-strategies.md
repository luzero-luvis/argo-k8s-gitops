# Deployment and release strategies

There is no universal, exhaustive list: these are common patterns, and teams often combine them.

- **All at once / Recreate:** Stop the old version and start the new one in one change, usually causing a brief outage. [Kubernetes](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- **Rolling update:** Replace old instances with new ones gradually while the service stays available. [Kubernetes](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- **Blue/green (red/black):** Run two complete versions side by side, then switch users to the new one. [AWS](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/deployment-strategies.html)
- **Canary:** Give a small group the new version first, check it, then give it to everyone. [AWS](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/deployment-strategies.html)
- **Linear / Ramped:** Move traffic to the new version in equal steps, such as 20% every ten minutes. [AWS](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/deployment-strategies.html)
- **Ring / Wave:** Release to groups in order, such as staff, early adopters, then all users. [Microsoft](https://learn.microsoft.com/en-us/windows/deployment/update/create-deployment-plan)
- **Immutable replacement:** Build fresh servers or containers for the new version instead of changing the existing ones. [AWS](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_tracking_change_management_immutable_infrastructure.html)
- **Shadow / Traffic mirroring:** Copy real requests to the new version for testing while users still receive the old version's responses. [Google Cloud](https://docs.cloud.google.com/service-mesh/docs/service-routing/advanced-traffic-management)
- **A/B testing:** Send different user groups to different versions and compare their results. [Microsoft](https://learn.microsoft.com/en-us/azure/azure-app-configuration/concept-feature-management)
- **Dark launch / Feature flags:** Deploy the new code but keep its new behavior hidden until you enable it for selected users. [Microsoft](https://learn.microsoft.com/en-us/azure/azure-app-configuration/concept-feature-management)

In this repository, the Helm chart supports Kubernetes Deployment `RollingUpdate` and `Recreate`, plus Argo Rollouts `blueGreen` and `canary`; the other patterns need additional traffic routing, infrastructure, or application features.

For a complete executable blue/green exercise using Helm, the official Argo
Rollouts color images, preview analysis, HTTPRoute traffic, and continuous
availability checks, see the
[Argo Rollouts blue/green Helm lab](argo-rollouts-bluegreen-helm-lab.md).
