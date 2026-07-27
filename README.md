# fortigate_exporter Helm Charts

用于在 Kubernetes 中部署
[`prometheus-community/fortigate_exporter`](https://github.com/prometheus-community/fortigate_exporter)
的 Helm Chart 仓库。

仓库采用与 [bitnami/charts](https://github.com/bitnami/charts) 相同的分层思路：
仓库级 CI、许可证和构建入口位于根目录，每个 Chart 在 `charts/` 下保持独立。
本项目与 Bitnami、Fortinet 或 prometheus-community 没有关联。

## Charts

| Chart | Chart 版本 | 应用版本 | 说明 |
|---|---:|---:|---|
| [fortigate-exporter](fortigate-exporter/README.md) | `0.4.0` | `1.25.0` | Prometheus Operator、告警规则和 Grafana Dashboard |

## 命名约定

- 上游项目、应用及应用资产使用官方名称 `fortigate_exporter`；
- Helm Chart 源码目录、`Chart.yaml name`、helper 命名空间、release 及
  Kubernetes/Grafana API 资源名使用 `fortigate-exporter`；
- 上游实际发布的容器地址是
  `quay.io/prometheuscommunity/fortigate-exporter`，因此镜像路径保留连字符。

## 目录结构

```text
.
├── .github/workflows/ci.yaml
├── fortigate-exporter/
│   ├── Chart.yaml
│   ├── CHANGELOG.md
│   ├── README.md
│   ├── grafana/
│   ├── scripts/
│   ├── templates/
│   ├── values.schema.json
│   └── values.yaml
├── .gitignore
├── LICENSE
├── Makefile
└── README.md
```

## 验证

```bash
make validate
make package
```

`make validate` 检查 Dashboard、Helm schema、默认配置、带脱敏目标的模板渲染，
并确认重复目标、未知目标引用、保留标签覆盖和错误字段会被拒绝。
`make package` 将 Chart 打包到 `dist/`。

## 本地安装

先按 Chart 文档创建 FortiGate API 用户、外部 Secret 和本地
`values-targets.yaml`，再从仓库根目录执行：

```bash
helm upgrade --install fortigate-exporter fortigate-exporter \
  --namespace monitoring \
  --values values-targets.yaml \
  --rollback-on-failure \
  --wait \
  --timeout 10m
```

完整配置和安全说明见
[fortigate-exporter Chart 文档](fortigate-exporter/README.md)。

## License

本项目采用 [Apache License 2.0](LICENSE)。
