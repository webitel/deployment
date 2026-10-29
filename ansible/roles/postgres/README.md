# postgres

Standalone PostgreSQL for Webitel: installs the PGDG and TimescaleDB repositories, PostgreSQL packages, and Webitel extensions, then configures parameters and initializes the database.

Supported combinations: Debian 12 / PostgreSQL 15, Debian 13 / PostgreSQL 18. The version is `pg_major`, set by the `topology` role; override it with `pg_major` in `group_vars`.

Base packages and database bootstrap come from the `postgres_common` role (repositories, packages, create user/db, restore schema). User/password/schema configuration is done via `postgres_common_*` variables (see `roles/postgres_common/README.md`).

When the inventory has a `grafana` host, the role also creates the Grafana backend DB
(`grafana_db_name`, owner `grafana_db_user`) and the SELECT-only datasource user
`grafana_datasource_user`.

`pg_hba.conf` allows `webitel_pg_user` from every inventory host, and the Grafana users from
`grafana` hosts (`grafana_db_user` to `grafana_db_name`, `grafana_datasource_user` to `webitel_pg_db`).

See `defaults/main.yml` for configurable variables.
