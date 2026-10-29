# Role: topology

Derives variables from the inventory. It installs no packages and changes no host.

Two entry points:

- `tasks/main.yml` (default) — sets the facts: `single_node`, `ha_mode`,
  `nomad_managed`, `pg_major`, dependency addresses (`webitel_pg_host`,
  `webitel_amqp_host`, …), connection strings, `webitel_public_url`, `proxy_env`.
  Run by `playbooks/topology.yml`, which every domain playbook imports first.
- `tasks/validate.yml` — asserts the inventory matches its declared
  `topology_profile`. Runs on `localhost` without SSH. Run by
  `playbooks/validate_topology.yml`, which `preflight.yml` imports.

```yaml
- ansible.builtin.include_role:
    name: topology
    tasks_from: validate
```

## `vars/main.yml` — deployment profiles

`topology_profiles` defines each deployment profile: datacenter and host bounds, `db`
shape, `dcs_scope`. `tasks/validate.yml` checks against it; `tasks/main.yml` reads
`dcs_scope` from it into `_topology_db_scope`.

## `vars/services.yml` — the service catalog

`webitel_services` lists every service a host may put in `services`, with its systemd
units and, for app services, how Nomad runs them (`type: service` for one active
instance per datacenter, `type: system` for every host). `tasks/validate.yml` rejects
services missing from it; `webitel_service`, `webitel_storage_key` and `nomad` read
units and job settings from it.

## `defaults/main.yml` — the tunables

Cluster-wide service credentials, the service config source (`webitel_config_branch`,
`webitel_config_base_url`), PKI paths, log level and DSN tunables, and the service ports.
Override them in `group_vars/all/main.yml`; do not set the derived facts. For a
dependency deployed outside this playbook, set the matching `external_*` variable
(`external_pg_host`, `external_amqp_url`, `external_consul_host`, …).
