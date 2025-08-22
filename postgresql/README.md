# PostgreSQL v15

## Install

### PostgreSQL
```shell
sudo apt-get update -y
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo tee /etc/apt/sources.list.d/pgdg.list <<EOF
deb http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main
EOF

sudo apt-get update
apt-get install postgresql-15 webitel-postgresql-15

systemctl enable postgresql
systemctl restart postgresql
```

### TimescaleDB
```shell
sudo sh -c "echo 'deb https://packagecloud.io/timescale/timescaledb/debian/ `lsb_release -c -s` main' > /etc/apt/sources.list.d/timescaledb.list"
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
sudo apt-get update
sudo apt-get install timescaledb-2-postgresql-15

timescaledb-tune --quiet --yes

systemctl restart postgresql
```

## Configure

### Database daily script
```shell
su postgres
echo "4 4     * * *   psql webitel < /usr/share/postgresql/15/webitel/database_helper.sql" | crontab -
```

### Schema migrations
```shell
su postgres
createuser -P -s -e opensips
psql -c "CREATE DATABASE webitel OWNER opensips;"
psql webitel -f /usr/share/postgresql/15/webitel/webitel-db-schema.sql
psql webitel -f /usr/share/postgresql/15/webitel/webitel-db-data.sql
```

## Addons

### Streaming replication

- Create a replication user on primary (change `password` with your value):
    ```sql
    CREATE ROLE wbtrepl WITH REPLICATION PASSWORD 'password' LOGIN;
    ```
  
- Checkout to standby node and start streaming replication (where `127.0.0.1` - is your primary host).
    ```shell
    sudo -u postgres rm -r /var/lib/postgresql/15/main/*
    sudo -u postgres pg_basebackup -h 127.0.0.1 -p 5432 -U wbtrepl -D /var/lib/postgresql/15/main/ -Fp -Xs -R -P
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

- Enable restore mode: switch the database into restore mode to allow proper import of historical data.  
This is required step for `TimescaleDB hypertables`, but skip this step if you are not using TimescaleDB.
    ```shell
    sudo -u postgres psql webitel -qxc "ALTER DATABASE webitel SET timescaledb.restoring='on';"
    ```
  
- Perform the restore:
    ```shell
    sudo -u postgres pg_restore -d webitel ~/webitel-date.dir
    ```

- Disable restore mode: after successful import, revert the database configuration to normal mode.  
Skip this if you are not using `TimescaleDB hypertables`. 
    ```shell
    sudo -u postgres psql webitel -qxc "ALTER DATABASE webitel RESET timescaledb.restoring;"
    ```