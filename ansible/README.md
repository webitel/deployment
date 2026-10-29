<div align="center">
  <h2>
    Webitel 26.6
  </h2>

  <a href="https://github.com/webitel/deployment/actions/workflows/ansible.yml?query=branch%3Amain">
    <img alt="ansible" src="https://github.com/webitel/deployment/actions/workflows/ansible.yml/badge.svg?branch=main">
  </a>
</div>

<!-- TOC -->
  * [Requirements](#requirements)
  * [Quickstart](#quickstart)
  * [Required variables](#required-variables)
  * [Deployment profiles](#deployment-profiles)
  * [Inventory model](#inventory-model)
  * [Secrets and vault](#secrets-and-vault)
  * [Service configs](#service-configs)
  * [Network access](#network-access)
  * [After the run](#after-the-run)
  * [Verification commands](#verification-commands)
  * [Tags](#tags)
<!-- TOC -->

## Requirements

- **Ansible controller:**
  - ansible-core >= 2.16
  - collections from `requirements.yml`
  - Python `cryptography` package
  - `sshpass` when hosts are reached with an SSH password
- **Target OS:** Debian 12 (bookworm) or Debian 13 (trixie), amd64 or arm64
  - Hosts running `postgres`, `patroni` or `freeswitch` **must** be amd64
- **Access:** SSH key or password, sudo/become rights on target hosts
- **Credentials:** Webitel S3 APT repository keys (access + secret), SignalWire Personal Access Token for FreeSWITCH
- **Internet access:** direct, or through an HTTP proxy — set `http_proxy` / `https_proxy` in
  `group_vars/all/main.yml`. Ansible tasks use it during the run (apt, GPG keys, config
  downloads); it is not written to the hosts. `no_proxy` is computed from localhost,
  `.consul` and every cluster host IP, plus `proxy_no_proxy_extra`.

## Quickstart

Run all commands from the `ansible/` directory.

```bash
# 1. Install required Ansible collections
ansible-galaxy collection install -r requirements.yml

# 2. Create your inventory from the example — see "Deployment profiles" for which one
cp -r inventories/singlehost.example inventories/production

# 3. Edit host definitions and assign services — see "Inventory model"
$EDITOR inventories/production/01-hosts.yml

# 4. Set the cluster variables — see "Required variables"
$EDITOR inventories/production/group_vars/all/main.yml

# 5. Fill in secret credentials — see "Secrets and vault" for the key list
cp inventories/production/group_vars/all/vault.yml.example \
   inventories/production/group_vars/all/vault.yml
$EDITOR inventories/production/group_vars/all/vault.yml
ansible-vault encrypt inventories/production/group_vars/all/vault.yml

# 6. Run the playbook
ansible-playbook -i inventories/production site.yml --ask-vault-pass
```

## Required variables

| Variable | Where | When |
|---|---|---|
| `topology_profile` | `group_vars/all/main.yml` | always |
| `webitel_version` | `group_vars/all/main.yml` | always, `MAJOR.MINOR` (e.g. `26.6`) |
| `nginx_site_name` | `group_vars/all/main.yml` | always |
| `vault_*` keys | `group_vars/all/vault.yml` | always, see "Secrets and vault" |
| `services` | each host in the inventory file | always |
| `dns_upstream_servers` | `group_vars/all/main.yml` or per datacenter | inventories with `patroni` (`consul_dns_forward`) |
| `primary_datacenter` | `group_vars/all/main.yml` | `warm_standby` |
| `datacenter` | `vars:` of each datacenter group | more than one datacenter |

Every other variable has a default. The example `group_vars/all/main.yml` lists the
common ones, commented out.

## Deployment profiles

Every inventory declares its profile via `topology_profile` in
`group_vars/all/main.yml`. Preflight fails when the inventory does not match the
declared profile.

| | `singlehost` | `multihost` | `failover` | `warm_standby` | `stretch` |
|---|---|---|---|---|---|
| **Example inventory** | `singlehost.example` | `multihost.example` | `failover.example` | `warm-standby-2dc.example` | — |
| **Datacenters** | 1 (single host) | 1 | 1 | 2+ | 3+ |
| **PostgreSQL** | standalone | standalone | one Patroni cluster | primary + N standby clusters | one cluster across all DCs |
| **Consul** | 1 server, loopback | 1 server | 1 cluster, 3+, odd | isolated cluster per DC | one raft, three fault domains |
| **RabbitMQ / Nomad** | single | single | cluster | cluster per DC | cluster per DC |
| **Survives** | nothing | loss of a non-DB host | loss of one node | loss of a datacenter | loss of a datacenter |
| **Promotion** | — | — | Patroni, automatic | external controller, manual | Patroni, automatic |
| **RPO** | last backup | last backup | ~0 (≤ 1 MiB WAL) | replication lag; unbounded once the link degrades | ~0 (≤ 1 MiB WAL), or 0 in sync mode |
| **RTO** | hours | hours (DB) | ~30–45 s | minutes to hours | ~60–90 s |

The **external controller** is a process outside this playbook that drains Nomad nodes
and promotes the standby database. This playbook does not install or configure it.

RPO and RTO are database-layer targets with the shipped defaults, not guarantees. They
are bounded by:

- `failover` and `stretch` — `patroni_ttl` (30 s / 60 s) plus promotion time for RTO,
  `maximum_lag_on_failover` (1 MiB) for RPO.
- `warm_standby` — how fast the external controller promotes and reroutes. There is no
  replication slot: with extreme lag the standby must be rebuilt.
- `singlehost` and `multihost` — your backup schedule and restore speed.

RTO covers the database only; application, DNS and SIP routing add their own.

Only `failover` and `stretch` promote automatically.

`warm_standby` supports any number of datacenters from two; `stretch` needs three.

`stretch` is active/passive: traffic is served by the datacenter holding the database
leader. Under `stretch`, `consul_raft_multiplier`, `patroni_ttl` and `patroni_retry_timeout`
are raised automatically. Set `patroni_synchronous_mode: true` for no transaction loss on
a cross-DC failover; every commit then waits for a WAN round trip.

Two datacenters without replication between them are two separate `failover`
inventories.

All profiles use the same `site.yml` playbook; the inventory's service groups
(`consul_server`, `patroni`, `nomad_server`, `rabbitmq`) select cluster or single-node
setup. Once any host is a `nomad_client`, Nomad runs every app service (all `webitel-*`,
opensips, rtpengine, freeswitch, grafana): Ansible installs and configures the units but
leaves them disabled, and `playbooks/nomad_jobs.yml` submits one job per service.

Validate an inventory without touching any host:

```bash
ansible-playbook -i inventories/<name> playbooks/validate_topology.yml
```

## Inventory model

Each host lists its `services`. The
[`webitel_services`](plugins/inventory/webitel_services.py) inventory plugin turns them
into groups. Set `services` in the inventory file, not in `host_vars/` or `group_vars/`.

```yaml
# inventories/production/01-hosts.yml
all:
  hosts:
    node1:
      ansible_host: 1.2.3.4
      services:
        - consul_server
        - postgres
        - rabbitmq
        - freeswitch
        - nginx
        - webitel_core
        - webitel_engine
        # ... more services
```

The full set of values `services` accepts is the service catalog in
[`roles/topology/vars/services.yml`](roles/topology/vars/services.yml); preflight rejects
anything not in it.

`datacenter` defaults to `dc1`. In a multi-datacenter inventory put the hosts of each
datacenter in a group and set `datacenter` in its `vars:` (see `warm-standby-2dc.example`).

Inspect the resulting groups at any time:

```bash
ansible-inventory -i inventories/production --graph
```

### Per-datacenter set ids

In a multi-datacenter inventory, set `freeswitch_dispatcher_setid` and
`rtpengine_setid` on each datacenter group so OpenSIPS routes to the FreeSWITCH
and rtpengine nodes of its own datacenter:

```yaml
dc_a:
  vars:
    datacenter: dc_a
    freeswitch_dispatcher_setid: 1
    rtpengine_setid: 1
```

Set them in group `vars:` or `group_vars`.
Without them every node is in set `1`. Single-datacenter inventories can ignore both.

## Secrets and vault

Every secret goes into `inventories/production/group_vars/all/vault.yml`, encrypted with
`ansible-vault`. Each example inventory ships a `vault.yml.example` with the keys it needs.
Preflight stops the run while any `vault_*` value still contains `CHANGE_ME`, or a password
is left at its default `webitel`.

```yaml
# Every example inventory:
vault_webitel_repo_s3_access_key: "..."
vault_webitel_repo_s3_secret_key: "..."
vault_freeswitch_signalwire_key: "pat_..."
vault_webitel_cookie_seed: "<random>"               # openssl rand -hex 32
vault_webitel_pg_password: "<random>"               # PostgreSQL app user
vault_webitel_amqp_password: "<random>"             # RabbitMQ user
vault_grafana_admin_password: "<random>"
vault_grafana_db_password: "<random>"               # Grafana backend DB user
vault_grafana_datasource_password: "<random>"       # Grafana SELECT-only datasource user
# multihost, failover, warm-standby-2dc:
vault_consul_encrypt_key: "<16-byte base64>"        # consul keygen
# failover, warm-standby-2dc:
vault_rabbitmq_erlang_cookie: "<random>"            # same on every node
vault_patroni_superuser_password: "<random>"
vault_patroni_replication_password: "<random>"
vault_patroni_rewind_password: "<random>"
vault_patroni_restapi_password: "<random>"
```

Secrets are read only from these `vault_*` keys; the inventory `group_vars` do not set them.

```bash
ansible-vault encrypt inventories/production/group_vars/all/vault.yml   # once
ansible-vault edit inventories/production/group_vars/all/vault.yml      # later

# Unlock at run time: prompt, or a password file (never commit it)
ansible-playbook -i inventories/production site.yml --ask-vault-pass
ansible-playbook -i inventories/production site.yml --vault-password-file ~/.vault_pass
```

## Packages

Webitel packages come from the `<webitel_version>-releases` component of the Webitel APT
repository. `webitel_packages_state: latest` (default) installs the newest build of that
release on every run; `present` keeps the installed builds.

## Service configs

The NGINX, OpenSIPS, rtpengine and FreeSWITCH configs are downloaded from
`webitel_config_base_url`:

```
https://raw.githubusercontent.com/webitel/deployment/refs/heads/{{ webitel_config_branch }}
```

`webitel_config_branch` defaults to `v<YY>.<MM>` of `webitel_version` (`26.6` → `v26.06`).
Set it in `group_vars/all/main.yml` to use another branch.

Each config is downloaded while the marker `/etc/<service>/.bootstrap` is absent
(`/etc/nginx`, `/etc/opensips`, `/etc/rtpengine`, `/etc/freeswitch`). On every run the
roles then set addresses, ports and credentials in the downloaded files. To download a
config again, delete its marker and re-run the playbook.

## Network access

The playbook does not manage a firewall. Restrict the OpenSIPS MI port (8000/tcp) and
the rtpengine ng port (`rtpengine_ng_port`, 60000/udp) with your firewall.

## After the run

The last play prints the server identifier from `<webitel_public_url>/api/srvinfo`. Copy it
and create a license request on the Support Portal.

The request checks the TLS certificate only when `nginx_tls_mode` is `letsencrypt`; set
`webitel_srvinfo_validate_certs` to override.

## Verification commands

After a successful run, check cluster health on any cluster node:

```bash
# Consul — all servers should be alive
consul members

# RabbitMQ — all nodes running
rabbitmqctl cluster_status
```

Inventories with `patroni` only:

```bash
# Resolve the Patroni leader via Consul DNS
dig @127.0.0.1 -p 8600 primary.webitel-postgres.service.consul

# Patroni — expect 1 Leader + N Replica, Lag 0
patronictl -c /etc/patroni/config.yml list
```

Inventories with Nomad, on a Nomad server. With TLS (`consul_pki_enabled`, on with Patroni):

```bash
export NOMAD_ADDR=https://127.0.0.1:4646 NOMAD_CACERT=/etc/ssl/app/ca.pem

# Nomad servers
nomad server members

# Nomad clients
nomad node status
```

## Tags

The infrastructure roles below have per-phase tags:

| Tag | Effect |
|---|---|
| `base_install`, `base_repo`, `base_configure` | Base system role phases |
| `pki_ca`, `pki_node` | CA generation / per-node certificates |
| `consul_install`, `consul_configure`, `consul_dns`, `consul_queries` | Consul role phases, dnsmasq forwarding, prepared queries |
| `nomad_install`, `nomad_configure` | Nomad role phases |
| `haproxy_install`, `haproxy_configure` | HAProxy role phases |
| `postgres_install`, `postgres_configure`, `postgres_database` | Standalone PostgreSQL role phases |
| `patroni_install`, `patroni_configure`, `patroni_bootstrap` | Patroni role phases |
| `rabbitmq_install`, `rabbitmq_configure`, `rabbitmq_cluster` | RabbitMQ role phases |
| `freeswitch_install`, `freeswitch_configure` | FreeSWITCH role phases |
| `rtpengine_install`, `rtpengine_configure` | RTPEngine role phases |
| `opensips_install`, `opensips_configure`, `opensips_fail2ban` | OpenSIPS role phases |
| `nginx_install`, `nginx_configure`, `nginx_tls` | NGINX role phases |
| `grafana_install`, `grafana_configure`, `grafana_dashboards` | Grafana role phases |

Webitel services are tagged differently: one tag per service
(`webitel_core`, `webitel_engine`, `webitel_call_center`, `webitel_flow_manager`,
`webitel_storage`, `webitel_messages`, `webitel_logger`, `webitel_cases`,
`webitel_media_exporter`, `webitel_storage_key`) selects *which* services run,
and the shared `install` / `configure` tags select *which phase*. Combine them.
`webitel_verify` checks that the Webitel units are running.

```bash
# Re-run only NGINX configuration
ansible-playbook -i inventories/production site.yml \
  --tags nginx_configure --ask-vault-pass

# Re-render env files for webitel_core only, without touching packages
ansible-playbook -i inventories/production site.yml \
  --tags webitel_core --skip-tags install --ask-vault-pass
```
