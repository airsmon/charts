#!/usr/bin/env bash

set -euo pipefail

helm_binary="${1:-helm}"
chart_dir="${2:-powerdns-admin}"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "${fixture_dir}"' EXIT

cp -R "${chart_dir}" "${fixture_dir}/powerdns-admin"
mkdir -p \
  "${fixture_dir}/powerdns-admin/.direnv" \
  "${fixture_dir}/powerdns-admin/.local" \
  "${fixture_dir}/powerdns-admin/secrets"
touch \
  "${fixture_dir}/powerdns-admin/.env" \
  "${fixture_dir}/powerdns-admin/.env.production" \
  "${fixture_dir}/powerdns-admin/.envrc" \
  "${fixture_dir}/powerdns-admin/.direnv/cache" \
  "${fixture_dir}/powerdns-admin/.local/credentials" \
  "${fixture_dir}/powerdns-admin/database-password.token" \
  "${fixture_dir}/powerdns-admin/debug.log" \
  "${fixture_dir}/powerdns-admin/private.key" \
  "${fixture_dir}/powerdns-admin/private.kubeconfig" \
  "${fixture_dir}/powerdns-admin/runtime-secret.yaml" \
  "${fixture_dir}/powerdns-admin/secrets/credentials.yaml" \
  "${fixture_dir}/powerdns-admin/values-local.yaml" \
  "${fixture_dir}/powerdns-admin/values-production.secret.yaml"

"${helm_binary}" package "${fixture_dir}/powerdns-admin" \
  --destination "${fixture_dir}" >/dev/null

archive_path=""
for candidate in "${fixture_dir}"/powerdns-admin-*.tgz; do
  archive_path="${candidate}"
  break
done

if [[ -z "${archive_path}" ]]; then
  echo "PowerDNS-Admin package archive was not created" >&2
  exit 1
fi

archive_list_path="${fixture_dir}/archive.list"
tar -tzf "${archive_path}" >"${archive_list_path}"

sensitive_entry="$(
  grep -E \
    '(^|/)(\.direnv/|\.env([^/]*)?|\.envrc$|\.local/|secrets/|runtime-secret\.yaml$|values-local\.yaml$|values-[^/]*\.(local|secret)\.yaml$|[^/]*\.(token|key|pem|p12|pfx|jks|kubeconfig|log)$)' \
    "${archive_list_path}" | head -n 1 || true
)"
if [[ -n "${sensitive_entry}" ]]; then
  echo "PowerDNS-Admin package contains a local or sensitive fixture: ${sensitive_entry}" >&2
  exit 1
fi

for required in \
  powerdns-admin/Chart.yaml \
  powerdns-admin/values.yaml \
  powerdns-admin/values.schema.json \
  powerdns-admin/templates/deployment.yaml; do
  if ! grep -qx "${required}" "${archive_list_path}"; then
    echo "PowerDNS-Admin package is missing ${required}" >&2
    exit 1
  fi
done

rendered_path="${fixture_dir}/rendered.yaml"
"${helm_binary}" template package-safety "${archive_path}" >"${rendered_path}"
if grep -q '^kind: Secret$' "${rendered_path}"; then
  echo "PowerDNS-Admin rendered an unexpected Secret" >&2
  exit 1
fi
