{{/*
Expand the chart name.
*/}}
{{- define "oxidized.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a release-scoped fully qualified name.
*/}}
{{- define "oxidized.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a chart label value.
*/}}
{{- define "oxidized.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Use the release namespace unless an explicit namespace override is provided.
Namespace creation remains the responsibility of Helm's --create-namespace.
*/}}
{{- define "oxidized.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Stable labels used by workload and Service selectors.
*/}}
{{- define "oxidized.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oxidized.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{/*
Selectors for the Oxidized server workload and Helm test Pod. Keeping the
component in selectors prevents the Service and NetworkPolicy from selecting
the test Pod.
*/}}
{{- define "oxidized.workloadSelectorLabels" -}}
{{ include "oxidized.selectorLabels" . }}
app.kubernetes.io/component: "server"
{{- end -}}

{{- define "oxidized.testSelectorLabels" -}}
{{ include "oxidized.selectorLabels" . }}
app.kubernetes.io/component: "test"
{{- end -}}

{{/*
Standard metadata labels. Reserved labels are validated before rendering.
*/}}
{{- define "oxidized.labels" -}}
{{- $labels := dict
  "helm.sh/chart" (include "oxidized.chart" .)
  "app.kubernetes.io/name" (include "oxidized.name" .)
  "app.kubernetes.io/instance" .Release.Name
  "app.kubernetes.io/version" .Chart.AppVersion
  "app.kubernetes.io/managed-by" .Release.Service
-}}
{{- range $key, $value := .Values.commonLabels -}}
{{- $_ := set $labels $key $value -}}
{{- end -}}
{{- toYaml $labels -}}
{{- end -}}

{{/*
Append a suffix while reserving its full length inside the 63-character DNS
label limit. Truncating only after concatenation can remove the suffix and make
two same-Kind resources collide.
*/}}
{{- define "oxidized.suffixedName" -}}
{{- $suffix := printf "-%s" .suffix -}}
{{- $maxBaseLength := int (sub 63 (len $suffix)) -}}
{{- $base := include "oxidized.fullname" .context | trunc $maxBaseLength | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- end -}}

{{/*
Names for supporting resources.
*/}}
{{- define "oxidized.configMapName" -}}
{{- if .Values.config.existingConfigmap -}}
{{- .Values.config.existingConfigmap -}}
{{- else -}}
{{- include "oxidized.suffixedName" (dict "context" . "suffix" "config") -}}
{{- end -}}
{{- end -}}

{{- define "oxidized.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- include "oxidized.suffixedName" (dict "context" . "suffix" "data") -}}
{{- end -}}
{{- end -}}

{{- define "oxidized.sshSecretName" -}}
{{- if .Values.sshSecret.existingSecret -}}
{{- .Values.sshSecret.existingSecret -}}
{{- else if .Values.sshSecret.name -}}
{{- .Values.sshSecret.name -}}
{{- else -}}
{{- include "oxidized.suffixedName" (dict "context" . "suffix" "ssh-keys") -}}
{{- end -}}
{{- end -}}

{{- define "oxidized.runtimeSecretName" -}}
{{- if .Values.runtimeSecret.existingSecret -}}
{{- .Values.runtimeSecret.existingSecret -}}
{{- else if .Values.runtimeSecret.name -}}
{{- .Values.runtimeSecret.name -}}
{{- else -}}
{{- include "oxidized.suffixedName" (dict "context" . "suffix" "runtime") -}}
{{- end -}}
{{- end -}}

{{/*
Main and test image references. Digest takes precedence over tag, and the
global registry takes precedence over the image-local registry.
*/}}
{{- define "oxidized.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.image.registry -}}
{{- $repository := .Values.image.repository -}}
{{- if $registry -}}
{{- $repository = printf "%s/%s" $registry $repository -}}
{{- end -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end -}}

{{- define "oxidized.testImage" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.tests.image.registry -}}
{{- $repository := .Values.tests.image.repository -}}
{{- if $registry -}}
{{- $repository = printf "%s/%s" $registry $repository -}}
{{- end -}}
{{- if .Values.tests.image.digest -}}
{{- printf "%s@%s" $repository .Values.tests.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repository .Values.tests.image.tag -}}
{{- end -}}
{{- end -}}

{{/*
Merge global and image-local pull secrets. String and {name: ...} forms are
accepted to remain compatible with common Helm values conventions.
*/}}
{{- define "oxidized.imagePullSecrets" -}}
{{- $pullSecrets := list -}}
{{- range concat (.Values.global.imagePullSecrets | default list) (.Values.image.pullSecrets | default list) -}}
{{- if kindIs "string" . -}}
{{- $pullSecrets = append $pullSecrets (dict "name" .) -}}
{{- else -}}
{{- $pullSecrets = append $pullSecrets . -}}
{{- end -}}
{{- end -}}
{{- with $pullSecrets -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the PVC StorageClass. A value of "-" explicitly emits an empty class.
*/}}
{{- define "oxidized.storageClass" -}}
{{- $storageClass := .Values.persistence.storageClass | default .Values.global.defaultStorageClass | default .Values.global.storageClass -}}
{{- if $storageClass -}}
{{- if eq $storageClass "-" -}}
storageClassName: ""
{{- else -}}
storageClassName: {{ $storageClass | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the ServiceAccount name.
*/}}
{{- define "oxidized.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "oxidized.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Cross-field validations that JSON Schema cannot express clearly.
*/}}
{{- define "oxidized.validateValues" -}}
{{- $reservedLabels := list "helm.sh/chart" "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/version" "app.kubernetes.io/managed-by" "app.kubernetes.io/component" -}}
{{- range $label := $reservedLabels -}}
{{- if hasKey ($.Values.commonLabels | default dict) $label -}}
{{- fail (printf "commonLabels must not override reserved label %q" $label) -}}
{{- end -}}
{{- if hasKey ($.Values.podLabels | default dict) $label -}}
{{- fail (printf "podLabels must not override reserved label %q" $label) -}}
{{- end -}}
{{- end -}}
{{- range $annotation := list "checksum/config" "checksum/runtime-secret" "checksum/ssh-secret" -}}
{{- if hasKey ($.Values.podAnnotations | default dict) $annotation -}}
{{- fail (printf "podAnnotations must not override reserved annotation %q" $annotation) -}}
{{- end -}}
{{- end -}}
{{- if and .Values.config.existingConfigmap .Values.config.configuration -}}
{{- fail "config.existingConfigmap and config.configuration are mutually exclusive" -}}
{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}
{{- fail "replicaCount must be 1 because Oxidized and its Git repository are single-writer" -}}
{{- end -}}
{{- if and .Values.initContainerSecurityContext.enabled (ne (int .Values.initContainerSecurityContext.runAsUser) 0) (not .Values.podSecurityContext.enabled) -}}
{{- fail "podSecurityContext.enabled must be true when the built-in init container runs as a non-root UID so emptyDir and PVC volumes receive fsGroup write access" -}}
{{- end -}}
{{- if .Values.runtimeSecret.enabled -}}
{{- if and .Values.runtimeSecret.create .Values.runtimeSecret.existingSecret -}}
{{- fail "runtimeSecret.create and runtimeSecret.existingSecret cannot both be set" -}}
{{- end -}}
{{- if and (not .Values.runtimeSecret.create) (not .Values.runtimeSecret.existingSecret) -}}
{{- fail "runtimeSecret.existingSecret is required when runtimeSecret.enabled=true and create=false" -}}
{{- end -}}
{{- end -}}
{{- if and (not .Values.runtimeSecret.enabled) .Values.runtimeSecret.secretKeys.extra -}}
{{- fail "runtimeSecret.enabled must be true when runtimeSecret.secretKeys.extra is configured" -}}
{{- end -}}
{{- $reservedRuntimeEnvironmentNames := list "OXIDIZED_DEVICE_USERNAME" "OXIDIZED_DEVICE_PASSWORD" "OXIDIZED_DEFAULT_USERNAME" "OXIDIZED_DEFAULT_PASSWORD" "NETBOX_API_TOKEN" "OXIDIZED_READONLY_DEVICE_USERNAME" "OXIDIZED_READONLY_DEVICE_PASSWORD" "OXIDIZED_READONLY_USERNAME" "OXIDIZED_READONLY_PASSWORD" -}}
{{- $runtimeSecretKeys := list .Values.runtimeSecret.secretKeys.deviceUsernameKey .Values.runtimeSecret.secretKeys.devicePasswordKey .Values.runtimeSecret.secretKeys.netboxApiTokenKey .Values.runtimeSecret.secretKeys.readonlyDeviceUsernameKey .Values.runtimeSecret.secretKeys.readonlyDevicePasswordKey -}}
{{- range $environmentName, $secretKey := .Values.runtimeSecret.secretKeys.extra -}}
{{- if has $environmentName $reservedRuntimeEnvironmentNames -}}
{{- fail (printf "runtimeSecret.secretKeys.extra must not redefine reserved environment variable %q" $environmentName) -}}
{{- end -}}
{{- if and $.Values.runtimeSecret.create (not (hasKey $.Values.runtimeSecret.data.extra $environmentName)) -}}
{{- fail (printf "runtimeSecret.data.extra.%s is required when runtimeSecret.create=true" $environmentName) -}}
{{- end -}}
{{- $runtimeSecretKeys = append $runtimeSecretKeys $secretKey -}}
{{- end -}}
{{- if ne (len $runtimeSecretKeys) (len (uniq $runtimeSecretKeys)) -}}
{{- fail "runtimeSecret.secretKeys values must be unique" -}}
{{- end -}}
{{- range $environmentName, $_ := .Values.runtimeSecret.data.extra -}}
{{- if not (hasKey $.Values.runtimeSecret.secretKeys.extra $environmentName) -}}
{{- fail (printf "runtimeSecret.data.extra.%s has no matching runtimeSecret.secretKeys.extra entry" $environmentName) -}}
{{- end -}}
{{- end -}}
{{- if not .Values.config.existingConfigmap -}}
{{- $configuration := .Values.config.configuration -}}
{{- if $configuration -}}
{{- $configuration = tpl $configuration . -}}
{{- else -}}
{{- $configuration = include "oxidized.defaultConfiguration" . -}}
{{- end -}}
{{- $knownRuntimeTokens := list "__OXIDIZED_DEVICE_USERNAME__" "__OXIDIZED_DEVICE_PASSWORD__" "__OXIDIZED_DEFAULT_USERNAME__" "__OXIDIZED_DEFAULT_PASSWORD__" "__OXIDIZED_READONLY_DEVICE_USERNAME__" "__OXIDIZED_READONLY_DEVICE_PASSWORD__" "__OXIDIZED_READONLY_USERNAME__" "__OXIDIZED_READONLY_PASSWORD__" -}}
{{- range $environmentName, $_ := .Values.runtimeSecret.secretKeys.extra -}}
{{- $knownRuntimeTokens = append $knownRuntimeTokens (printf "__%s__" $environmentName) -}}
{{- end -}}
{{- range $token := regexFindAll "__OXIDIZED_[A-Z][A-Z0-9_]*__" $configuration -1 -}}
{{- if not (has $token $knownRuntimeTokens) -}}
{{- fail (printf "runtime Secret placeholder %q has no matching runtimeSecret.secretKeys.extra entry" $token) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if .Values.sshSecret.enabled -}}
{{- if and .Values.sshSecret.create .Values.sshSecret.existingSecret -}}
{{- fail "sshSecret.create and sshSecret.existingSecret cannot both be set" -}}
{{- end -}}
{{- if and (not .Values.sshSecret.create) (not .Values.sshSecret.existingSecret) -}}
{{- fail "sshSecret.existingSecret is required when sshSecret.enabled=true and create=false" -}}
{{- end -}}
{{- if and .Values.sshSecret.create (not (or .Values.sshSecret.data.id_rsa .Values.sshSecret.data.id_rsa_pub .Values.sshSecret.data.known_hosts)) -}}
{{- fail "at least one sshSecret.data value is required when sshSecret.enabled=true and create=true" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.runtimeSecret.enabled .Values.sshSecret.enabled (or .Values.runtimeSecret.create .Values.sshSecret.create) (eq (include "oxidized.runtimeSecretName" .) (include "oxidized.sshSecretName" .)) -}}
{{- fail "runtimeSecret and sshSecret must not resolve to the same name when either Secret is chart-created" -}}
{{- end -}}
{{- if and .Values.config.hooks.githubrepo.enabled (not .Values.sshSecret.enabled) -}}
{{- fail "sshSecret.enabled must be true when config.hooks.githubrepo.enabled=true" -}}
{{- end -}}
{{- if and .Values.config.hooks.githubrepo.enabled (not .Values.config.hooks.githubrepo.remoteRepo) -}}
{{- fail "config.hooks.githubrepo.remoteRepo is required when the hook is enabled" -}}
{{- end -}}
{{- if and .Values.config.hooks.githubrepo.enabled .Values.sshSecret.create (not (and .Values.sshSecret.data.id_rsa .Values.sshSecret.data.id_rsa_pub .Values.sshSecret.data.known_hosts)) -}}
{{- fail "sshSecret.data.id_rsa, id_rsa_pub, and known_hosts are required for a chart-created githubrepo SSH Secret" -}}
{{- end -}}
{{- if and .Values.config.hooks.exec.enabled (not .Values.config.hooks.exec.cmd) -}}
{{- fail "config.hooks.exec.cmd is required when the exec hook is enabled" -}}
{{- end -}}
{{- if and .Values.config.hooks.slackdiff.enabled (or (not .Values.config.hooks.slackdiff.token) (not .Values.config.hooks.slackdiff.channel)) -}}
{{- fail "config.hooks.slackdiff.token and channel are required when the hook is enabled" -}}
{{- end -}}
{{- if and .Values.config.hooks.xmppdiff.enabled (or (not .Values.config.hooks.xmppdiff.jid) (not .Values.config.hooks.xmppdiff.password) (not .Values.config.hooks.xmppdiff.channel) (not .Values.config.hooks.xmppdiff.nick)) -}}
{{- fail "config.hooks.xmppdiff.jid, password, channel, and nick are required when the hook is enabled" -}}
{{- end -}}
{{- if and .Values.config.source.http.enabled (not .Values.config.source.http.url) -}}
{{- fail "config.source.http.url is required when the HTTP source is enabled" -}}
{{- end -}}
{{- if and .Values.config.source.http.enabled (not (regexMatch "^https?://" .Values.config.source.http.url)) -}}
{{- fail "config.source.http.url must be an absolute http:// or https:// URL" -}}
{{- end -}}
{{- if and .Values.config.source.http.enabled .Values.config.source.http.pagination (not .Values.config.source.http.hostsLocation) -}}
{{- fail "config.source.http.hostsLocation is required when HTTP pagination is enabled" -}}
{{- end -}}
{{- if and (not .Values.config.existingConfigmap) (not .Values.config.configuration) (eq .Values.config.source.default "csv") (not (trim .Values.config.source.csv.routerDb)) -}}
{{- fail "config.source.csv.routerDb must contain at least one node when CSV is the default source; Oxidized cannot start with an empty source" -}}
{{- end -}}
{{- if and .Values.config.output.http.enabled (not .Values.config.output.http.url) -}}
{{- fail "config.output.http.url is required when the HTTP output is enabled" -}}
{{- end -}}
{{- if and .Values.config.output.http.enabled (not (regexMatch "^https?://" .Values.config.output.http.url)) -}}
{{- fail "config.output.http.url must be an absolute http:// or https:// URL" -}}
{{- end -}}
{{- if and (not .Values.config.existingConfigmap) (not .Values.config.configuration) -}}
{{- $source := index .Values.config.source .Values.config.source.default -}}
{{- if not $source -}}
{{- fail (printf "config.source.default references unknown source %q" .Values.config.source.default) -}}
{{- else if not $source.enabled -}}
{{- fail (printf "config.source.%s.enabled must be true because it is the default source" .Values.config.source.default) -}}
{{- end -}}
{{- if not (hasKey $source.map "name") -}}
{{- fail (printf "config.source.%s.map.name is required by Oxidized" .Values.config.source.default) -}}
{{- end -}}
{{- $output := index .Values.config.output .Values.config.output.default -}}
{{- if not $output -}}
{{- fail (printf "config.output.default references unknown output %q" .Values.config.output.default) -}}
{{- else if not $output.enabled -}}
{{- fail (printf "config.output.%s.enabled must be true because it is the default output" .Values.config.output.default) -}}
{{- end -}}
{{- if and .Values.config.input.ssh.enabled .Values.config.input.ssh.secure (not .Values.sshSecret.enabled) -}}
{{- fail "sshSecret.enabled must be true and provide known_hosts when the generated configuration enables strict SSH host verification" -}}
{{- end -}}
{{- if and .Values.config.input.ssh.enabled .Values.config.input.ssh.secure .Values.sshSecret.create (not .Values.sshSecret.data.known_hosts) -}}
{{- fail "sshSecret.data.known_hosts is required for a chart-created Secret when strict SSH host verification is enabled" -}}
{{- end -}}
{{- $input := index .Values.config.input .Values.config.input.default -}}
{{- if not $input.enabled -}}
{{- fail (printf "config.input.%s.enabled must be true because it is the default input" .Values.config.input.default) -}}
{{- end -}}
{{- end -}}
{{- if and (ne (toString .Values.pdb.minAvailable) "") (ne (toString .Values.pdb.maxUnavailable) "") -}}
{{- fail "pdb.minAvailable and pdb.maxUnavailable are mutually exclusive" -}}
{{- end -}}
{{- end -}}
