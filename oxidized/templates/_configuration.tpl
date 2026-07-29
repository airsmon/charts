{{- define "oxidized.defaultConfiguration" -}}
username: {{ .Values.config.core.usernamePlaceholder | quote }}
password: {{ .Values.config.core.passwordPlaceholder | quote }}
model: {{ .Values.config.core.model | quote }}
resolve_dns: {{ .Values.config.core.resolveDns }}
interval: {{ .Values.config.core.interval }}
use_syslog: {{ .Values.config.core.useSyslog }}
{{ if .Values.config.core.log }}
log: {{ .Values.config.core.log | quote }}
{{ end }}
debug: {{ .Values.config.core.debug }}
threads: {{ .Values.config.core.threads }}
use_max_threads: {{ .Values.config.core.useMaxThreads }}
timeout: {{ .Values.config.core.timeout }}
timelimit: {{ .Values.config.core.timelimit }}
retries: {{ .Values.config.core.retries }}
prompt: !ruby/regexp {{ .Values.config.core.prompt }}
next_adds_job: {{ .Values.config.core.nextAddsJob }}
vars:
  {{ if .Values.config.vars.enable.enabled }}
  enable: {{ .Values.config.vars.enable.value | quote }}
  {{ end }}
  remove_secret: {{ .Values.config.vars.removeSecret }}
  auth_methods:
    {{ range .Values.config.vars.authMethods }}
    - {{ . | quote }}
    {{ end }}
  {{ if .Values.config.vars.sshKeys }}
  ssh_keys:
    {{ range .Values.config.vars.sshKeys }}
    - {{ . | quote }}
    {{ end }}
  {{ end }}
  ssh_no_exec: {{ .Values.config.vars.sshNoExec }}
  ssh_no_keepalive: {{ .Values.config.vars.sshNoKeepalive }}
  {{ if .Values.config.vars.sshKex }}
  ssh_kex: {{ join "," .Values.config.vars.sshKex | quote }}
  {{ end }}
  {{ if .Values.config.vars.sshEncryption }}
  ssh_encryption: {{ join "," .Values.config.vars.sshEncryption | quote }}
  {{ end }}
  {{ if .Values.config.vars.sshHmac }}
  ssh_hmac: {{ join "," .Values.config.vars.sshHmac | quote }}
  {{ end }}
  {{ if .Values.config.vars.metadata.enabled }}
  metadata: {{ .Values.config.vars.metadata.value }}
  {{ if .Values.config.vars.metadata.top }}
  metadata_top: {{ .Values.config.vars.metadata.top | quote }}
  {{ end }}
  {{ if .Values.config.vars.metadata.bottom }}
  metadata_bottom: {{ .Values.config.vars.metadata.bottom | quote }}
  {{ end }}
  {{ end }}
  {{ if .Values.config.vars.outputStoreMode.enabled }}
  output_store_mode: {{ .Values.config.vars.outputStoreMode.value | quote }}
  {{ end }}
  {{ range $key, $value := .Values.config.vars.extra }}
  {{ $key | snakecase }}: {{ $value | toJson }}
  {{ end }}
{{ if empty .Values.config.groupMap }}
group_map: {}
{{ else }}
group_map:
  {{- range $key, $value := .Values.config.groupMap }}
  {{ if hasPrefix "!ruby/regexp " $key }}{{ $key }}{{ else }}{{ $key | quote }}{{ end }}: {{ $value | quote }}
  {{- end }}
{{ end }}
pid: {{ .Values.config.core.pid | quote }}
{{ if .Values.config.logger.enabled }}
logger:
  level: {{ .Values.config.logger.level }}
  {{ if .Values.config.logger.appenders }}
  appenders:
    {{ toYaml .Values.config.logger.appenders | nindent 4 }}
  {{ end }}
{{ end }}
{{ if .Values.web.enabled }}
extensions:
  oxidized-web:
    load: true
    listen: {{ .Values.web.listen | quote }}
    port: {{ .Values.web.port }}
    {{ if .Values.web.urlPrefix }}
    url_prefix: {{ .Values.web.urlPrefix | quote }}
    {{ end }}
    {{ if .Values.web.vhosts }}
    vhosts:
      {{ range .Values.web.vhosts }}
      - {{ . | quote }}
      {{ end }}
    {{ end }}
{{ end }}
crash:
  directory: {{ .Values.config.crash.directory | quote }}
  hostnames: {{ .Values.config.crash.hostnames }}
stats:
  history_size: {{ .Values.config.stats.historySize }}
input:
  default: {{ .Values.config.input.default | quote }}
  debug: {{ .Values.config.input.debug }}
  {{ if .Values.config.input.ssh.enabled }}
  ssh:
    secure: {{ .Values.config.input.ssh.secure }}
  {{ end }}
  utf8_encoded: {{ .Values.config.input.utf8Encoded }}
output:
  default: {{ .Values.config.output.default | quote }}
  clean_obsolete_nodes: {{ .Values.config.output.cleanObsoleteNodes }}
  {{ if .Values.config.output.git.enabled }}
  git:
    user: {{ .Values.config.output.git.user | quote }}
    email: {{ .Values.config.output.git.email | quote }}
    repo: {{ .Values.config.output.git.repo | quote }}
    single_repo: {{ .Values.config.output.git.singleRepo }}
  {{ end }}
  {{ if .Values.config.output.file.enabled }}
  file:
    directory: {{ .Values.config.output.file.directory | quote }}
  {{ end }}
  {{ if .Values.config.output.http.enabled }}
  http:
    url: {{ .Values.config.output.http.url | quote }}
    {{ if .Values.config.output.http.user }}
    user: {{ .Values.config.output.http.user | quote }}
    {{ end }}
    {{ if .Values.config.output.http.password }}
    password: {{ .Values.config.output.http.password | quote }}
    {{ end }}
    ssl_verify: {{ .Values.config.output.http.sslVerify }}
    {{ if .Values.config.output.http.headers }}
    headers:
      {{ range $key, $value := .Values.config.output.http.headers }}
      {{ $key | quote }}: {{ $value | quote }}
      {{ end }}
    {{ end }}
  {{ end }}
{{ if or .Values.config.hooks.githubrepo.enabled .Values.config.hooks.exec.enabled .Values.config.hooks.slackdiff.enabled .Values.config.hooks.xmppdiff.enabled }}
hooks:
  {{ if .Values.config.hooks.githubrepo.enabled }}
  githubrepo:
    type: {{ .Values.config.hooks.githubrepo.type | quote }}
    events:
      {{ range .Values.config.hooks.githubrepo.events }}
      - {{ . | quote }}
      {{ end }}
    remote_repo: {{ .Values.config.hooks.githubrepo.remoteRepo | quote }}
    privatekey: {{ .Values.config.hooks.githubrepo.privateKey | quote }}
    publickey: {{ .Values.config.hooks.githubrepo.publicKey | quote }}
  {{ end }}
  {{ if .Values.config.hooks.exec.enabled }}
  exec:
    type: {{ .Values.config.hooks.exec.type | quote }}
    events:
      {{ range .Values.config.hooks.exec.events }}
      - {{ . | quote }}
      {{ end }}
    cmd: {{ .Values.config.hooks.exec.cmd | quote }}
    timeout: {{ .Values.config.hooks.exec.timeout }}
    async: {{ .Values.config.hooks.exec.async }}
  {{ end }}
  {{ if .Values.config.hooks.slackdiff.enabled }}
  slackdiff:
    type: {{ .Values.config.hooks.slackdiff.type | quote }}
    events:
      {{ range .Values.config.hooks.slackdiff.events }}
      - {{ . | quote }}
      {{ end }}
    token: {{ .Values.config.hooks.slackdiff.token | quote }}
    channel: {{ .Values.config.hooks.slackdiff.channel | quote }}
  {{ end }}
  {{ if .Values.config.hooks.xmppdiff.enabled }}
  xmppdiff:
    type: {{ .Values.config.hooks.xmppdiff.type | quote }}
    events:
      {{ range .Values.config.hooks.xmppdiff.events }}
      - {{ . | quote }}
      {{ end }}
    jid: {{ .Values.config.hooks.xmppdiff.jid | quote }}
    password: {{ .Values.config.hooks.xmppdiff.password | quote }}
    channel: {{ .Values.config.hooks.xmppdiff.channel | quote }}
    nick: {{ .Values.config.hooks.xmppdiff.nick | quote }}
  {{ end }}
{{ else }}
hooks: {}
{{ end }}
source:
  default: {{ .Values.config.source.default | quote }}
  {{ if .Values.config.source.csv.enabled }}
  csv:
    file: {{ .Values.config.source.csv.file | quote }}
    {{- $delimiter := .Values.config.source.csv.delimiter }}
    {{- if regexMatch "^!ruby/regexp[[:space:]]+/.*?/[mix]*$" $delimiter }}
    delimiter: !ruby/regexp {{ regexReplaceAll "^!ruby/regexp[[:space:]]+" $delimiter "" | quote }}
    {{- else }}
    delimiter: {{ $delimiter | quote }}
    {{- end }}
    gpg: {{ .Values.config.source.csv.gpg }}
    {{ if .Values.config.source.csv.gpgPassword }}
    gpg_password: {{ .Values.config.source.csv.gpgPassword | quote }}
    {{ end }}
    map:
      {{ range $key, $value := .Values.config.source.csv.map }}
      {{ $key | quote }}: {{ $value }}
      {{ end }}
    {{ if .Values.config.source.csv.varsMap }}
    vars_map:
      {{ range $key, $value := .Values.config.source.csv.varsMap }}
      {{ $key | quote }}: {{ $value }}
      {{ end }}
    {{ end }}
  {{ end }}
  {{ if .Values.config.source.http.enabled }}
  http:
    url: {{ .Values.config.source.http.url | quote }}
    secure: {{ .Values.config.source.http.secure }}
    {{ if .Values.config.source.http.user }}
    user: {{ .Values.config.source.http.user | quote }}
    {{ end }}
    {{ if .Values.config.source.http.pass }}
    pass: {{ .Values.config.source.http.pass | quote }}
    {{ end }}
    read_timeout: {{ .Values.config.source.http.readTimeout }}
    pagination: {{ .Values.config.source.http.pagination }}
    {{ if .Values.config.source.http.pagination }}
    pagination_key_name: {{ .Values.config.source.http.paginationKeyName | quote }}
    {{ end }}
    {{ if .Values.config.source.http.hostsLocation }}
    hosts_location: {{ .Values.config.source.http.hostsLocation | quote }}
    {{ end }}
    map:
      {{ range $key, $value := .Values.config.source.http.map }}
      {{ if $value }}
      {{ $key | quote }}: {{ $value | quote }}
      {{ end }}
      {{ end }}
    headers: {{ .Values.config.source.http.headers | toJson }}
    {{ if .Values.config.source.http.varsMap }}
    vars_map:
      {{ range $key, $value := .Values.config.source.http.varsMap }}
      {{ $key | quote }}: {{ $value | quote }}
      {{ end }}
    {{ end }}
  {{ end }}
  {{ if .Values.config.source.sql.enabled }}
  sql:
    adapter: {{ .Values.config.source.sql.adapter | quote }}
    {{ if .Values.config.source.sql.host }}
    host: {{ .Values.config.source.sql.host | quote }}
    {{ end }}
    database: {{ .Values.config.source.sql.database | quote }}
    table: {{ .Values.config.source.sql.table | quote }}
    {{ if .Values.config.source.sql.user }}
    user: {{ .Values.config.source.sql.user | quote }}
    {{ end }}
    {{ if .Values.config.source.sql.password }}
    password: {{ .Values.config.source.sql.password | quote }}
    {{ end }}
    {{ if .Values.config.source.sql.query }}
    query: {{ .Values.config.source.sql.query | quote }}
    {{ end }}
    with_ssl: {{ .Values.config.source.sql.withSsl }}
    {{ if .Values.config.source.sql.sslMode }}
    ssl_mode: {{ .Values.config.source.sql.sslMode | quote }}
    {{ end }}
    {{ if .Values.config.source.sql.sslCa }}
    ssl_ca: {{ .Values.config.source.sql.sslCa | quote }}
    {{ end }}
    {{ if .Values.config.source.sql.sslCert }}
    ssl_cert: {{ .Values.config.source.sql.sslCert | quote }}
    {{ end }}
    {{ if .Values.config.source.sql.sslKey }}
    ssl_key: {{ .Values.config.source.sql.sslKey | quote }}
    {{ end }}
    map:
      {{ range $key, $value := .Values.config.source.sql.map }}
      {{ $key | quote }}: {{ $value | quote }}
      {{ end }}
    {{ if .Values.config.source.sql.varsMap }}
    vars_map:
      {{ range $key, $value := .Values.config.source.sql.varsMap }}
      {{ $key | quote }}: {{ $value | quote }}
      {{ end }}
    {{ end }}
  {{ end }}
  {{ if .Values.config.source.jsonfile.enabled }}
  jsonfile:
    file: {{ .Values.config.source.jsonfile.file | quote }}
    gpg: {{ .Values.config.source.jsonfile.gpg }}
    {{ if .Values.config.source.jsonfile.gpgPassword }}
    gpg_password: {{ .Values.config.source.jsonfile.gpgPassword | quote }}
    {{ end }}
    map:
      {{ range $key, $value := .Values.config.source.jsonfile.map }}
      {{ $key | quote }}: {{ $value | quote }}
      {{ end }}
    {{ if .Values.config.source.jsonfile.varsMap }}
    vars_map:
      {{ range $key, $value := .Values.config.source.jsonfile.varsMap }}
      {{ $key | quote }}: {{ $value | quote }}
      {{ end }}
    {{ end }}
  {{ end }}
{{ if .Values.config.modelMap }}
model_map:
  {{- range $key, $value := .Values.config.modelMap }}
  {{ if hasPrefix "!ruby/regexp " $key }}{{ $key }}{{ else }}{{ $key | quote }}{{ end }}: {{ $value | quote }}
  {{- end }}
{{ else }}
model_map: {}
{{ end }}
{{ if .Values.config.groups }}
groups:
  {{- range $group, $cfg := .Values.config.groups }}
  {{ $group | quote }}:
    {{- if $cfg.usernamePlaceholder }}
    username: {{ $cfg.usernamePlaceholder | quote }}
    {{- end }}
    {{- if $cfg.passwordPlaceholder }}
    password: {{ $cfg.passwordPlaceholder | quote }}
    {{- end }}
    {{- if $cfg.vars }}
    vars:
      {{- range $varKey, $varValue := $cfg.vars }}
      {{ $varKey | snakecase }}: {{ $varValue | toJson }}
      {{- end }}
    {{- end }}
    {{- if $cfg.models }}
    models:
      {{- range $model, $modelCfg := $cfg.models }}
      {{ $model | quote }}:
        {{- if $modelCfg.username }}
        username: {{ $modelCfg.username | quote }}
        {{- end }}
        {{- if $modelCfg.password }}
        password: {{ $modelCfg.password | quote }}
        {{- end }}
        {{- if $modelCfg.vars }}
        vars:
          {{- range $varKey, $varValue := $modelCfg.vars }}
          {{ $varKey | snakecase }}: {{ $varValue | toJson }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- range $key, $value := $cfg.extra }}
    {{ $key | snakecase }}: {{ $value | toJson }}
    {{- end }}
  {{- end }}
{{ else }}
groups: {}
{{ end }}
{{ if .Values.config.models }}
models:
  {{- range $model, $cfg := .Values.config.models }}
  {{ $model | quote }}:
    {{- if $cfg.username }}
    username: {{ $cfg.username | quote }}
    {{- end }}
    {{- if $cfg.password }}
    password: {{ $cfg.password | quote }}
    {{- end }}
    {{- if $cfg.vars }}
    vars:
      {{- range $varKey, $varValue := $cfg.vars }}
      {{ $varKey | snakecase }}: {{ $varValue | toJson }}
      {{- end }}
    {{- end }}
  {{- end }}
{{ else }}
models: {}
{{ end }}
{{- end -}}
