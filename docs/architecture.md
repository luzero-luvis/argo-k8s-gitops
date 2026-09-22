# Architecture

Argo CD reconciles `cluster/`, which creates four projects and four child
Applications. Sync waves enforce the order platform, services, monitoring, then
workloads. Each child Application owns one repository boundary.
