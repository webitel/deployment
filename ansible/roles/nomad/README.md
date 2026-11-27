# nomad

Installs and configures HashiCorp Nomad (server + client mode) with the Webitel systemd task driver on clients.

## Requirements

- Ansible-core >= 2.16
- Debian target (HashiCorp apt repository)
- `pki` role run before this role when TLS is enabled (`consul_pki_enabled: true`)

## Role variables

See `defaults/main.yml` for configurable variables.

## Tags

Tags: `nomad_install`, `nomad_configure` — see `tasks/main.yml`.

## Job submission (`tasks_from: jobs`)

`playbooks/nomad_jobs.yml` runs `tasks/jobs.yml` on the first Nomad server of each
datacenter. For every service in the catalog (`roles/topology/vars/services.yml`) with a
`nomad` entry that runs on one of the datacenter's clients, it renders
`templates/job.nomad.hcl.j2`, plans it and registers it when the plan shows a difference.

- `type: service` jobs run one instance per datacenter and reschedule to another node
  of the same service on failure; `type: system` jobs run on every node of the service.
- Every job carries `meta.dcctl_stage`, the order in which `webitel-dcctl` starts (ascending)
  and stops (descending) jobs: 1 voice media (freeswitch, rtpengine), 2 application services,
  3 perimeter (opensips, `webitel-core-api`, `nginx-vip`). The stage is `nomad.stage` of the
  catalog entry, else `nomad_jobs_stages`; it must be an integer >= 1.
- `webitel-api` runs as the job `webitel-core-api` on the `webitel_core` hosts, apart from
  `webitel-app` and `webitel-uac` (`webitel-core`). `nginx_vip` runs as the singleton job
  `nginx-vip`. Both come from `nomad_jobs_extra`; a catalog entry with a `nomad` key of the
  same name replaces it.
- Only the active datacenter (`active_datacenter`, else `primary_datacenter`, else the only
  datacenter) gets running jobs. In any other datacenter a job is registered stopped
  (`Stop=true`) when it does not exist, and keeps its current `Stop` when it does, so a
  repeated run does not start what `webitel-dcctl` stopped. That registration is guarded by the
  job's modify index. With several datacenters and neither variable set, no datacenter is active
  and new jobs are registered stopped everywhere.
- A client disconnected from the servers stops its `service` units after
  `nomad_jobs_stop_on_client_after` (30s).
- Drain a node only for maintenance, before stopping its agent: `nomad node drain -enable <node>`.
  Jobs of inactive datacenters are stopped by `webitel-dcctl`, not by draining.
- A changed `nomad_jobs_stop_on_client_after` applies to new allocations only; to apply
  it to running ones, run `nomad job restart -reschedule <job>`.
- Nodes are selected with `${meta.services} set_contains <service>`.
- `nomad_jobs_node_constraints` (`{<service>: [<node name>, ...]}`) pins a `service` job to the
  listed nodes. It is refused for `system` jobs: their nodes are known by `meta.services` only.
- A job that cannot be placed (nodes drained or down) is registered with a warning when it is
  not stopped; it starts when the nodes become eligible.
- Jobs for services removed from the inventory are not stopped; stop them by hand
  (`meta.managed_by = "wansible"` marks ours).

## Notes

- Clients get the `nomad-driver-systemd` package from the Webitel repo's `main` component (see `base_repo_extra_components` in the `base` role). Jobs reference it as `driver = "systemd"`.
- The `plugin "nomad-driver-systemd"` block in `nomad.hcl.j2` is rendered only for clients. It limits the driver to `nomad_systemd_driver_allowed_units`: every unit of a catalog service with a `nomad` entry.
- Every client advertises `meta.services` = the host's `services`, comma-separated.
- TLS is enabled when `consul_pki_enabled` is true. It defaults to true when the inventory has `patroni`. The `pki` role (`playbooks/pki.yml`) runs before this role in `site.yml`.
- Under `stretch`, Nomad registers in Consul as `nomad-<datacenter>` (servers) and `nomad-client-<datacenter>` (clients). Other profiles use the Nomad defaults `nomad` and `nomad-client`.

## Verification

With TLS enabled, set `NOMAD_ADDR=https://127.0.0.1:4646 NOMAD_CACERT=/etc/ssl/app/ca.pem` first.

```bash
nomad server members          # expect server nodes alive
nomad node status             # expect client nodes ready
nomad node status -self -verbose | grep driver.systemd   # on a client: detected + healthy
```
