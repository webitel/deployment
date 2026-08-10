# PostgreSQL

Supported PostgreSQL major versions: **15** and **18**.

All commands below use the `PG_VERSION` variable, so export it once and paste the
snippets as they are:

```shell
export PG_VERSION=18   # or 15
```

## Install

### PostgreSQL
Add the PostgreSQL APT repository:
```shell
sudo apt-get update -y
sudo apt-get install -y gnupg postgresql-common apt-transport-https lsb-release wget
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
```

Install the packages:
```shell
sudo apt-get update
sudo apt-get install postgresql-${PG_VERSION} \
  webitel-postgresql-${PG_VERSION} \
  webitel-postgresql-migrations-${PG_VERSION}

systemctl enable postgresql
systemctl restart postgresql
```

- `webitel-postgresql-${PG_VERSION}` — the Webitel PostgreSQL extension.
- `webitel-postgresql-migrations-${PG_VERSION}` — the database schema, seed data
  and helper scripts (`/usr/share/postgresql/${PG_VERSION}/webitel/`). Required
  for the [Schema migrations](#schema-migrations) step below.

### TimescaleDB
```shell
echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg

sudo apt-get update
sudo apt-get install timescaledb-2-postgresql-${PG_VERSION}

timescaledb-tune --quiet --yes

systemctl restart postgresql
```

## Configure

### Database daily script
```shell
echo "4 4     * * *   psql webitel < /usr/share/postgresql/${PG_VERSION}/webitel/database_helper.sql" | sudo -u postgres crontab -
```

### Schema migrations

Provided by the `webitel-postgresql-migrations-${PG_VERSION}` package.

```shell
sudo -u postgres createuser -P -s -e opensips
sudo -u postgres psql -c "CREATE DATABASE webitel OWNER opensips;"
sudo -u postgres psql webitel -f /usr/share/postgresql/${PG_VERSION}/webitel/webitel-db-schema.sql
sudo -u postgres psql webitel -f /usr/share/postgresql/${PG_VERSION}/webitel/webitel-db-data.sql
```

## Addons

### Streaming replication

- Create a replication user on primary (change `password` with your value):
    ```sql
    CREATE ROLE wbtrepl WITH REPLICATION PASSWORD 'password' LOGIN;
    ```
  
- Checkout to standby node and start streaming replication (where `127.0.0.1` - is your primary host).
    ```shell
    sudo -u postgres rm -r /var/lib/postgresql/${PG_VERSION}/main/*
    sudo -u postgres pg_basebackup -h 127.0.0.1 -p 5432 -U wbtrepl -D /var/lib/postgresql/${PG_VERSION}/main/ -Fp -Xs -R -P
    ```

- Configure DSN in Webitel services configuration:
    ```
    -sql_data_source_replicas='postgres://opensips:webitel@10.10.10.222:5432/webitel?fallback_application_name=engine&sslmode=disable&connect_timeout=10&search_path=call_center'
    ```

### Backup data (using `pg_dump`)

```shell
sudo -u postgres pg_dump -Fd webitel -j 4 -f ~/webitel-$(date +\%Y\%m\%d\%H\%M).dir
```

### Restore

- Create an empty database:
    ```shell
    sudo -u postgres psql -c "CREATE DATABASE webitel OWNER opensips;"
    ```

- Create the TimescaleDB extension, so the restore helper functions become
available. Skip this and the two steps below if you are not using TimescaleDB.
    ```shell
    sudo -u postgres psql webitel -qxc "CREATE EXTENSION IF NOT EXISTS timescaledb;"
    ```

- Enable restore mode: `timescaledb_pre_restore()` sets `timescaledb.restoring='on'`
and stops the TimescaleDB background workers, so historical data is imported into
`hypertables` as-is.
    ```shell
    sudo -u postgres psql webitel -qxc "SELECT timescaledb_pre_restore();"
    ```

- Perform the restore. Do **not** add `-j` — parallel restore is not supported for
TimescaleDB and may fail.
    ```shell
    sudo -u postgres pg_restore -d webitel ~/webitel-date.dir
    ```

- Disable restore mode: `timescaledb_post_restore()` reverts the setting and
restarts the background workers. The database is not usable normally until this
runs.
    ```shell
    sudo -u postgres psql webitel -qxc "SELECT timescaledb_post_restore();"
    ```