.PHONY: dashboard lint negative package template validate

HELM ?= helm
NODE ?= node
CHART_DIR ?= fortigate-exporter
DIST_DIR ?= dist
TEST_TARGET_ARGS = \
	--set 'targets[0].name=fortigate-test' \
	--set 'targets[0].url=https://fortigate.example.internal' \
	--set 'targets[0].labels.site=test'

validate: dashboard lint template negative

dashboard:
	$(NODE) $(CHART_DIR)/scripts/validate-dashboard.mjs

lint:
	$(HELM) lint $(CHART_DIR) --strict
	$(HELM) lint $(CHART_DIR) --strict $(TEST_TARGET_ARGS)

template:
	$(HELM) template fortigate-exporter $(CHART_DIR) \
		--namespace monitoring >/dev/null
	$(HELM) template fortigate-exporter $(CHART_DIR) --namespace monitoring \
		$(TEST_TARGET_ARGS) >/dev/null

negative:
	! $(HELM) template fortigate-exporter $(CHART_DIR) \
		--set 'serviceMonitor.scrapeTimeot=10s' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(CHART_DIR) \
		--set 'targets[0].name=duplicate' \
		--set 'targets[0].url=https://first.example.internal' \
		--set 'targets[1].name=duplicate' \
		--set 'targets[1].url=https://second.example.internal' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(CHART_DIR) \
		--set 'podLabels.app\.kubernetes\.io/name=unsafe' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(CHART_DIR) \
		--set 'prometheusRule.wanBandwidth.devices.unknown.aliasRegex=^WAN$$' \
		--set 'prometheusRule.wanBandwidth.devices.unknown.downstreamKbps=100000' \
		--set 'prometheusRule.wanBandwidth.devices.unknown.upstreamKbps=50000' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(CHART_DIR) \
		--set 'prometheusRule.certificateExpiry.warningDays=7' \
		--set 'prometheusRule.certificateExpiry.criticalDays=7' >/dev/null 2>&1
	! $(HELM) template fortigate-exporter $(CHART_DIR) \
		--set 'prometheusRule.slowProbe.thresholdSeconds=30' >/dev/null 2>&1

package:
	mkdir -p $(DIST_DIR)
	$(HELM) package $(CHART_DIR) --destination $(DIST_DIR)
