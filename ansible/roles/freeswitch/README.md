# freeswitch

Installs and configures FreeSWITCH from the SignalWire APT repository.

## Configuration

The configs in `freeswitch_config_files` are downloaded from `freeswitch_config_base_url`
(`{{ webitel_config_base_url }}/freeswitch`) while `/etc/freeswitch/.bootstrap` is absent.
On every run the role then sets the RTP port range, the AMQP connection and the service
endpoints in `vars.xml` and `configuration.xml`. To download the configs again, delete
`/etc/freeswitch/.bootstrap` and re-run the role.

In multi-host inventories the role also writes one `dispatcher` row per FreeSWITCH host,
tagged with that host's `freeswitch_dispatcher_setid`.

## Variables

See `defaults/main.yml` for configurable variables. The role also uses the topology facts
`webitel_opensips_host`, `webitel_amqp_host` and `webitel_consul_address` for
`outbound_sip_proxy`, `amqp_host` and `consul_url` in vars.xml.
