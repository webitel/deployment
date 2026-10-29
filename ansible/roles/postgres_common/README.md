# Role: postgres_common

Shared tasks for the `postgres` (standalone) and `patroni` (HA) roles:

- `tasks/install.yml` — PGDG and TimescaleDB repositories (GPG keys, `deb822_repository`) and installation of the base package list `postgres_common_base_packages`.
- `tasks/configure.yml` — bootstraps the Webitel DB: create app user, create database, fix permissions on the SQL directory, restore schema/data.

The role has no `tasks/main.yml` — it's invoked only via
`include_role: { name: postgres_common, tasks_from: install | configure }`.

## Interface (variables)

See `defaults/main.yml` for the variable interface (`login_host`/`login_user`/`login_password`: empty means peer auth, non-empty means TCP).

`pg_major` (15\|18) comes from the `topology` role.

## Usage

```yaml
# install (at the start of the consuming role)
- ansible.builtin.include_role:
    name: postgres_common
    tasks_from: install

# bootstrap (after the consuming role's configure)
- ansible.builtin.include_role:
    name: postgres_common
    tasks_from: configure
  vars:
    postgres_common_db: "{{ postgres_db }}"   # example for standalone
```
