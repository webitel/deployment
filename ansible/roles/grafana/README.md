# grafana

Installs Grafana OSS, provisions the PostgreSQL data sources, and optionally imports a set of pre-built Webitel analytics dashboards.

Data sources query the webitel DB at `webitel_pg_host` as the SELECT-only `grafana_datasource_user`:

- **PostgreSQL Primary** — `webitel_pg_host`:`webitel_pg_port`, default.
- **PostgreSQL Replica** — the HAProxy RO port (`haproxy_pg_ro_port`), rendered only when HAProxy is present.

The Grafana backend DB (`[database]` in `grafana.ini`) is `grafana_db_name` at
`webitel_pg_host`:`webitel_pg_port`, as `grafana_db_user`. The backend DB and both users
are created by:

- `roles/postgres` (standalone PostgreSQL), in `tasks/database.yml`;
- `roles/patroni` (Patroni cluster), in `tasks/bootstrap_db.yml` on the leader of the primary datacenter.

See `defaults/main.yml` for configurable variables.

## Admin credentials

`grafana_admin_user` / `grafana_admin_password` are written to the `[security]` section
of `grafana.ini` and apply only when Grafana first creates the admin user. To change the
password on an existing instance, run on the host:

```bash
grafana-cli admin reset-admin-password "<new-password>"
```
