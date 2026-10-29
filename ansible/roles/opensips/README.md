# opensips

Installs and configures OpenSIPS from the official APT repository for Webitel SIP proxy.

## Configuration

`opensips.cfg` is downloaded from `opensips_config_url`
(`{{ webitel_config_base_url }}/opensips/opensips.cfg`) while `/etc/opensips/.bootstrap`
is absent. The role then sets the values below on every run. To download the config
again, delete `/etc/opensips/.bootstrap` and re-run the role.

## Variables

See `defaults/main.yml` for configurable variables.

## Address resolution

In every mode, from the topology facts:

- PostgreSQL DSN → `webitel_pg_user`, `webitel_pg_password`, `webitel_pg_host`:`webitel_pg_port`
- RabbitMQ connection → `webitel_amqp_user`, `webitel_amqp_password`, `webitel_amqp_host`:`webitel_amqp_port`
- FreeSWITCH dispatcher set → `freeswitch_dispatcher_setid`

In multi-host inventories (`single_node: false`) also:

- MI listen address → `opensips_mi_listen` (host IP, or all addresses with a VIP)
- RTPEngine → depends on how many rtpengine hosts the datacenter runs:
  - **exactly one**: its address is set in the static `rtpengine_sock` modparam.
  - **several**: the static socket is commented out, the `db_url` modparam is
    uncommented, and `rtpengine_use_set()` is pointed at this datacenter's set.
    The socket rows come from the `rtpengine` table (`roles/rtpengine`); the set is
    reloaded over MI on every run.

## Dispatcher probing

`ds_probing_mode` is set to `1` (ping every destination) and the datacenter's
`freeswitch_dispatcher_setid` is added to `ds_probing_list`. FreeSWITCH must answer OPTIONS
with 200. `opensips_ds_ping_interval` sets `ds_ping_interval`; empty keeps the value from the
downloaded config.

## Floating IP

`opensips_vip` (`address/prefix`) adds a systemd drop-in that brings the address up with
OpenSIPS and removes it when OpenSIPS stops. Set `external_opensips_host` to the same address.

## fail2ban integration

When `opensips_fail2ban: true`, the `fail2ban.yml` task file is included. It installs
rsyslog and fail2ban, redirects OpenSIPS logs to `/var/log/opensips.log` via LOCAL7
syslog facility, and deploys `filter.d/opensips.conf` and `logrotate.d/opensips`.
