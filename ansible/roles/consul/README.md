# consul

Installs and configures HashiCorp Consul from the HashiCorp APT repository: server mode on
`consul_server` hosts, agent mode on `consul_agent` hosts.

See `defaults/main.yml` for configurable variables.

## Datacenter scope

`consul_datacenter` follows the deployment profile (`roles/topology/vars/main.yml`):

- `_topology_db_scope: dc` (default) — each site is a separate Consul datacenter named after `datacenter`. No WAN federation.
- `_topology_db_scope: global` (profile `stretch`) — all sites form one Consul datacenter named `consul_global_datacenter`, with servers in exactly three fault domains. `consul_raft_multiplier` is 5 (1 in `dc` scope).

## DNS forwarding

`consul_dns_forward` (default: on when the inventory has `patroni`) installs dnsmasq, which sends `.consul` to Consul and everything else to `dns_upstream_servers`, and points `/etc/resolv.conf` at it. `dns_upstream_servers` is then required on every Consul host. With forwarding off the host resolver is left as is.
