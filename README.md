# Network Operations Helm Charts

用于在 Kubernetes 中部署网络运维与配置备份工具的 Helm Chart 仓库。

仓库采用与 [bitnami/charts](https://github.com/bitnami/charts) 相同的分层思路：
仓库级 CI、许可证和构建入口位于根目录；每个 Chart 是根目录下相互独立的
同级目录。本项目与 Bitnami、Fortinet、Oxidized 或
prometheus-community 没有关联。

## Charts

| Chart | Chart 版本 | 应用版本 | 说明 |
|---|---:|---:|---|
| [fortigate-exporter](fortigate-exporter/README.md) | `0.4.0` | `1.25.0` | Prometheus Operator、告警规则和 Grafana Dashboard |
| [oxidized](oxidized/README.md) | `0.1.0` | `0.36.0` | 网络设备配置采集、Git 版本化和备份 |

## 命名约定

- Chart 目录、`Chart.yaml name` 和 helper 命名空间统一使用 DNS-safe
  kebab-case；
- Kubernetes 主资源名由 Helm release 与 Chart 名生成，不硬编码 release 或
  namespace；
- selector 只使用稳定的 `app.kubernetes.io/name`、
  `app.kubernetes.io/instance`，需要区分工作负载角色时再加入
  `app.kubernetes.io/component`；
- 上游项目名、Prometheus job、Dashboard 资产和容器地址保留各自官方拼写。

例如 `fortigate_exporter` 是上游应用名，而 Chart 和镜像路径使用
`fortigate-exporter`。Oxidized 的 Chart、应用和镜像名统一为 `oxidized`。

## 目录结构

```text
.
├── .github/workflows/ci.yaml
├── fortigate-exporter/
│   ├── .helmignore
│   ├── Chart.yaml
│   ├── CHANGELOG.md
│   ├── README.md
│   ├── grafana/
│   ├── scripts/
│   ├── templates/
│   ├── values.schema.json
│   └── values.yaml
├── oxidized/
│   ├── .helmignore
│   ├── Chart.yaml
│   ├── CHANGELOG.md
│   ├── README.md
│   ├── templates/
│   ├── values.schema.json
│   └── values.yaml
├── .gitignore
├── LICENSE
├── Makefile
└── README.md
```

Chart 源码不提交渲染后的 YAML、依赖缓存或 `.tgz` 包。`make package` 的输出
统一进入 `dist/`。

## 验证

```bash
make validate
make validate-fortigate-exporter
make validate-oxidized
make package
```

`make validate` 会验证两个 Chart 的 schema、基础与生产组合渲染和负向配置。
FortiGate Dashboard 静态检查仅属于 `fortigate-exporter`，不会错误套用到其他
Chart。

## 本地安装

FortiGate Exporter：

```bash
helm upgrade --install fortigate-exporter ./fortigate-exporter \
  --namespace monitoring \
  --values values-targets.yaml \
  --atomic \
  --wait \
  --timeout 10m
```

Oxidized：

```bash
helm upgrade --install oxidized ./oxidized \
  --namespace oxidized \
  --create-namespace \
  --values values-production.yaml \
  --atomic \
  --wait \
  --timeout 10m
```

生产凭据应使用外部 Secret，不应提交到仓库。完整配置、安全边界和升级说明见各
Chart 的 README。

## License

本项目采用 [Apache License 2.0](LICENSE)。
