# Superset + ClickHouse

Apache Superset served at `https://<global.domain>/analytics`, charting data held
in the single-node ClickHouse that the sibling `clickhouse` chart deploys.

Both charts are picked up automatically by the backbone ApplicationSet
(`config-as-code/helm/charts/argo-cd/backbone/backbone-app-set-backbone.yaml`),
which turns every directory under `backbone-used-charts/` into an ArgoCD
application — here `backbone-superset` and `backbone-clickhouse`. No extra
ArgoCD manifest is needed.

## Topology

| Component | Where |
|---|---|
| Superset web (+ nginx sidecar) | `superset-web`, namespace `backbone` |
| Celery worker / beat | `superset-worker`, `superset-beat` |
| Metadata DB | `superset` database on the environment's Azure PostgreSQL server |
| Celery broker + cache | shared `redis.backbone`, DBs 2 and 3 |
| Analytical store | `clickhouse.backbone.svc.cluster.local:8123`, database `analytics` |

The stock `apache/superset` image ships neither the PostgreSQL nor the
ClickHouse driver. An init container `pip install`s both into a shared
`emptyDir` that is prepended to `PYTHONPATH`, so the image stays unmodified —
this requires the cluster to reach PyPI.

## Prerequisites

1. **Create the metadata database and role** on the Azure PostgreSQL server
   (`afrohcm-t-euw-server`), as the `whoadmin` admin. The server has public
   access disabled, so run this from a pod inside the cluster.

   ```sql
   CREATE ROLE superset LOGIN PASSWORD '<db-password>';
   GRANT superset TO whoadmin;          -- needed to hand over ownership
   CREATE DATABASE superset OWNER superset;
   ```

   Then, connected to the new `superset` database:

   ```sql
   ALTER SCHEMA public OWNER TO superset;
   GRANT ALL ON SCHEMA public TO superset;
   ```

   The second step is not optional. On PostgreSQL 15 the `public` schema comes
   from Azure's template owned by `azure_pg_admin` and no longer grants CREATE
   to PUBLIC, so `superset db upgrade` fails with
   `permission denied for schema public` without it.

2. **Add the secrets** to `config-as-code/environments/who-afro-hcm-secrets.yaml`
   (SOPS, Azure Key Vault — run `az login` first):

   ```yaml
   cluster-configs:
     secrets:
       superset:
         db-password: <matches the role above>
         secret-key: <openssl rand -base64 42>
         admin-password: <Superset admin UI password>
         clickhouse-password: <must equal clickhouse.superset-password>
       clickhouse:
         admin-password: <ClickHouse default user>
         superset-password: <ClickHouse read-only BI user>
   ```

   Keep passwords alphanumeric: they are interpolated into SQLAlchemy URIs.

3. Sync `who-afro-cluster-configs` first so the `superset` and `clickhouse`
   secrets exist in the `backbone` namespace, then sync the two backbone apps.

## Users and access

- Superset UI: `admin` / `ADMIN_PASSWORD`, created by the `superset-init-db`
  PreSync hook (idempotent, re-runs on every sync).
- The ClickHouse connection is pre-registered in Superset under the name
  `ClickHouse`, using a read-only ClickHouse user (`readonly=2`: SELECT plus
  per-query settings, no INSERT or DDL). Load data with the `default` user.
