{{/*
Expand the chart name.
*/}}
{{- define "fortigate-exporter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a stable fully qualified name.
*/}}
{{- define "fortigate-exporter.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create a DNS-safe Probe name that remains unique when the release name is
long. The target prefix keeps the name readable; the hash protects targets
whose names share the same truncated prefix.
*/}}
{{- define "fortigate-exporter.probeName" -}}
{{- $targetPrefix := .target.name | trunc 20 | trimSuffix "-" -}}
{{- $targetHash := .target.name | sha256sum | trunc 8 -}}
{{- $suffix := printf "-%s-%s" $targetPrefix $targetHash -}}
{{- $prefixLength := sub 63 (len $suffix) | int -}}
{{- printf "%s%s" (include "fortigate-exporter.fullname" .root | trunc $prefixLength | trimSuffix "-") $suffix -}}
{{- end }}

{{/*
Reserve space for the fixed Dashboard suffix.
*/}}
{{- define "fortigate-exporter.dashboardName" -}}
{{- printf "%s-dashboard" (include "fortigate-exporter.fullname" . | trunc 53 | trimSuffix "-") -}}
{{- end }}

{{/*
Chart label value.
*/}}
{{- define "fortigate-exporter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "fortigate-exporter.labels" -}}
helm.sh/chart: {{ include "fortigate-exporter.chart" . }}
{{ include "fortigate-exporter.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: exporter
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "fortigate-exporter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fortigate-exporter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "fortigate-exporter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fortigate-exporter.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Immutable image reference when a digest is configured.
*/}}
{{- define "fortigate-exporter.image" -}}
{{- if .Values.image.digest }}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}
{{- end }}

{{/*
Render a FortiGate interface metric restricted to the configured critical
interfaces. deviceAliasRegex takes precedence over deviceNameRegex, which
takes precedence over the legacy global nameRegex. Device maps produce one
selector per fortigate_device label.
*/}}
{{- define "fortigate-exporter.criticalInterfaceMetric" -}}
{{- $root := .root -}}
{{- $config := .config -}}
{{- $metric := .metric -}}
{{- $range := .range | default "" -}}
{{- $function := .function | default "" -}}
{{- $deviceSelectors := .deviceAliasRegexOverride | default dict -}}
{{- if eq (len $deviceSelectors) 0 -}}
{{- $deviceSelectors = $config.deviceAliasRegex | default dict -}}
{{- end -}}
{{- $selectorLabel := "alias" -}}
{{- if eq (len $deviceSelectors) 0 -}}
{{- $deviceSelectors = $config.deviceNameRegex | default dict -}}
{{- $selectorLabel = "name" -}}
{{- end -}}
{{- if gt (len $deviceSelectors) 0 -}}
(
{{- $first := true -}}
{{- range $device, $selectorRegex := $deviceSelectors -}}
{{- if not $first }} or {{ end -}}
{{- if $function }}{{ $function }}({{ end -}}
{{ $metric }}{job={{ $root.Values.probe.jobName | quote }},fortigate_device={{ $device | quote }},{{ $selectorLabel }}=~{{ $selectorRegex | quote }}}{{ $range }}
{{- if $function }}){{ end -}}
{{- $first = false -}}
{{- end -}}
)
{{- else -}}
{{- if $function }}{{ $function }}({{ end -}}
{{ $metric }}{job={{ $root.Values.probe.jobName | quote }},name=~{{ $config.nameRegex | quote }}}{{ $range }}
{{- if $function }}){{ end -}}
{{- end -}}
{{- end }}

{{/*
Render WAN utilization using configured contract bandwidth instead of the
physical interface speed reported by FortiGate. Receive uses downstreamKbps;
transmit uses upstreamKbps. Kbps is converted to bits per second with 1000.
*/}}
{{- define "fortigate-exporter.wanBandwidthUtilization" -}}
{{- $root := .root -}}
{{- $config := .config -}}
{{- $direction := .direction -}}
{{- $metric := "fortigate_interface_receive_bytes_total" -}}
{{- $capacityKey := "downstreamKbps" -}}
{{- if eq $direction "transmit" -}}
{{- $metric = "fortigate_interface_transmit_bytes_total" -}}
{{- $capacityKey = "upstreamKbps" -}}
{{- end -}}
(
{{- $first := true -}}
{{- range $device, $deviceConfig := $config.devices -}}
{{- if not $first }} or {{ end -}}
(rate({{ $metric }}{job={{ $root.Values.probe.jobName | quote }},fortigate_device={{ $device | quote }},alias=~{{ $deviceConfig.aliasRegex | quote }}}[5m]) * 8 / ({{ index $deviceConfig $capacityKey }} * 1000))
{{- $first = false -}}
{{- end -}}
)
{{- end }}
