import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Development/CI-only static validation. This script reads the committed
// dashboard JSON, performs no network or cluster access, and changes no files.
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");
const dashboardPath = path.join(
  projectRoot,
  "grafana",
  "fortigate_exporter-overview.json",
);
const source = fs.readFileSync(dashboardPath, "utf8");
const dashboard = JSON.parse(source);

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

assert(
  dashboard.apiVersion === "dashboard.grafana.app/v2",
  "dashboard must use the Grafana v2 resource schema",
);
assert(dashboard.kind === "Dashboard", "dashboard kind must be Dashboard");
assert(
  dashboard.metadata?.name === "fortigate-exporter-overview",
  "dashboard metadata.name must be stable",
);
assert(
  Object.keys(dashboard.metadata).length === 1,
  "deployment metadata must not be committed",
);
assert(dashboard.spec?.title, "dashboard title is required");
assert(
  Object.keys(dashboard.spec?.elements ?? {}).length > 0,
  "dashboard must contain panels",
);

const panelExpressions = [];
const panelTitles = [];
const prometheusDataSources = [];
const elementReferences = [];

function visit(value) {
  if (Array.isArray(value)) {
    value.forEach(visit);
    return;
  }
  if (!value || typeof value !== "object") {
    return;
  }

  if (value.kind === "Panel") {
    panelTitles.push(value.spec?.title ?? "");
  }
  if (value.kind === "DataQuery" && value.group === "prometheus") {
    prometheusDataSources.push(value.datasource?.name);
  }
  if (typeof value.expr === "string") {
    panelExpressions.push(value.expr);
  }
  if (value.kind === "ElementReference") {
    elementReferences.push(value.name);
  }

  Object.values(value).forEach(visit);
}

visit(dashboard);

const variables = dashboard.spec.variables ?? [];
const variableNames = variables.map((variable) => variable.spec?.name);
const expectedVariables = [
  "datasource",
  "job",
  "device",
  "vdom",
  "interface",
  "phase1",
  "phase2",
  "sdwan",
  "fortiswitch",
  "mac_address",
];

assert(
  JSON.stringify(variableNames) === JSON.stringify(expectedVariables),
  `unexpected dashboard variables: ${variableNames.join(", ")}`,
);
assert(
  variables[0]?.kind === "DatasourceVariable" &&
    variables[0]?.spec?.pluginId === "prometheus",
  "dashboard must start with a Prometheus datasource variable",
);
assert(
  prometheusDataSources.length > 0 &&
    prometheusDataSources.every((name) => name === "$datasource"),
  "all Prometheus queries must use the $datasource variable",
);
assert(
  panelExpressions.length > 0,
  "dashboard must contain Prometheus panel expressions",
);
assert(
  panelTitles.every((title) => title.trim()),
  "every dashboard panel must have a title",
);

const expectedElements = new Set(Object.keys(dashboard.spec.elements));
assert(
  elementReferences.length === expectedElements.size,
  "every dashboard element must have exactly one layout reference",
);
for (const reference of elementReferences) {
  assert(
    expectedElements.has(reference),
    `layout references missing element ${reference}`,
  );
}
assert(
  new Set(elementReferences).size === elementReferences.length,
  "dashboard layout contains duplicate element references",
);
assert(
  dashboard.spec.layout?.spec?.rows?.some(
    (row) => row.spec?.title === "Collection Health",
  ),
  "dashboard must contain the Collection Health row",
);

function hasBalancedPromqlSyntax(expression) {
  let braces = 0;
  let quoted = false;
  let escaped = false;

  for (const character of expression) {
    if (escaped) {
      escaped = false;
      continue;
    }
    if (quoted && character === "\\") {
      escaped = true;
      continue;
    }
    if (character === '"') {
      quoted = !quoted;
      continue;
    }
    if (!quoted && character === "{") {
      braces += 1;
    }
    if (!quoted && character === "}") {
      braces -= 1;
      if (braces < 0) {
        return false;
      }
    }
  }

  return !quoted && braces === 0;
}

const stableJobSelector = 'job=~"${job:regex}"';
const stableDeviceSelector =
  'fortigate_device=~"${device:regex}"';
const perVdomMetric =
  /\bfortigate_(?:interface|policy|vpn|ipsec|ha_member|virtual_wan|link|wifi|managed_switch|log)_/;

for (const expression of panelExpressions) {
  assert(
    hasBalancedPromqlSyntax(expression),
    `unbalanced PromQL expression: ${expression}`,
  );
  assert(
    !/\binstance\s*[!~]?=|\$firewall\b/.test(expression),
    `legacy instance/firewall selector found: ${expression}`,
  );
  assert(
    expression.includes(stableJobSelector) &&
      expression.includes(stableDeviceSelector),
    `stable job/device selectors missing: ${expression}`,
  );
  if (perVdomMetric.test(expression)) {
    assert(
      expression.includes('vdom=~"${vdom:regex}"'),
      `VDOM selector missing: ${expression}`,
    );
  }
}

const allExpressions = panelExpressions.join("\n");
assert(
  allExpressions.includes("probe_success{") &&
    allExpressions.includes("probe_duration_seconds{"),
  "dashboard must expose probe success and duration",
);
assert(
  !allExpressions.includes('mac="$mac_address"'),
  "WiFi All selection must use a regex matcher",
);
assert(
  allExpressions.includes('mac=~"${mac_address:regex}"'),
  "WiFi client panels must use the mac_address regex variable",
);
assert(
  allExpressions.includes(
    'interface=~"${sdwan:regex}"',
  ),
  "SD-WAN panels must use the sdwan variable",
);
assert(
  allExpressions.includes(
    'parent=~"${phase1:regex}",name=~"${phase2:regex}"',
  ),
  "IPsec panels must use chained phase1 and phase2 variables",
);
for (const counter of [
  "fortigate_ha_member_virus_events_total",
  "fortigate_ha_member_ips_events_total",
]) {
  assert(
    panelExpressions
      .filter((expression) => expression.includes(counter))
      .every((expression) => expression.includes("rate(")),
    `${counter} must be displayed as a rate`,
  );
}

const forbiddenPatterns = [
  [/\b10(?:\.\d{1,3}){3}\b/, "private 10/8 address"],
  [/\b192\.168(?:\.\d{1,3}){2}\b/, "private 192.168/16 address"],
  [/\b172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2}\b/, "private 172.16/12 address"],
  [/"resourceVersion"\s*:/, "Grafana resourceVersion"],
  [/"creationTimestamp"\s*:/, "Grafana creationTimestamp"],
  [/grafana\.app\/(?:createdBy|updatedBy|updatedTimestamp)/, "Grafana user metadata"],
  [/"__systemRef"\s*:\s*"hideSeriesFrom"/, "UI-only hidden-series state"],
];

for (const [pattern, description] of forbiddenPatterns) {
  assert(!pattern.test(source), `dashboard contains ${description}`);
}

console.log(
  `Dashboard OK: ${dashboard.spec.title} ` +
    `(${Object.keys(dashboard.spec.elements).length} elements, ` +
    `${panelExpressions.length} PromQL expressions, ` +
    `${variables.length} variables)`,
);
