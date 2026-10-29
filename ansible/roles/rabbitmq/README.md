# rabbitmq

Installs and configures RabbitMQ, single node or cluster.

## Variables

See `defaults/main.yml` for configurable variables.

## Tags

Tags: `rabbitmq_install`, `rabbitmq_configure`, `rabbitmq_cluster` — see `tasks/main.yml`.

## Notes

- In every multi-host inventory RabbitMQ uses Consul peer discovery and registers in
  Consul as `rabbitmq`, or `rabbitmq-<datacenter>` under `stretch`.
- Cluster mode activates when `rabbitmq_cluster_hosts | length > 1` (RabbitMQ hosts of the
  same datacenter). Every node gets the shared Erlang cookie (`vault_rabbitmq_erlang_cookie`).
- Hostname resolution: cluster nodes talk to each other as `rabbit@<ansible_hostname>` (the server's short hostname). The role adds `/etc/hosts` entries (`<ip> <hostname>`) for all peers and pins `RABBITMQ_NODENAME=rabbit@{{ ansible_hostname }}` in `/etc/rabbitmq/rabbitmq-env.conf`.
- On a fresh install of a cluster node the role removes the node database the package
  created (`/var/lib/rabbitmq/mnesia`) before it sets the cookie. A node initialized earlier
  with a different node name or cookie needs `rabbitmqctl reset` by hand.

## Verification

```bash
rabbitmqctl cluster_status    # all nodes running
```
