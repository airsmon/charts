#!/usr/bin/env bash

set -euo pipefail

helm_binary="${1:-helm}"
chart_dir="${2:-oxidized}"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "${fixture_dir}"' EXIT

cp -R "${chart_dir}" "${fixture_dir}/oxidized"
mkdir -p \
  "${fixture_dir}/oxidized/.direnv" \
  "${fixture_dir}/oxidized/.local" \
  "${fixture_dir}/oxidized/secrets"
touch \
  "${fixture_dir}/oxidized/.env" \
  "${fixture_dir}/oxidized/.env.production" \
  "${fixture_dir}/oxidized/.envrc" \
  "${fixture_dir}/oxidized/.direnv/cache" \
  "${fixture_dir}/oxidized/.local/credentials" \
  "${fixture_dir}/oxidized/debug.log" \
  "${fixture_dir}/oxidized/fortigate-key.yaml" \
  "${fixture_dir}/oxidized/private.jks" \
  "${fixture_dir}/oxidized/private.key" \
  "${fixture_dir}/oxidized/private.kubeconfig" \
  "${fixture_dir}/oxidized/private.p12" \
  "${fixture_dir}/oxidized/private.pem" \
  "${fixture_dir}/oxidized/private.pfx" \
  "${fixture_dir}/oxidized/private.token" \
  "${fixture_dir}/oxidized/secrets/credentials.yaml" \
  "${fixture_dir}/oxidized/site-fortigate-key.yaml" \
  "${fixture_dir}/oxidized/values-local.yaml" \
  "${fixture_dir}/oxidized/values-targets.yaml" \
  "${fixture_dir}/oxidized/values-test.local.yaml" \
  "${fixture_dir}/oxidized/values-test.secret.yaml"

"${helm_binary}" package "${fixture_dir}/oxidized" \
  --destination "${fixture_dir}" >/dev/null

archive_path=""
for candidate in "${fixture_dir}"/oxidized-*.tgz; do
  archive_path="${candidate}"
  break
done

if [[ -z "${archive_path}" ]]; then
  echo "Oxidized package archive was not created" >&2
  exit 1
fi

if tar -tzf "${archive_path}" | grep -Eq \
  '(^|/)(\.direnv/|\.env([^/]*)?|\.envrc$|\.local/|secrets/|values-(targets|local)\.yaml$|values-[^/]*\.(local|secret)\.yaml$|([^/]*-)?fortigate-key\.yaml$|[^/]*\.(token|key|pem|p12|pfx|jks|kubeconfig|log)$)'; then
  echo "Oxidized package contains a local or sensitive fixture" >&2
  exit 1
fi
