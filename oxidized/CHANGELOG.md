# Changelog

All notable changes to this Helm Chart are documented in this file.

## 0.1.0

- Add release-scoped names, standard Kubernetes labels, and
  `namespaceOverride` semantics compatible with normal Helm installs.
- Require a real node source and externally managed runtime credentials before
  installation instead of shipping unusable empty or environment-specific
  defaults.
- Keep strict SSH host verification enabled by default, with `known_hosts`,
  device keys, NetBox, remote Git, and legacy SSH algorithms explicitly
  opt-in.
- Support existing ConfigMaps, Secrets, and PVCs without rendering duplicate
  resources.
- Render credentials with Ruby/YAML so quotes, delimiters, ampersands, and
  multiline values remain valid configuration.
- Support generic external Secret placeholders for hook, source, output,
  group, and model credentials without exposing them in ConfigMaps.
- Reject fail-open empty egress rules, whitespace-only CSV sources, and strict
  SSH configurations that omit `known_hosts`.
- Add optional Ingress, NetworkPolicy, PodDisruptionBudget, retained
  persistence, probes, scheduling controls, and a Helm connection test.
- Keep workload and test selectors separate and preserve supporting-resource
  suffixes even at the Kubernetes name-length limit.
- Add strict values validation and repository-level CI coverage.
