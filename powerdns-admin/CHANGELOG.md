# Changelog

All notable changes to this Chart are documented in this file.

## 0.1.0

- Add PowerDNS-Admin `0.6.1` with immutable `tag@digest` image references.
- Add an optional, application-dedicated PostgreSQL 17 StatefulSet and retained
  PVC; external database deployments render no PostgreSQL resources.
- Require pre-created runtime and database Secrets and never render Secret
  payloads.
- Support the upstream single-replica entrypoint migration workflow and an
  Argo CD Sync hook migration workflow.
- Add opt-in NetworkPolicy and Istio/cert-manager routing resources.
- Keep first-Administrator registration local to a route-disabled bootstrap
  phase and reject public routing while sign-up is enabled.
- Align a chart-created certificate Secret with the selected Istio gateway
  workload namespace and support referencing an existing Gateway.
- Add hardened single-node defaults, environment validation profiles and
  package safety checks.
