# PowerDNS-Admin Helm Chart

This Chart deploys [PowerDNS-Admin](https://github.com/PowerDNS-Admin/PowerDNS-Admin)
`0.6.1` as one hardened Kubernetes Deployment. It can also deploy one
application-dedicated PostgreSQL StatefulSet or connect the application to an
external PostgreSQL database.

The Chart templates follow this repository's Apache-2.0 license; the upstream
PowerDNS-Admin application is distributed under MIT.

The Chart does **not** deploy PowerDNS Authoritative. PowerDNS-Admin reaches an
environment-specific PowerDNS HTTP API supplied through an existing Secret.
Upstream `0.6.1` supports PowerDNS Authoritative `5.0` and `5.1`.

## Architecture and scope

```text
trusted browser
      |
optional Istio Gateway + cert-manager TLS
      |
PowerDNS-Admin Deployment (1 Pod, Gunicorn on 8080)
      |                         |
dedicated or external PG       PowerDNS HTTP API
                               (environment-specific)
```

PowerDNS-Admin stores its accounts, settings, audit history and SQLAlchemy
sessions in PostgreSQL. The web Pod is stateless and has no PVC. A bundled
database belongs only to PowerDNS-Admin; never share the PowerDNS
Authoritative backend database with this application.

The Chart uses a Deployment instead of Knative because schema migrations must
be serialized and this privileged DNS administration surface benefits from
predictable availability. Scale-to-zero would repeat migration checks on cold
starts and can introduce concurrent schema migration attempts.

## Prerequisites

- Kubernetes `1.27` or newer;
- Helm `4.2` or newer for this repository's validation workflow;
- a separate PowerDNS Authoritative `5.0` or `5.1` endpoint and API key;
- the two existing Secrets described below;
- a default StorageClass or an explicit StorageClass when bundled PostgreSQL
  is enabled;
- an enforcing NetworkPolicy implementation if NetworkPolicy is enabled;
- Istio and cert-manager CRDs only when the optional route is enabled.

Enabling a chart-created route also requires permission to manage a `Gateway`
in `route.gateway.resourceNamespace` and a `Certificate` in
`route.tls.certificate.namespace` (`istio-system` by default).

## Immutable images

The defaults render both the readable tag and immutable multi-platform index
digest:

```text
docker.io/powerdnsadmin/pda-legacy:v0.6.1@sha256:5741b1f877210878f02923dd45346c7016acefc7eac9b14e90229f94e4c726c4
docker.io/library/postgres:17.10-alpine3.22@sha256:b02d9b5bcf608c2719da32cdabee274a33841202487fd5dc9b065b63f886753f
```

Do not remove the digests in production. Updating an application or database
image requires reviewing both its tag and digest.

## Existing Secret contract

This Chart has no Secret template and never writes credentials into a rendered
manifest or package. Create the following Secrets in the release namespace
through the approved secret-management workflow before installation.

### Runtime Secret

Default name: `powerdns-admin-runtime`.

| Key | Purpose |
|---|---|
| `secret-key` | Long, random, stable Flask signing key |
| `pdns-api-url` | PowerDNS API base URL ending in `/api/v1` |
| `pdns-api-key` | API key for the same environment |

### Database Secret

Default name: `powerdns-admin-database`.

| Key | Bundled PostgreSQL | External PostgreSQL |
|---|---:|---:|
| `username` | required | unused by the Chart |
| `password` | required | unused by the Chart |
| `database` | required | unused by the Chart |
| `sqlalchemy-database-uri` | required | required |

For bundled PostgreSQL, the URI must describe the same username, password and
database and use this chart-generated hostname:

For the recommended release name `powerdns-admin`, the hostname is:

```text
powerdns-admin-postgresql.<namespace>.svc.cluster.local:5432
```

Other release names change the generated fullname. Confirm the exact Service
name with `helm template` before creating the URI.

Percent-encode credentials in the URI where required. Secret file values must
not have trailing newlines because upstream consumes the full file contents.
Never copy production PowerDNS credentials into UAT; the application performs
writes.

## Database modes

### Bundled PostgreSQL (default)

```yaml
postgresql:
  enabled: true
  persistence:
    storageClass: example-storage
    size: 10Gi
```

The Chart renders one headless Service and one-replica PostgreSQL StatefulSet.
Its `data` volume claim template uses `ReadWriteOnce`. The StatefulSet declares
`Retain` for scale-down and deletion so a controller deletion does not request
PVC deletion. Retention is not a backup: production requires an encrypted,
off-node `pg_dump` destination and a tested restore procedure.

### External PostgreSQL

```yaml
postgresql:
  enabled: false

database:
  existingSecret: powerdns-admin-external-database
```

This mode renders no PostgreSQL Service, StatefulSet or volume claim template.
The named Secret must provide `sqlalchemy-database-uri`. Manage availability,
backup, restore, upgrades and TLS for the external database outside this Chart.

## Migration modes

| Mode | Intended workflow | Behavior |
|---|---|---|
| `entrypoint` | Direct/public Helm use (default) | No Job is rendered. With bundled PostgreSQL, a bounded `pg_isready` init container waits for the database. The upstream entrypoint then runs `flask db upgrade` and starts Gunicorn on port `8080`. `replicaCount` is fixed at `1`. |
| `argocdHook` | Argo CD GitOps | PostgreSQL is wave `-20`, a single migration Sync hook is wave `-10`, and the web Deployment starts Gunicorn directly at wave `0`. |

The Argo hook is deleted after success and recreated before a later sync. Do
not use direct Gunicorn startup without the migration Job, and do not add a
second application-side migration mechanism.

## First Administrator bootstrap

An empty application database has no account. Upstream grants the first user
registered through `/register` the Administrator role. The bootstrap defaults
enable sign-up while disabling the external Istio route and NetworkPolicy;
`siteUrl` is `http://127.0.0.1:8080`.

This is **not** a localhost-only network boundary. The ClusterIP Service can
still be reached by in-cluster workloads unless the platform supplies tested
equivalent isolation. Perform bootstrap in a controlled maintenance window,
confirm that no untrusted workload can reach the Service, and keep the window
open only until the first Administrator is verified and sign-up is disabled.

After the workload is ready, expose it only on the operator workstation:

```bash
kubectl --namespace powerdns-admin port-forward \
  --address 127.0.0.1 service/powerdns-admin 8080:8080
```

Open `http://127.0.0.1:8080/register`, create the first Administrator, confirm
that the account can sign in, and stop the port-forward. Do not store that
password in values, Git, a Helm command line or a bootstrap Secret.

Then switch to a steady-state environment values file in one controlled
change:

```yaml
config:
  csrfCookieSecure: true
  hstsEnabled: true
  serverExternalSsl: true
  sessionCookieSecure: true
  signupEnabled: false
  siteUrl: https://powerdns-admin.example.internal

route:
  enabled: true
  host: powerdns-admin.example.internal
```

The Chart rejects any render that enables a route while public sign-up remains
enabled. Verify `/register` is unavailable after the steady deployment. A
restored or external database that already has an Administrator skips this
bootstrap and starts directly with `signupEnabled=false`.

## Install with Helm

Prepare a non-secret values file, then render and inspect it:

```bash
helm lint ./powerdns-admin --strict --values ./my-values.yaml
helm template powerdns-admin ./powerdns-admin \
  --namespace powerdns-admin \
  --values ./my-values.yaml
```

Install only after the two existing Secrets and the database backup plan are
ready:

```bash
helm upgrade --install powerdns-admin ./powerdns-admin \
  --namespace powerdns-admin \
  --create-namespace \
  --values ./my-values.yaml \
  --rollback-on-failure \
  --wait \
  --timeout 10m
```

`migration.mode=entrypoint` is the supported direct Helm path.

## Argo CD profile

Use `migration.mode=argocdHook`. The repository includes reviewed UAT and
production profiles under `ci/` as non-secret render fixtures. Copy the needed
settings into the application repository rather than referencing this Git
checkout path from another repository.

```yaml
migration:
  mode: argocdHook

config:
  csrfCookieSecure: true
  hstsEnabled: true
  serverExternalSsl: true
  sessionCookieSecure: true
  signupEnabled: false
  siteUrl: https://powerdns-admin.uat.example.internal
```

## Optional route

Istio and cert-manager resources are off by default. This example creates one
`Certificate`, `Gateway` and `VirtualService`:

```yaml
config:
  csrfCookieSecure: true
  hstsEnabled: true
  serverExternalSsl: true
  sessionCookieSecure: true
  signupEnabled: false
  siteUrl: https://powerdns-admin.uat.example.internal

route:
  enabled: true
  host: powerdns-admin.uat.example.internal
  gateway:
    create: true
    resourceNamespace: istio-system
    workloadNamespace: istio-system
    selector:
      istio: gateway
  tls:
    enabled: true
    certificate:
      create: true
      namespace: istio-system
      issuerRef:
        kind: ClusterIssuer
        name: dnspod
```

`config.siteUrl` must exactly match the enabled route's scheme and host. Keep
the hostname on trusted internal DNS or behind an approved identity-aware
access layer; upstream advises against public Internet exposure.

The Gateway CR is created in `route.gateway.resourceNamespace`. Its selector
targets Pods in `route.gateway.workloadNamespace`. A chart-created Certificate
must use that same workload namespace so Istio can resolve the
`credentialName` Secret. The VirtualService remains in the Helm release
namespace and references the Gateway as `<resourceNamespace>/<name>`.

To reuse a separately managed Gateway and its existing certificate Secret,
set `route.gateway.create=false`, provide `route.gateway.name`, and set
`route.tls.certificate.create=false`. This renders only the VirtualService.
For a chart-created `Issuer` rather than a `ClusterIssuer`, the Issuer must
exist in `route.tls.certificate.namespace`.

## Optional NetworkPolicy

NetworkPolicy is disabled by default because Kubernetes accepts policy objects
even when the installed CNI does not enforce them. When enabled, the Chart
restricts PostgreSQL ingress to Pods from the same PowerDNS-Admin release and
restricts web ingress to the explicitly configured peers. With an empty
`networkPolicy.web.from` list and `fromAllNamespaces=false`, web ingress is
denied.

For the included Istio profile:

```yaml
networkPolicy:
  enabled: true
  web:
    from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: istio-system
```

This declaration provides isolation only after a policy enforcement test has
passed on the target cluster.

## Single-node and security defaults

- one web replica and one optional database replica;
- web Deployment strategy `Recreate`; no PodDisruptionBudget;
- no service-account token and no Kubernetes API permissions;
- numeric non-root UID/GID, runtime-default seccomp, all capabilities dropped,
  no privilege escalation and read-only root filesystems;
- writable data is limited to the PostgreSQL PVC and bounded `emptyDir`
  runtime paths;
- bootstrap defaults enable sign-up only while all external routing is off;
  the ClusterIP remains internally reachable and requires a trusted cluster or
  equivalent bootstrap isolation;
- steady-state UAT/production profiles disable sign-up and enable secure
  cookies, HTTPS awareness and HSTS.

The PostgreSQL StatefulSet uses `RollingUpdate`, the only safe automatic
StatefulSet update strategy for this one-replica design. The application
Deployment uses `Recreate` so a single-node upgrade never runs two web Pods.

## Validate

From the repository root:

```bash
make validate-powerdns-admin
make package-powerdns-admin
```

Validation covers bootstrap and steady-state profiles, the default Helm
workflow, bundled and external databases, the Argo migration path, created and
referenced Istio Gateways, TLS namespace alignment, optional policies,
schema-negative cases, immutable image references, absence of Secret objects
and package fixture exclusion.

## Upgrade and rollback

Take and verify a logical database backup before changing the application or
database image. Review upstream schema migrations, render the new Chart, run
the migration against an isolated restored database, and then deploy one
environment at a time. A Helm or Git rollback cannot reverse a database schema
migration; restore the verified backup when an upstream migration is not
backward compatible.
