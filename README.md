# Airsmon Helm Charts

[![Validate](https://github.com/airsmon/charts/actions/workflows/ci.yaml/badge.svg)](https://github.com/airsmon/charts/actions/workflows/ci.yaml)
[![License](https://img.shields.io/github/license/airsmon/charts)](LICENSE)

面向多个独立服务的 Kubernetes Helm Charts 聚合仓库。仓库根目录提供统一的
Chart 索引、工程约定、验证、打包和 CI；每个一级 Chart 目录都可以独立配置、
安装、升级和版本管理。

仓库入口借鉴 [Bitnami Charts](https://github.com/bitnami/charts) 的组织方式：
根 README 负责快速开始和通用规则，具体参数、依赖与安全边界由各 Chart 的
README 维护。本项目与 Bitnami 及各上游应用项目没有隶属或官方支持关系。

## TL;DR

### 前置条件

- Helm 4.2 或更高版本；个别 Chart 支持的更宽版本范围以其 README 为准；
- 可访问目标 Kubernetes 集群的 kubeconfig；
- 满足目标 Chart `Chart.yaml` 和 README 中声明的 Kubernetes 版本及依赖。

当前仓库提供源码安装，尚未声明公开的 Helm Repository 或 OCI Registry。
克隆仓库后，先阅读目标 Chart 文档并准备独立的 values 文件与外部 Secret：

```bash
git clone https://github.com/airsmon/charts.git
cd charts

helm lint ./chart-name --strict --values ./my-values.yaml
helm template my-release ./chart-name \
  --namespace my-namespace \
  --values ./my-values.yaml

helm upgrade --install my-release ./chart-name \
  --namespace my-namespace \
  --create-namespace \
  --values ./my-values.yaml \
  --rollback-on-failure \
  --wait \
  --timeout 10m
```

将 `chart-name`、`my-release`、`my-namespace` 和 values 文件替换为实际值。
不要直接把示例占位符用于生产部署。

## 可用 Charts

| Chart | 类别 | Chart 版本 | 应用版本 | 功能 |
|---|---|---:|---:|---|
| [fortigate-exporter](fortigate-exporter/README.md) | Monitoring | `0.4.0` | `1.25.0` | 部署 `fortigate_exporter`，并集成 Prometheus Operator、告警规则和 Grafana Dashboard |
| [oxidized](oxidized/README.md) | Infrastructure | `0.1.0` | `0.36.0` | 网络设备配置采集、Git 版本化与备份 |

Chart 的安装前提、values 参数、Secret 创建方式、升级说明和完整示例以各自
README 为准。

## 仓库组织

```text
.
├── .github/workflows/ci.yaml
├── <chart-name>/
│   ├── .helmignore
│   ├── Chart.yaml
│   ├── CHANGELOG.md
│   ├── README.md
│   ├── templates/
│   ├── values.schema.json
│   └── values.yaml
├── Makefile
├── LICENSE
└── README.md
```

Chart 可以按自身需求增加 `ci/`、`grafana/` 或 `scripts/` 等目录，但不得把
Chart 专属逻辑放入其他 Chart。根目录只维护跨 Chart 的入口和自动化。

## 统一约定

- 一个一级目录对应一个 Chart，目录名、`Chart.yaml.name` 和 helper
  命名空间统一使用 DNS-safe kebab-case；
- Chart 版本和应用版本分别维护在 `version` 与 `appVersion`，遵循各自的发布
  生命周期；
- Kubernetes 资源名由 Helm release 与 Chart 名生成，不硬编码 release 或
  namespace；
- selector 使用稳定的 `app.kubernetes.io/name` 和
  `app.kubernetes.io/instance`，需要区分角色时再加入
  `app.kubernetes.io/component`；
- values 通过 JSON Schema 约束，未知字段和越界值应在安装前被拒绝；
- 上游项目名、镜像地址、Prometheus job 和 Dashboard 资产保留其官方拼写。

## 验证与打包

从仓库根目录执行：

```bash
# 验证全部 Charts
make validate

# 验证单个 Chart
make validate-fortigate-exporter
make validate-oxidized

# 将全部 Charts 打包到 dist/
make package
```

`make validate` 是本仓库的统一质量门禁，包含 Chart lint、JSON Schema、
模板渲染、边界条件与 Chart 专属静态检查。CI 对 Pull Request 和 `main`
分支执行相同入口。

`dist/`、渲染后的清单和依赖缓存属于构建产物，不提交到源码仓库。

## 添加或维护 Chart

新增 Chart 时：

1. 在仓库根目录创建与 `Chart.yaml.name` 同名的 kebab-case 目录；
2. 提供 `Chart.yaml`、`values.yaml`、`values.schema.json`、`.helmignore`、
   `README.md` 和 `CHANGELOG.md`；
3. 在 `Makefile` 中接入独立的 lint、template、negative 和 package 目标，
   并确保 `make validate` 覆盖该 Chart；
4. 在上方 Chart 索引中登记版本、应用版本、类别和用途；
5. 提交前运行 `make validate` 与 `make package`，检查归档中不包含本地配置、
   凭据或临时文件。

变更应保持在目标 Chart 内；只有跨 Chart 的规则或自动化才应修改仓库根文件。

## 安全边界

- 生产凭据使用预先创建的 Kubernetes Secret，不写入 values、Git 历史或
  Chart 包；
- 提交前检查 Helm 渲染结果，确认 namespace、资源名、RBAC、网络策略和
  持久化配置符合目标环境；
- 不提交 kubeconfig、私钥、Token、日志、环境文件、生产 values 或 `.tgz`
  包；
- 上游镜像与应用的漏洞、安全公告和兼容性由对应上游项目负责，本仓库负责
  Chart 模板及默认配置的安全边界。

## License

本项目采用 [Apache License 2.0](LICENSE)。
