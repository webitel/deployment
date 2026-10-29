# haproxy

HAProxy in front of the Patroni PostgreSQL cluster and the RabbitMQ cluster.
Backends come from Consul DNS (`127.0.0.1:8600`) via `resolvers` + `server-template`.

TCP listeners:
- `postgres-rw` (`:6432`) → leader (`primary.<scope>.service.consul`)
- `postgres-ro` (`:6433`) → replicas, roundrobin (`replica.<scope>.service.consul`)
- `rabbitmq-amqp` (`:5673`) → rabbitmq nodes, leastconn (`rabbitmq.service.consul`; `rabbitmq-<datacenter>` under stretch)

`haproxy_pg_rw_check`:
- `dns` (default) — `postgres-rw` resolves `primary.<scope>.service.consul`.
- `patroni` — `postgres-rw` goes to the Patroni node that answers 200 on REST `/primary`.

PG listeners render when `haproxy_backends` is non-empty, AMQP when
`haproxy_rabbitmq_backends` is non-empty.

## Topology

HAProxy runs as a sidecar: `haproxy` in `services` on each host that connects to
PostgreSQL or RabbitMQ; services connect via `127.0.0.1`. Validation requires a local
`haproxy` on every PG/AMQP consumer, and requires `patroni` in the inventory.

`webitel_pg_*` / `webitel_amqp_*` point at HAProxy when the `haproxy` group exists.

See `defaults/main.yml` for configurable variables.

## Dependencies
A Consul agent with DNS on `:8600`; Patroni and RabbitMQ services registered in Consul.
