# Alerting: Grafana-managed vs Alertmanager

This cluster migrated from **Prometheus rules + Alertmanager** to **Grafana-managed
alerting** on 2026-06-30. Alertmanager was removed (`alertmanager.enabled: false`
in the kube-prometheus-stack values); alert rules, contact points, notification
policies, and the email contact are now provisioned as code under
`grafana.alerting` in `monitoring/kube-prometheus-stack/values.yaml`.

> The Prometheus `defaultRules` are still installed and still evaluate — they
> remain **visible** in Grafana's alert list, but Grafana (not Alertmanager) is
> what sends notifications now.

Facts below are sourced from the official Grafana and Prometheus docs (links at
the bottom), not assumptions.

## Why Grafana-managed alerting (what's better)

| Area | Grafana-managed alerting | Prometheus + Alertmanager |
|---|---|---|
| **Data sources you can alert on** | A single rule can query **multiple data sources** — metrics, plus Loki logs, traces, SQL, etc. | One PromQL query against Prometheus metrics |
| **Expressions** | Expression-based transformations (reduce / math / resample / threshold) and advanced conditions | One PromQL expression per rule |
| **No-data / error handling** | First-class `noDataState` / `execErrState` per rule | Handled at the query level only |
| **Images in notifications** | Supported | Not built in |
| **Where it's configured** | One UI + one provisioning block (`grafana.alerting`) for rules, contact points, policies, silences | Split: rules in `PrometheusRule` CRDs, routing/receivers in a separate Alertmanager config |
| **Rule authoring** | Visual editor with preview, **or** GitOps YAML | YAML / PromQL only |
| **Resolved notifications** | **On by default** — opt out per contact point via *Disable resolved message* (`disableResolveMessage`) | **Off by default for email and Slack**; on for PagerDuty/webhook/most others (`send_resolved` per receiver) |
| **Single pane of glass** | Rules, alerts, dashboards, and silences all in Grafana | Alerting UI separate from dashboards |
| **Operational surface** | One fewer component to run, store (PVC), and upgrade | Extra StatefulSet + storage to operate |

### `send_resolved` defaults in classic Alertmanager (per receiver)

| Receiver | `send_resolved` default |
|---|---|
| `email_configs` | **false** |
| `slack_configs` | **false** |
| `pagerduty_configs`, `webhook_configs`, Discord, OpsGenie, Pushover, Telegram, VictorOps, WeChat, SNS, … | **true** |

This is why the old email setup would not have sent "resolved" mails unless you
added `send_resolved: true`, whereas the current Grafana setup sends them by default.

## Where Alertmanager is still the stronger choice

Being fair — Alertmanager is a different trade-off, not strictly worse:

| Area | Alertmanager advantage |
|---|---|
| **Independence** | Decoupled from Grafana — alert routing keeps working even if Grafana is down |
| **Scale & HA** | Mature gossip-based clustering; built for very high alert volumes |
| **Inhibition** | First-class `inhibit_rules` — a firing source alert suppresses matching target alerts during an outage |
| **Ecosystem** | The de-facto standard; `amtool`, runbooks, and many integrations assume it |
| **Footprint** | Single-purpose and lightweight; no dashboard stack required |

## Rule of thumb

- **Single cluster, Grafana already central, want logs/traces alerting and one
  place to manage everything** → Grafana-managed (this cluster's choice).
- **Large/multi-cluster, alerting must survive Grafana being down, very high
  alert volume, or heavy inhibition logic** → keep Prometheus + Alertmanager.

## Key trade-off: alerting now depends on Grafana

With Alertmanager removed, **alert evaluation and delivery live inside Grafana**.
If Grafana itself is down or broken, alerts won't be sent — there is no
independent component still watching. (Classic Alertmanager keeps firing even
if Grafana dies.) For a single, Grafana-centric cluster this is an acceptable
trade-off, but it should be covered.

### Mitigation: a dead-man's-switch (heartbeat)

The standard answer to "who watches the watcher" is a **heartbeat / dead-man's-switch**:

- Create an **always-firing** alert rule and route it to an **external** receiver
  (e.g. [healthchecks.io](https://healthchecks.io), Grafana OnCall, Better Uptime,
  or a webhook that pings an external monitor).
- That external service expects a ping on a schedule. **As long as Grafana is
  healthy, the ping keeps arriving and the service stays quiet.**
- If Grafana (or the whole cluster) goes down, the pings **stop**, and the
  external service alerts *you* — telling you the alerting system itself is down.

The kube-prometheus-stack `defaultRules` already ship a `Watchdog` alert (an
always-firing alert designed for exactly this); route it (or an equivalent
Grafana-managed always-on rule) to an external heartbeat endpoint to close the gap.

> Not yet configured in this repo — add an external heartbeat receiver when you
> want this setup to be fully production-solid.

## Current setup (this repo)

- **Contact point:** `email-default` → `platform@example.com` (Gmail SMTP; password in
  the `grafana-smtp` secret via `GF_SMTP_PASSWORD`).
- **Notification policy:** routes all alerts to `email-default`; resolved emails on.
- **Grafana-managed rules:** `InstanceDown`, `NodeDiskAlmostFull`,
  `KubeNodeNotReady`, `PodCrashLooping`, `PVFillingUp`, `NodeMemoryPressure`
  (each with a `for:` hold-down to avoid flapping).
- **Dashboard:** "Alerting Overview" (`monitoring/configs/dashboards/alerting-overview.yaml`).

## Sources

- Grafana — Alerting fundamentals: https://grafana.com/docs/grafana/latest/alerting/fundamentals/
- Grafana — Alert rules (Grafana-managed vs data source-managed): https://grafana.com/docs/grafana/latest/alerting/fundamentals/alert-rules/
- Grafana — Contact points (Disable resolved message): https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/
- Prometheus — Alertmanager configuration (`send_resolved`, `inhibit_rules`): https://prometheus.io/docs/alerting/latest/configuration/

See `docs/COMPONENTS.md` for the kube-prometheus-stack version and the
Alertmanager-removal note.
