{{/* Expand the chart name. */}}
{{- define "powerdns-admin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Create a release-scoped fully qualified name. */}}
{{- define "powerdns-admin.fullname" -}}
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

{{- define "powerdns-admin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "powerdns-admin.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "powerdns-admin.suffixedName" -}}
{{- $suffix := printf "-%s" .suffix -}}
{{- $maxBaseLength := int (sub 63 (len $suffix)) -}}
{{- $base := include "powerdns-admin.fullname" .context | trunc $maxBaseLength | trimSuffix "-" -}}
{{- printf "%s%s" $base $suffix -}}
{{- end -}}

{{- define "powerdns-admin.postgresqlName" -}}
{{- include "powerdns-admin.suffixedName" (dict "context" . "suffix" "postgresql") -}}
{{- end -}}

{{- define "powerdns-admin.migrationName" -}}
{{- include "powerdns-admin.suffixedName" (dict "context" . "suffix" "database-migration") -}}
{{- end -}}

{{- define "powerdns-admin.tlsSecretName" -}}
{{- if .Values.route.tls.secretName -}}
{{- .Values.route.tls.secretName -}}
{{- else -}}
{{- include "powerdns-admin.suffixedName" (dict "context" . "suffix" "tls") -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-admin.gatewayName" -}}
{{- default (include "powerdns-admin.fullname" .) .Values.route.gateway.name -}}
{{- end -}}

{{- define "powerdns-admin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "powerdns-admin.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{- define "powerdns-admin.webSelectorLabels" -}}
{{ include "powerdns-admin.selectorLabels" . }}
app.kubernetes.io/component: "web"
{{- end -}}

{{- define "powerdns-admin.postgresqlSelectorLabels" -}}
{{ include "powerdns-admin.selectorLabels" . }}
app.kubernetes.io/component: "database"
{{- end -}}

{{- define "powerdns-admin.migrationSelectorLabels" -}}
{{ include "powerdns-admin.selectorLabels" . }}
app.kubernetes.io/component: "migration"
{{- end -}}

{{- define "powerdns-admin.labels" -}}
{{- $labels := dict
  "helm.sh/chart" (include "powerdns-admin.chart" .)
  "app.kubernetes.io/name" (include "powerdns-admin.name" .)
  "app.kubernetes.io/instance" .Release.Name
  "app.kubernetes.io/version" .Chart.AppVersion
  "app.kubernetes.io/managed-by" .Release.Service
-}}
{{- range $key, $value := .Values.commonLabels -}}
{{- $_ := set $labels $key $value -}}
{{- end -}}
{{- toYaml $labels -}}
{{- end -}}

{{/* Immutable references deliberately include both the human-readable tag and digest. */}}
{{- define "powerdns-admin.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.image.registry -}}
{{- $repository := .Values.image.repository -}}
{{- if $registry -}}
{{- $repository = printf "%s/%s" $registry $repository -}}
{{- end -}}
{{- if .Values.image.digest -}}
{{- printf "%s:%s@%s" $repository .Values.image.tag .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repository .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-admin.postgresqlImage" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.postgresql.image.registry -}}
{{- $repository := .Values.postgresql.image.repository -}}
{{- if $registry -}}
{{- $repository = printf "%s/%s" $registry $repository -}}
{{- end -}}
{{- if .Values.postgresql.image.digest -}}
{{- printf "%s:%s@%s" $repository .Values.postgresql.image.tag .Values.postgresql.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repository .Values.postgresql.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-admin.imagePullSecrets" -}}
{{- $pullSecrets := list -}}
{{- range concat (.Values.global.imagePullSecrets | default list) (.Values.image.pullSecrets | default list) (.Values.postgresql.image.pullSecrets | default list) -}}
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

{{- define "powerdns-admin.postgresqlStorageClass" -}}
{{- $storageClass := .Values.postgresql.persistence.storageClass | default .Values.global.defaultStorageClass | default .Values.global.storageClass -}}
{{- if $storageClass -}}
{{- if eq $storageClass "-" -}}
storageClassName: ""
{{- else -}}
storageClassName: {{ $storageClass | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-admin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "powerdns-admin.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Shared application environment and existing-Secret mounts. */}}
{{- define "powerdns-admin.configEnv" -}}
- name: CAPTCHA_ENABLE
  value: {{ ternary "true" "false" .Values.config.captchaEnable | quote }}
- name: CSRF_COOKIE_SECURE
  value: {{ ternary "true" "false" .Values.config.csrfCookieSecure | quote }}
- name: GUNICORN_LOGLEVEL
  value: {{ .Values.config.gunicorn.logLevel | quote }}
- name: GUNICORN_TIMEOUT
  value: {{ .Values.config.gunicorn.timeout | quote }}
- name: GUNICORN_WORKERS
  value: {{ .Values.config.gunicorn.workers | quote }}
- name: BIND_ADDRESS
  value: {{ .Values.config.gunicorn.bindAddress | quote }}
- name: HSTS_ENABLED
  value: {{ ternary "true" "false" .Values.config.hstsEnabled | quote }}
- name: PDNS_ADMIN_LOG_LEVEL
  value: {{ .Values.config.logLevel | quote }}
- name: PYTHONDONTWRITEBYTECODE
  value: "1"
- name: PYTHONUNBUFFERED
  value: "1"
- name: SERVER_EXTERNAL_SSL
  value: {{ ternary "true" "false" .Values.config.serverExternalSsl | quote }}
- name: SESSION_COOKIE_SECURE
  value: {{ ternary "true" "false" .Values.config.sessionCookieSecure | quote }}
- name: SESSION_TYPE
  value: {{ .Values.config.sessionType | quote }}
- name: SIGNUP_ENABLED
  value: {{ ternary "true" "false" .Values.config.signupEnabled | quote }}
- name: SITE_URL
  value: {{ .Values.config.siteUrl | quote }}
- name: SQLALCHEMY_TRACK_MODIFICATIONS
  value: {{ ternary "true" "false" .Values.config.sqlalchemyTrackModifications | quote }}
- name: SECRET_KEY_FILE
  value: /var/run/secrets/powerdns-admin/runtime/{{ .Values.runtimeSecret.keys.secretKey }}
- name: SQLALCHEMY_DATABASE_URI_FILE
  value: /var/run/secrets/powerdns-admin/database/{{ .Values.database.keys.sqlalchemyDatabaseUri }}
- name: PDNS_API_URL_FILE
  value: /var/run/secrets/powerdns-admin/runtime/{{ .Values.runtimeSecret.keys.pdnsApiUrl }}
- name: PDNS_API_KEY_FILE
  value: /var/run/secrets/powerdns-admin/runtime/{{ .Values.runtimeSecret.keys.pdnsApiKey }}
{{- end -}}

{{- define "powerdns-admin.secretVolumes" -}}
- name: database-secret
  secret:
    secretName: {{ .Values.database.existingSecret | quote }}
    defaultMode: 0440
- name: runtime-secret
  secret:
    secretName: {{ .Values.runtimeSecret.existingSecret | quote }}
    defaultMode: 0440
{{- end -}}

{{- define "powerdns-admin.secretVolumeMounts" -}}
- name: database-secret
  mountPath: /var/run/secrets/powerdns-admin/database
  readOnly: true
- name: runtime-secret
  mountPath: /var/run/secrets/powerdns-admin/runtime
  readOnly: true
{{- end -}}

{{/* Cross-field checks not expressible in JSON Schema. */}}
{{- define "powerdns-admin.validateValues" -}}
{{- $reservedLabels := list "helm.sh/chart" "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/version" "app.kubernetes.io/managed-by" "app.kubernetes.io/component" -}}
{{- range $label := $reservedLabels -}}
{{- if hasKey ($.Values.commonLabels | default dict) $label -}}
{{- fail (printf "commonLabels must not override reserved label %q" $label) -}}
{{- end -}}
{{- if hasKey ($.Values.podLabels | default dict) $label -}}
{{- fail (printf "podLabels must not override reserved label %q" $label) -}}
{{- end -}}
{{- if hasKey ($.Values.postgresql.podLabels | default dict) $label -}}
{{- fail (printf "postgresql.podLabels must not override reserved label %q" $label) -}}
{{- end -}}
{{- end -}}
{{- if ne (int .Values.replicaCount) 1 -}}
{{- fail "replicaCount must be 1; this chart's migration and single-node contract does not support concurrent web startup" -}}
{{- end -}}
{{- if and (or .Values.config.csrfCookieSecure .Values.config.sessionCookieSecure .Values.config.hstsEnabled .Values.config.serverExternalSsl) (not (hasPrefix "https://" .Values.config.siteUrl)) -}}
{{- fail "config.siteUrl must use https:// while secure-cookie, HSTS, or external-SSL settings are enabled" -}}
{{- end -}}
{{- if .Values.route.enabled -}}
{{- if .Values.config.signupEnabled -}}
{{- fail "config.signupEnabled must be false before route.enabled=true; bootstrap the first Administrator through a local port-forward" -}}
{{- end -}}
{{- if eq .Values.route.host "powerdns-admin.example.invalid" -}}
{{- fail "route.host must be replaced before route.enabled=true" -}}
{{- end -}}
{{- range $label := splitList "." .Values.route.host -}}
{{- if gt (len $label) 63 -}}
{{- fail "each route.host DNS label must be at most 63 characters" -}}
{{- end -}}
{{- end -}}
{{- $scheme := ternary "https" "http" .Values.route.tls.enabled -}}
{{- if ne .Values.config.siteUrl (printf "%s://%s" $scheme .Values.route.host) -}}
{{- fail "config.siteUrl must exactly match the enabled route scheme and host" -}}
{{- end -}}
{{- if and .Values.route.http.redirectToHttps (not .Values.route.tls.enabled) -}}
{{- fail "route.http.redirectToHttps requires route.tls.enabled=true" -}}
{{- end -}}
{{- if and .Values.route.tls.enabled (not (and .Values.config.csrfCookieSecure .Values.config.sessionCookieSecure .Values.config.hstsEnabled .Values.config.serverExternalSsl)) -}}
{{- fail "an HTTPS route requires CSRF/session secure cookies, HSTS, and serverExternalSsl" -}}
{{- end -}}
{{- if and (not .Values.route.gateway.create) (not .Values.route.gateway.name) -}}
{{- fail "route.gateway.name is required when route.gateway.create=false" -}}
{{- end -}}
{{- if and (not .Values.route.gateway.create) .Values.route.tls.certificate.create -}}
{{- fail "route.tls.certificate.create must be false when route.gateway.create=false; the existing Gateway owns its TLS Secret" -}}
{{- end -}}
{{- if and .Values.route.gateway.create (empty .Values.route.gateway.selector) -}}
{{- fail "route.gateway.selector must not be empty when route.gateway.create=true" -}}
{{- end -}}
{{- if and .Values.route.tls.certificate.create (not .Values.route.tls.enabled) -}}
{{- fail "route.tls.certificate.create requires route.tls.enabled=true" -}}
{{- end -}}
{{- if and .Values.route.tls.certificate.create (ne .Values.route.tls.certificate.namespace .Values.route.gateway.workloadNamespace) -}}
{{- fail "route.tls.certificate.namespace must equal route.gateway.workloadNamespace so the gateway workload can read credentialName" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.postgresql.enabled (eq .Values.database.existingSecret "") -}}
{{- fail "database.existingSecret is required by the bundled PostgreSQL database" -}}
{{- end -}}
{{- end -}}
