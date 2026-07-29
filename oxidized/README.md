# Oxidized Helm Chart

在 Kubernetes 中部署
[Oxidized](https://github.com/ytti/oxidized)，用于网络设备配置采集、版本化和备份。

这个 Chart 采用 Bitnami Chart 的核心约定：release 级资源名、稳定 selector、
标准 labels、`existing*` 外部资源、配置 checksum、严格 values schema，以及由
Helm 管理 namespace 的标准部署方式。Chart 保持自包含，不依赖 Bitnami
`common` library chart。

## 前置条件

- Kubernetes `1.23+`
- Helm `3.8+` 或 Helm `4`
- 一个支持所需访问模式的 StorageClass，或预先创建的 PVC

## 快速开始

Oxidized `0.36.0` 在 source 没有任何有效节点时会退出。Chart 因此不注入会被
误访问的虚构设备，而是要求在首次安装前配置至少一个真实节点或 HTTP/SQL
source。默认还会严格校验 SSH host key；先核对设备指纹，再创建只含
`known_hosts` 的外部 Secret：

```bash
kubectl create namespace oxidized
kubectl --namespace oxidized create secret generic oxidized-known-hosts \
  --from-file=known_hosts=./known_hosts
kubectl --namespace oxidized create secret generic oxidized-runtime \
  --from-literal=OXIDIZED_DEVICE_USERNAME=readonly \
  --from-literal=OXIDIZED_DEVICE_PASSWORD='replace-me'
```

请先把示例凭据替换为真实的只读设备账号；命令行 literal 可能进入 shell
history，生产环境应由 Secret 管理系统创建。最小的
`values-minimal.yaml`：

```yaml
runtimeSecret:
  enabled: true
  create: false
  existingSecret: oxidized-runtime

sshSecret:
  enabled: true
  create: false
  existingSecret: oxidized-known-hosts

config:
  source:
    csv:
      routerDb: |
        router-01.example.internal:ios
```

请将示例替换为真实设备，再从本仓库根目录执行：

```bash
helm upgrade --install oxidized ./oxidized \
  --namespace oxidized \
  --create-namespace \
  --values values-minimal.yaml \
  --atomic \
  --wait \
  --timeout 10m
```

使用有效 source 安装后，Chart 会：

- 创建单副本 `Deployment`，使用 `Recreate` 策略；
- 将 `config.source.csv.routerDb` 写入 `router.db`，并启动 Oxidized Web；
- 使用本地 Git output，但不启用远程 Git push hook；
- 创建 50 Gi、`ReadWriteOnce` 的 PVC；
- 为 PVC 设置 `helm.sh/resource-policy: keep`，卸载时保留备份；
- 不从 Helm values 创建凭据或 SSH Secret，也不创建 Ingress、NetworkPolicy
  或 PDB。

生产环境应使用环境专用 values 文件和外部 Secret/PVC。

## 标准命名

资源名由 Helm release 和 Chart 名生成：

| Release | 默认主资源名 |
|---|---|
| `oxidized` | `oxidized` |
| `production` | `production-oxidized` |

辅助资源使用稳定后缀，例如 `-config`、`-runtime`、`-ssh-keys` 和
`-data`。workload selector 使用稳定的 `app.kubernetes.io/name`、
`app.kubernetes.io/instance` 与 `app.kubernetes.io/component: server`，
不会随 Chart 版本或自定义 labels 改变，也不会误选 Helm test Pod。

可使用 `nameOverride` 或 `fullnameOverride` 覆盖名称。已存在的旧部署若必须
继续使用固定资源名，可以设置：

```yaml
fullnameOverride: oxidized
persistence:
  existingClaim: oxidized-data
```

namespace 默认始终来自 `helm --namespace`。`namespaceOverride` 仅用于少数
高级场景；它不会创建 namespace。不要通过 Chart 模板管理共享 Namespace。

## 推荐生产配置

先在目标 namespace 外部创建 Secret。Runtime Secret 默认 key 如下：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oxidized-runtime
  namespace: oxidized
type: Opaque
stringData:
  OXIDIZED_DEVICE_USERNAME: readonly
  OXIDIZED_DEVICE_PASSWORD: change-me
  NETBOX_API_TOKEN: change-me
  OXIDIZED_READONLY_DEVICE_USERNAME: readonly
  OXIDIZED_READONLY_DEVICE_PASSWORD: change-me
```

生产覆盖文件 `values-production.yaml`：

```yaml
runtimeSecret:
  enabled: true
  create: false
  existingSecret: oxidized-runtime

sshSecret:
  enabled: true
  create: false
  existingSecret: oxidized-known-hosts

persistence:
  existingClaim: oxidized-data

config:
  source:
    csv:
      routerDb: |
        router-01.example.internal:ios

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: production
  hosts:
    - host: oxidized.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: oxidized-tls
      hosts:
        - oxidized.example.com
```

部署：

```bash
helm upgrade --install oxidized ./oxidized \
  --namespace oxidized \
  --create-namespace \
  --values values-production.yaml \
  --atomic \
  --wait \
  --timeout 10m
```

真实凭据不应写入版本库或普通 Helm values。Helm 创建的 Secret 内容会进入
release history，因此生产环境推荐 `existingSecret`。

## Oxidized 配置

支持三种互斥/优先级明确的配置方式：

1. 默认字段化配置：通过 `config.*` 配置；
2. `config.configuration`：完整替换默认生成的配置，可使用 Helm `tpl`；
3. `config.existingConfigmap`：引用包含 `config` key 的外部 ConfigMap。

`config.existingConfigmap` 与 `config.configuration` 不能同时设置。
字段化 CSV source 必须设置非空的 `config.source.csv.routerDb`；Chart 会在每次
Pod 启动时将它复制到数据卷。使用外部 ConfigMap 的 CSV 配置时，应同时提供
`router.db` key。完整配置使用 CSV 时，也需要自行保证数据卷中存在有效节点。

字段化配置和完整配置可以使用以下占位符；内置 init container 会从
runtime Secret 读取值后，以 YAML 安全方式替换：

- `__OXIDIZED_DEVICE_USERNAME__`
- `__OXIDIZED_DEVICE_PASSWORD__`
- `__NETBOX_API_TOKEN__`
- `__OXIDIZED_READONLY_DEVICE_USERNAME__`
- `__OXIDIZED_READONLY_DEVICE_PASSWORD__`

其他配置凭据通过 `runtimeSecret.secretKeys.extra` 映射。映射键是注入 init
container 的环境变量名，值是外部 Secret 中的 key；在任意字符串配置字段中
使用 `__环境变量名__` 作为占位符。例如 Slack token：

```yaml
runtimeSecret:
  enabled: true
  create: false
  existingSecret: oxidized-runtime
  secretKeys:
    extra:
      OXIDIZED_SLACK_TOKEN: slack-token

config:
  hooks:
    slackdiff:
      enabled: true
      token: __OXIDIZED_SLACK_TOKEN__
      channel: network-backups
```

此时外部 `oxidized-runtime` Secret 必须包含 `slack-token`。环境变量名必须以
`OXIDIZED_` 开头，只能包含大写字母、数字和下划线；新增引用不是 optional，
key 缺失时 Pod 会在 init 阶段明确失败。相同机制可用于 XMPP、HTTP/SQL source、
GPG、HTTP output、group/model 密码等所有字符串字段。若仅用于开发测试且设置
`runtimeSecret.create: true`，可在 `runtimeSecret.data.extra` 中以环境变量名
提供值，但这些值会进入 Helm release history。

替换逻辑支持引号、`&`、`|`、反斜杠和多行值，不使用不安全的直接 `sed`
replacement。字段中的内联凭据只为兼容简单部署而保留；它们会进入 ConfigMap
和 Helm release history，生产环境必须使用外部 Secret 与占位符。若外部配置
完全不使用任何占位符，可以设置 `runtimeSecret.enabled: false`。

### NetBox HTTP source

如果不使用内嵌 `router.db`，可以切换到 NetBox 风格 HTTP source：

```yaml
config:
  source:
    default: http
    csv:
      enabled: false
    http:
      enabled: true
      url: https://netbox.example.com/api/dcim/devices/?status=active&tag=oxidized&limit=500
      secure: true
      hostsLocation: results
      headers:
        Authorization: Bearer __NETBOX_API_TOKEN__
      map:
        name: name
        ip: primary_ip.address
        model: platform.slug
        group: platform.slug
      varsMap: {}
```

启用 HTTP source 时 `config.source.http.url` 必须是完整的绝对 HTTP(S)
URL。`map` 除了 `name`、`ip`、`model`、`group`，也支持 Oxidized 的
`username`、`password` 等节点字段；建议按实际返回结构配置，并确保含凭据的
source 只通过受信任的 HTTPS 端点访问。

### 远程 Git push

`sshSecret` 可以只包含 `known_hosts`，用于密码认证设备的严格 host key
校验。远程 push 默认关闭；启用它时，外部 SSH Secret 必须同时包含
`id_rsa`、`id_rsa.pub` 和 `known_hosts`：

```yaml
sshSecret:
  enabled: true
  create: false
  existingSecret: oxidized-ssh-keys

config:
  hooks:
    githubrepo:
      enabled: true
      type: githubrepo
      events:
        - post_store
      remoteRepo: git@example.com:network/oxidized.git
      privateKey: /home/oxidized/.ssh/id_rsa
      publicKey: /home/oxidized/.ssh/id_rsa.pub
```

`known_hosts` 必须包含远端 Git 服务器 host key。只有确实需要兼容旧设备时，
才在
`config.vars.sshKex`、`sshEncryption` 和 `sshHmac` 中显式加入弱算法。
这些字段会按 Oxidized 的配置格式渲染到全局 `vars.ssh_*`，而
`config.input.ssh` 只渲染上游实际从该位置读取的 `secure`。

## Web、Service 和探针

`web.port` 是 Oxidized Web、容器端口、Service targetPort 和
NetworkPolicy ingress 的单一端口来源。`service.port` 是客户端访问的
Service 端口，可以不同。Kubernetes 内的 Web listener 固定使用
`0.0.0.0`，避免仅监听 loopback 导致 Service 和探针不可达。

设置 `web.vhosts` 时，默认 HTTP probes 与 Helm test 会使用列表中的第一个
host 作为 `Host` header，避免 Oxidized Web 的 host authorization 拒绝健康
检查。

上游镜像的自动 reload helper 固定访问容器内 `8888`。因此 Chart 仅在
`web.enabled: true`、`web.port: 8888`、没有 URL prefix，且 vhosts 允许
`localhost` 时传入 `CONFIG_RELOAD_INTERVAL`；其他组合会自动禁用该 helper。

设置 `web.enabled: false` 会一起关闭默认 HTTP probes、Service、Ingress、
NetworkPolicy ingress 和 Helm test。完整配置若使用 `url_prefix`，应同步修改
`startupProbe.path`、`readinessProbe.path`、`livenessProbe.path` 以及 Ingress
path。也可以通过 `customStartupProbe`、`customReadinessProbe` 和
`customLivenessProbe` 完全覆盖默认探针。

Oxidized Web 本身不应在没有认证和 TLS 防护时直接暴露到公网。

## 持久化

`persistence.enabled: true` 时，Chart 使用 PVC 保存配置、Git 仓库和
`router.db`。推荐生产环境使用 `persistence.existingClaim`。

Chart 创建的 PVC 默认设置：

```yaml
persistence:
  resourcePolicy: keep
```

因此 `helm uninstall` 不会删除 PVC。若明确希望 Helm 删除 PVC，可设置空值：

```yaml
persistence:
  resourcePolicy: ""
```

关闭持久化会改用 `emptyDir`，Pod 重建后备份数据会丢失。

## NetworkPolicy

NetworkPolicy 默认关闭，因为 Oxidized 需要主动访问网络设备、DNS、HTTP
source 和远程 Git。启用后请按真实网络范围收紧 egress：

```yaml
networkPolicy:
  enabled: true
  ingress:
    enabled: true
    fromAllNamespaces: false
    from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: ingress-nginx
  egress:
    enabled: true
    cidr: 10.0.0.0/8
    ports:
      - protocol: TCP
        port: 22
      - protocol: TCP
        port: 443
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
```

`networkPolicy.egress.ports` 至少要包含一项。Kubernetes 会把空的 `ports`
解释为匹配所有端口，因此 Chart 会在 schema 阶段拒绝空列表，避免限制规则
意外失效。

启用 Helm test 时，Chart 会额外允许同一 release 的
`app.kubernetes.io/component: test` Pod 访问 server。若要严格拒绝全部
ingress，请同时设置 `tests.enabled: false`；此时
`fromAllNamespaces: false` 与 `from: []` 会渲染 `ingress: []`。

## 安全上下文

ServiceAccount token 默认不会挂载。官方 0.36.0 镜像明确使用 UID/GID
`30000` 运行 Oxidized，因此 init container 也使用 `30000` 生成配置、SSH
文件和 `router.db`，并丢弃 Linux capabilities。主容器默认不强制 non-root，
因为上游入口需要先以 root 启动 runit，再由镜像内部切换用户；只有在验证自定义
镜像的 UID、入口和可写目录后，才应启用 `containerSecurityContext`。
字段化配置默认设置 `config.input.ssh.secure: true`；若未启用包含
`known_hosts` 的 `sshSecret`，Chart 会在模板阶段拒绝部署。CI 示例中的
`secure: false` 仅用于离线渲染测试，不是生产建议。

## 测试、升级和卸载

静态验证：

```bash
helm lint ./oxidized --strict \
  --set-string 'config.source.csv.routerDb=router.example.internal:ios' \
  --set config.input.ssh.secure=false \
  --set runtimeSecret.enabled=false
helm template oxidized ./oxidized --namespace oxidized \
  --set-string 'config.source.csv.routerDb=router.example.internal:ios' \
  --set config.input.ssh.secure=false \
  --set runtimeSecret.enabled=false >/dev/null
make validate-oxidized
```

集群连接测试：

```bash
helm test oxidized --namespace oxidized
```

升级继续使用 `helm upgrade --install`。卸载：

```bash
helm uninstall oxidized --namespace oxidized
```

默认 PVC 会保留；如不再需要，应确认备份后单独删除。

## 主要参数分组

| 分组 | 说明 |
|---|---|
| `global.*` | 全局镜像 registry、pull secrets 和 StorageClass |
| `image.*` | Oxidized 镜像 tag/digest/pull policy |
| `web.*`, `service.*`, `ingress.*` | Web、Service 和入口流量 |
| `config.*` | Oxidized 字段化或完整配置 |
| `runtimeSecret.*`, `sshSecret.*` | 凭据与 SSH key 的创建/引用策略 |
| `persistence.*` | PVC、StorageClass、容量和保留策略 |
| `startupProbe`, `readinessProbe`, `livenessProbe` | 默认 HTTP probes |
| `podSecurityContext`, `containerSecurityContext` | Pod/容器安全上下文 |
| `resources`, `nodeSelector`, `affinity`, `tolerations` | 资源和调度 |
| `networkPolicy.*`, `pdb.*` | 可选网络策略和 disruption budget |
| `extraEnvVars`, `extraVolumes`, `sidecars`, `initContainers` | 高级扩展 |
