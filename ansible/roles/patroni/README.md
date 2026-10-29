# Role: patroni

Deploys PostgreSQL under Patroni with Consul DCS. In HA inventories this role replaces the standalone `postgres` role. Patroni manages the PostgreSQL lifecycle; native `postgresql.service` is disabled.

Repos, base packages, and DB bootstrap come from the `postgres_common` role. DB parameters (`*_app_password`, `*_db`, `*_schema_files`) are set via `postgres_common_*` (see `roles/postgres_common/README.md`).

## Requirements

- Consul agent running on `127.0.0.1:8500` (role `consul` must run first).
- `community.postgresql` collection installed (`requirements.yml`).

## Variables

See `defaults/main.yml` for configurable variables.

`patroni_cluster_hosts`: under `_topology_db_scope: dc` the local datacenter's patroni hosts, under `global` (profile `stretch`) every patroni host across all datacenters.

`patroni_ttl` / `patroni_retry_timeout` are 60/20 under `global` scope, 30/10 otherwise. Keep `ttl` above `loop_wait + 2 * retry_timeout` if you override them.

`patroni_synchronous_mode` (default `false`) enables synchronous replication: no lost transactions on a cross-DC failover, one WAN round trip per commit.

`patroni_pg_parameters` (dict) adds or overrides PostgreSQL parameters on top of
`max_connections: 200` and `shared_preload_libraries: timescaledb`. They are applied when
the cluster is created; on a running cluster change them with `patronictl edit-config`.

## Vault variables (set in `vault.yml`)

```yaml
vault_patroni_superuser_password: "..."
vault_patroni_replication_password: "..."
vault_patroni_rewind_password: "..."
vault_patroni_restapi_password: "..."
```

## Tags

Tags: `patroni_install`, `patroni_configure` (see `tasks/main.yml`), `patroni_bootstrap` (creates the app user/db and grafana user/db — leader only).

## Notes

- PGDG and TimescaleDB apt repos plus base PostgreSQL packages are set up by the `postgres_common` role (included at install time).
- Native `postgresql.service` is disabled and Debian's default cluster is not created (`create_main_cluster = false`); Patroni bootstraps its own cluster in `/var/lib/postgresql/{{ patroni_major }}/main`.
- DB bootstrap (`bootstrap_db.yml`) runs only on the Patroni leader of the primary datacenter. Besides the webitel app DB it creates, when a `grafana` group exists, the grafana backend user/db and the SELECT-only datasource role `grafana_datasource_user`.
- Schema restore runs only when the webitel database has no tables.
- `pg_hba` allows every host outside the Patroni cluster as `webitel_pg_user`, and Grafana hosts as `grafana_db_user` (DB `grafana_db_name`) and `grafana_datasource_user` (DB `webitel_pg_db`).

## Verification

```bash
# Leader resolves via Consul DNS
dig @127.0.0.1 -p 8600 primary.{{ patroni_scope }}.service.consul

# Expect 1 Leader + N-1 Replica, Lag 0
patronictl -c /etc/patroni/config.yml list
```
