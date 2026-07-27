# Changelog

All notable changes to this Helm Chart are documented in this file.

## 0.4.0

- Align the application, Dashboard file, Prometheus job, and rule group names
  with the upstream `fortigate_exporter` name.
- Keep the Helm Chart directory, Chart name, helper namespace, release,
  Kubernetes resource, and published image names as `fortigate-exporter`.
- Complete the values schema and reject unknown top-level configuration.
- Reject duplicate targets, unknown alert target references, inconsistent
  alert thresholds, and attempts to override reserved labels or annotations.
- Quote user-provided resource values and protect workload selectors when
  merging custom metadata.
- Keep Probe names unique and the Dashboard ConfigMap name valid when Helm
  release names approach the Kubernetes DNS-label length limit.

## 0.3.0

- Deploy fortigate_exporter v1.25.0 with an immutable image digest.
- Add Prometheus Operator Probe, ServiceMonitor, and PrometheusRule resources.
- Add a multi-device Grafana Dashboard and static Dashboard validation.
- Require an external Secret for FortiGate API tokens.
