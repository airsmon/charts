.PHONY: \
	dashboard \
		lint lint-fortigate-exporter lint-oxidized lint-powerdns-admin \
		negative negative-fortigate-exporter negative-oxidized negative-powerdns-admin \
		package package-fortigate-exporter package-oxidized package-powerdns-admin \
		package-safety-oxidized package-safety-powerdns-admin \
		template template-fortigate-exporter template-oxidized template-powerdns-admin \
		validate validate-fortigate-exporter validate-oxidized validate-powerdns-admin

HELM ?= helm
NODE ?= node
FORTIGATE_CHART_DIR ?= fortigate-exporter
OXIDIZED_CHART_DIR ?= oxidized
POWERDNS_ADMIN_CHART_DIR ?= powerdns-admin
DIST_DIR ?= dist

FORTIGATE_TEST_TARGET_ARGS = \
	--set 'targets[0].name=fortigate-test' \
	--set 'targets[0].url=https://fortigate.example.internal' \
	--set 'targets[0].labels.site=test'

OXIDIZED_SOURCE_ARGS = \
	--set-string 'config.source.csv.routerDb=router.example.internal:ios'

OXIDIZED_TEST_SOURCE_ARGS = $(OXIDIZED_SOURCE_ARGS) \
	--set 'config.input.ssh.secure=false' \
	--set 'runtimeSecret.enabled=false'

OXIDIZED_EXTERNAL_ARGS = $(OXIDIZED_SOURCE_ARGS) \
	--set 'runtimeSecret.create=false' \
	--set 'runtimeSecret.existingSecret=oxidized-runtime' \
	--set 'sshSecret.enabled=true' \
	--set 'sshSecret.create=false' \
	--set 'sshSecret.existingSecret=oxidized-ssh-keys' \
	--set 'config.hooks.githubrepo.enabled=true' \
	--set 'config.hooks.githubrepo.remoteRepo=git@example.com:network/oxidized.git' \
	--set 'persistence.existingClaim=oxidized-data' \
	--set 'ingress.enabled=true' \
	--set 'ingress.className=nginx' \
	--set 'networkPolicy.enabled=true' \
	--set 'networkPolicy.ingress.enabled=true' \
	--set 'networkPolicy.egress.enabled=true' \
	--set 'pdb.create=true'

validate: validate-fortigate-exporter validate-oxidized validate-powerdns-admin

validate-fortigate-exporter: dashboard lint-fortigate-exporter template-fortigate-exporter negative-fortigate-exporter

validate-oxidized: lint-oxidized template-oxidized negative-oxidized package-safety-oxidized

validate-powerdns-admin: lint-powerdns-admin template-powerdns-admin negative-powerdns-admin package-safety-powerdns-admin

dashboard:
	$(NODE) $(FORTIGATE_CHART_DIR)/scripts/validate-dashboard.mjs

lint: lint-fortigate-exporter lint-oxidized lint-powerdns-admin

lint-fortigate-exporter:
	$(HELM) lint $(FORTIGATE_CHART_DIR) --strict
	$(HELM) lint $(FORTIGATE_CHART_DIR) --strict $(FORTIGATE_TEST_TARGET_ARGS)

lint-oxidized:
	$(HELM) lint $(OXIDIZED_CHART_DIR) --strict $(OXIDIZED_TEST_SOURCE_ARGS)
	$(HELM) lint $(OXIDIZED_CHART_DIR) --strict $(OXIDIZED_EXTERNAL_ARGS)

lint-powerdns-admin:
	$(HELM) lint $(POWERDNS_ADMIN_CHART_DIR) --strict
	$(HELM) lint $(POWERDNS_ADMIN_CHART_DIR) --strict \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/bootstrap-values.yaml
	$(HELM) lint $(POWERDNS_ADMIN_CHART_DIR) --strict \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml
	$(HELM) lint $(POWERDNS_ADMIN_CHART_DIR) --strict \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/production-values.yaml
	$(HELM) lint $(POWERDNS_ADMIN_CHART_DIR) --strict \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/external-database-values.yaml

template: template-fortigate-exporter template-oxidized template-powerdns-admin

template-fortigate-exporter:
	$(HELM) template fortigate-exporter $(FORTIGATE_CHART_DIR) \
		--namespace monitoring >/dev/null
	$(HELM) template fortigate-exporter $(FORTIGATE_CHART_DIR) \
		--namespace monitoring $(FORTIGATE_TEST_TARGET_ARGS) >/dev/null

template-oxidized:
	$(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		--namespace oxidized $(OXIDIZED_TEST_SOURCE_ARGS) >/dev/null
	$(HELM) template production $(OXIDIZED_CHART_DIR) \
		--namespace network-automation $(OXIDIZED_EXTERNAL_ARGS) >/dev/null
	$(HELM) template alpha $(OXIDIZED_CHART_DIR) \
		--namespace team-a --set tests.enabled=false \
		$(OXIDIZED_TEST_SOURCE_ARGS) | \
		grep -q 'name: "alpha-oxidized"'
	$(HELM) template alpha $(OXIDIZED_CHART_DIR) \
		--namespace team-a --set tests.enabled=false \
		$(OXIDIZED_TEST_SOURCE_ARGS) | \
		grep -q 'namespace: "team-a"'
	$(HELM) template deny-ingress $(OXIDIZED_CHART_DIR) \
		--set tests.enabled=false \
		--set networkPolicy.enabled=true \
		--set networkPolicy.ingress.enabled=true \
		--set networkPolicy.ingress.fromAllNamespaces=false \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--show-only templates/networkpolicy.yaml | grep -q 'ingress: \[\]'
	$(HELM) template restricted-ingress $(OXIDIZED_CHART_DIR) \
		--set networkPolicy.enabled=true \
		--set networkPolicy.ingress.enabled=true \
		--set networkPolicy.ingress.fromAllNamespaces=false \
		--set 'networkPolicy.ingress.from[0].podSelector.matchLabels.role=proxy' \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--show-only templates/networkpolicy.yaml | grep -q 'role: proxy'
	$(HELM) template vhost $(OXIDIZED_CHART_DIR) \
		--set 'web.vhosts[0]=oxidized.example.com' \
		$(OXIDIZED_TEST_SOURCE_ARGS) | \
		grep -q 'value: "oxidized.example.com"'
	$(HELM) template http-empty-headers $(OXIDIZED_CHART_DIR) \
		--set 'config.source.default=http' \
		--set 'config.source.csv.enabled=false' \
		--set 'config.source.http.enabled=true' \
		--set-string 'config.source.http.url=https://inventory.example/api/devices' \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--show-only templates/configmap.yaml | \
		grep -q 'headers: {}'
	$(HELM) template http-node-fields $(OXIDIZED_CHART_DIR) \
		--set 'config.source.default=http' \
		--set 'config.source.csv.enabled=false' \
		--set 'config.source.http.enabled=true' \
		--set-string 'config.source.http.url=https://inventory.example/api/devices' \
		--set-string 'config.source.http.map.username=credentials.username' \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--show-only templates/configmap.yaml | \
		grep -q '"username": "credentials.username"'
	$(HELM) template pdb-zero $(OXIDIZED_CHART_DIR) \
		--set 'pdb.create=true' \
		--set-string 'pdb.minAvailable=' \
		--set 'pdb.maxUnavailable=0' \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--show-only templates/pdb.yaml | \
		grep -q 'maxUnavailable: 0'
	$(HELM) template long-name $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'fullnameOverride=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
		--set 'runtimeSecret.enabled=true' \
		--set 'runtimeSecret.create=true' \
		--set 'sshSecret.enabled=true' \
		--set 'sshSecret.create=true' \
		--set-string 'sshSecret.data.id_rsa=private' \
		--show-only templates/secret-runtime.yaml \
		--show-only templates/secret-ssh.yaml | \
		grep '^  name:' | sort -u | wc -l | grep -Eq '^ *2$$'
	$(HELM) template quoted-secret-key $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'runtimeSecret.enabled=true' \
		--set 'runtimeSecret.create=true' \
		--set-string 'runtimeSecret.secretKeys.deviceUsernameKey=null' \
		--show-only templates/secret-runtime.yaml | \
		grep -q '^  "null":'
	$(HELM) template comma-delimiter $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set-string 'config.source.csv.delimiter=\,' \
		--show-only templates/configmap.yaml | \
		grep -q 'delimiter: ","'
	$(HELM) template external-config-secret $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_SOURCE_ARGS) \
		--set 'config.input.ssh.secure=false' \
		--set 'runtimeSecret.existingSecret=oxidized-runtime' \
		--set-string 'runtimeSecret.secretKeys.extra.OXIDIZED_SLACK_TOKEN=slack-token' \
		--set 'config.hooks.slackdiff.enabled=true' \
		--set-string 'config.hooks.slackdiff.token=__OXIDIZED_SLACK_TOKEN__' \
		--set-string 'config.hooks.slackdiff.channel=network-backups' \
		--show-only templates/deployment.yaml | \
		grep -q 'key: "slack-token"'
	$(HELM) template external-config-secret $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_SOURCE_ARGS) \
		--set 'config.input.ssh.secure=false' \
		--set 'runtimeSecret.existingSecret=oxidized-runtime' \
		--set-string 'runtimeSecret.secretKeys.extra.OXIDIZED_SLACK_TOKEN=slack-token' \
		--set 'config.hooks.slackdiff.enabled=true' \
		--set-string 'config.hooks.slackdiff.token=__OXIDIZED_SLACK_TOKEN__' \
		--set-string 'config.hooks.slackdiff.channel=network-backups' \
		--show-only templates/configmap.yaml | \
		grep -q 'token: "__OXIDIZED_SLACK_TOKEN__"'
	$(HELM) template no-web $(OXIDIZED_CHART_DIR) \
		--set web.enabled=false \
		--set ingress.enabled=true \
		--set networkPolicy.enabled=true \
		--set networkPolicy.ingress.enabled=true \
		--set persistence.enabled=false \
		$(OXIDIZED_TEST_SOURCE_ARGS) >/dev/null
	! $(HELM) template no-web $(OXIDIZED_CHART_DIR) \
		--set web.enabled=false \
		--set ingress.enabled=true \
		--set networkPolicy.enabled=true \
		--set networkPolicy.ingress.enabled=true \
		--set persistence.enabled=false \
		$(OXIDIZED_TEST_SOURCE_ARGS) | \
		grep -Eq '^kind: (Ingress|NetworkPolicy|Pod|Service)$$'

template-powerdns-admin:
	$(HELM) template default $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin >/dev/null
	$(HELM) template default $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin | \
		grep -q 'docker.io/powerdnsadmin/pda-legacy:v0.6.1@sha256:5741b1f877210878f02923dd45346c7016acefc7eac9b14e90229f94e4c726c4'
	$(HELM) template default $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin | \
		grep -q 'docker.io/library/postgres:17.10-alpine3.22@sha256:b02d9b5bcf608c2719da32cdabee274a33841202487fd5dc9b065b63f886753f'
	$(HELM) template default $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin --show-only templates/deployment.yaml | \
		grep -q -- '- gunicorn'
	$(HELM) template default $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin --show-only templates/deployment.yaml | \
		grep -q -- '- --bind=0.0.0.0:8080'
	$(HELM) template default $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin --show-only templates/deployment.yaml | \
		grep -q 'name: wait-for-postgresql'
	@rendered="$$(mktemp)"; trap 'rm -f "$$rendered"' 0; \
		$(HELM) template default $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin >"$$rendered"; \
		! grep -Eq '^kind: (Job|Secret|PodDisruptionBudget)$$' "$$rendered"
	$(HELM) template bootstrap $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/bootstrap-values.yaml \
		--show-only templates/deployment.yaml | \
		grep -A1 'name: SIGNUP_ENABLED' | grep -q 'value: "true"'
	@rendered="$$(mktemp)"; trap 'rm -f "$$rendered"' 0; \
		$(HELM) template bootstrap $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/bootstrap-values.yaml >"$$rendered"; \
		! grep -Eq '^kind: (Certificate|Gateway|VirtualService|Secret|PodDisruptionBudget)$$' "$$rendered"
	$(HELM) template uat $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml | \
		grep -q '^kind: Job$$'
	$(HELM) template uat $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml \
		--show-only templates/deployment.yaml | \
		grep -q -- '- /opt/venv/bin/gunicorn'
	$(HELM) template uat $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml | \
		grep -q 'argocd.argoproj.io/hook: Sync'
	$(HELM) template production $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/production-values.yaml | \
		grep -q '^kind: Certificate$$'
	$(HELM) template production $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/production-values.yaml \
		--show-only templates/route.yaml | \
		grep -q 'namespace: "istio-system"'
	$(HELM) template production $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/production-values.yaml \
		--show-only templates/route.yaml | \
		grep -q -- '- "istio-system/production-powerdns-admin"'
	$(HELM) template existing-gateway $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/production-values.yaml \
		--set route.gateway.create=false \
		--set route.gateway.name=shared-powerdns \
		--set route.tls.certificate.create=false \
		--show-only templates/route.yaml | grep -c '^kind:' | grep -q '^1$$'
	$(HELM) template existing-gateway $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/production-values.yaml \
		--set route.gateway.create=false \
		--set route.gateway.name=shared-powerdns \
		--set route.tls.certificate.create=false \
		--show-only templates/route.yaml | \
		grep -q -- '- "istio-system/shared-powerdns"'
	$(HELM) template production $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/production-values.yaml | \
		grep -q 'storage: 20Gi'
	@rendered="$$(mktemp)"; trap 'rm -f "$$rendered"' 0; \
		$(HELM) template external $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/external-database-values.yaml >"$$rendered"; \
		! grep -Eq '^kind: StatefulSet$$|component: "database"|name: wait-for-postgresql' "$$rendered"
	$(HELM) template deny-web $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--set networkPolicy.enabled=true \
		--show-only templates/networkpolicy.yaml | grep -q 'ingress: \[\]'
	$(HELM) template alpha $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace team-a \
		--set fullnameOverride=alpha-powerdns-admin | \
		grep -q 'namespace: "team-a"'
	@rendered="$$(mktemp)"; trap 'rm -f "$$rendered"' 0; \
		$(HELM) template uat $(POWERDNS_ADMIN_CHART_DIR) \
		--namespace powerdns-admin \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml >"$$rendered"; \
		! grep -q '^kind: Secret$$' "$$rendered"

negative: negative-fortigate-exporter negative-oxidized negative-powerdns-admin

negative-fortigate-exporter:
	! $(HELM) template fortigate-exporter $(FORTIGATE_CHART_DIR) \
		--set 'serviceMonitor.scrapeTimeot=10s' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(FORTIGATE_CHART_DIR) \
		--set 'targets[0].name=duplicate' \
		--set 'targets[0].url=https://first.example.internal' \
		--set 'targets[1].name=duplicate' \
		--set 'targets[1].url=https://second.example.internal' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(FORTIGATE_CHART_DIR) \
		--set 'podLabels.app\.kubernetes\.io/name=unsafe' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(FORTIGATE_CHART_DIR) \
		--set 'prometheusRule.wanBandwidth.devices.unknown.aliasRegex=^WAN$$' \
		--set 'prometheusRule.wanBandwidth.devices.unknown.downstreamKbps=100000' \
		--set 'prometheusRule.wanBandwidth.devices.unknown.upstreamKbps=50000' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(FORTIGATE_CHART_DIR) \
		--set 'prometheusRule.certificateExpiry.warningDays=7' \
		--set 'prometheusRule.certificateExpiry.criticalDays=7' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(FORTIGATE_CHART_DIR) \
		--set 'prometheusRule.slowProbe.thresholdSeconds=30' >/dev/null 2>&1

negative-oxidized:
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'totallyUnknownKey=invalid' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'service.typo=invalid' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'service.port=70000' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'replicaCount=2' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'runtimeSecret.enabled=true' \
		--set 'runtimeSecret.create=false' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		--set-string 'config.source.csv.routerDb=router.example.internal:ios' \
		--set 'config.input.ssh.secure=true' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'config.source.csv.enabled=false' \
		--set 'config.source.http.enabled=true' \
		--set 'config.source.default=http' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'commonLabels.app\.kubernetes\.io/name=unsafe' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'config.input.ssh.enabled=false' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'fullnameOverride=foo.bar' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'commonLabels.bad key=invalid' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'networkPolicy.egress.cidr=999.999.999.999/24' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'config.output.default=http' \
		--set 'config.output.git.enabled=false' \
		--set 'config.output.http.enabled=true' \
		--set-string 'config.output.http.url=file:///tmp/out' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'pdb.minAvailable=2' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_TEST_SOURCE_ARGS) \
		--set 'config.input.telnet.secure=true' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		--set-string 'config.source.csv.routerDb=   ' \
		--set 'config.input.ssh.secure=false' \
		--set 'runtimeSecret.enabled=false' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		--set-string 'config.source.csv.routerDb=router.example.internal:ios:ssh' \
		--set 'config.source.csv.map.input=2' \
		--set 'config.input.default=telnet' \
		--set 'config.input.telnet.enabled=true' \
		--set 'runtimeSecret.enabled=false' >/dev/null 2>&1
	$(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		--values $(OXIDIZED_CHART_DIR)/ci/empty-egress-values.yaml 2>&1 | \
		grep -Eq '(minItems|at least 1 items)'
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_SOURCE_ARGS) \
		--set 'config.input.ssh.secure=false' \
		--set 'runtimeSecret.existingSecret=oxidized-runtime' \
		--set-string 'runtimeSecret.secretKeys.extra.OXIDIZED_DEFAULT_USERNAME=other-key' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_SOURCE_ARGS) \
		--set 'config.input.ssh.secure=false' \
		--set 'runtimeSecret.existingSecret=oxidized-runtime' \
		--set-string 'runtimeSecret.data.extra.OXIDIZED_UNUSED=value' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_SOURCE_ARGS) \
		--set 'config.input.ssh.secure=false' \
		--set 'runtimeSecret.create=true' \
		--set-string 'runtimeSecret.secretKeys.extra.OXIDIZED_SLACK_TOKEN=slack-token' >/dev/null 2>&1
	! $(HELM) template oxidized $(OXIDIZED_CHART_DIR) \
		$(OXIDIZED_SOURCE_ARGS) \
		--set 'config.input.ssh.secure=false' \
		--set 'runtimeSecret.existingSecret=oxidized-runtime' \
		--set 'config.hooks.slackdiff.enabled=true' \
		--set-string 'config.hooks.slackdiff.token=__OXIDIZED_SLACK_TOKEN__' \
		--set-string 'config.hooks.slackdiff.channel=network-backups' >/dev/null 2>&1

negative-powerdns-admin:
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--set totallyUnknownKey=invalid >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--set replicaCount=2 >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--set-string runtimeSecret.existingSecret= >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--set-string image.digest= >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--set route.enabled=true >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--set route.enabled=true \
		--set route.host=powerdns-admin.example.internal \
		--set config.siteUrl=https://powerdns-admin.example.internal \
		--set config.csrfCookieSecure=true \
		--set config.sessionCookieSecure=true \
		--set config.hstsEnabled=true \
		--set config.serverExternalSsl=true >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml \
		--set config.siteUrl=https://wrong.example.internal >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--set route.enabled=true \
		--set route.host=powerdns-admin.example.internal \
		--set route.tls.enabled=false \
		--set config.siteUrl=http://powerdns-admin.example.internal \
		--set config.signupEnabled=false \
		--set config.csrfCookieSecure=false \
		--set config.sessionCookieSecure=false \
		--set config.hstsEnabled=false \
		--set config.serverExternalSsl=false \
		--set route.http.redirectToHttps=true >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml \
		--set route.tls.certificate.namespace=powerdns-admin >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml \
		--set route.gateway.create=false \
		--set route.gateway.name=shared-powerdns >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--values $(POWERDNS_ADMIN_CHART_DIR)/ci/uat-values.yaml \
		--set route.gateway.create=false \
		--set-string route.gateway.name= \
		--set route.tls.certificate.create=false >/dev/null 2>&1
	! $(HELM) template powerdns-admin $(POWERDNS_ADMIN_CHART_DIR) \
		--set serviceAccount.automountServiceAccountToken=true >/dev/null 2>&1

package: package-fortigate-exporter package-oxidized package-powerdns-admin

package-fortigate-exporter:
	mkdir -p $(DIST_DIR)
	$(HELM) package $(FORTIGATE_CHART_DIR) --destination $(DIST_DIR)

package-oxidized:
	mkdir -p $(DIST_DIR)
	$(HELM) package $(OXIDIZED_CHART_DIR) --destination $(DIST_DIR)

package-powerdns-admin:
	mkdir -p $(DIST_DIR)
	$(HELM) package $(POWERDNS_ADMIN_CHART_DIR) --destination $(DIST_DIR)

package-safety-oxidized:
	bash $(OXIDIZED_CHART_DIR)/scripts/validate-package.sh \
		"$(HELM)" "$(OXIDIZED_CHART_DIR)"

package-safety-powerdns-admin:
	bash $(POWERDNS_ADMIN_CHART_DIR)/scripts/validate-package.sh \
		"$(HELM)" "$(POWERDNS_ADMIN_CHART_DIR)"
