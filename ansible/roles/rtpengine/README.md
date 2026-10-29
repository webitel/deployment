# rtpengine

Installs and configures ngcp-rtpengine from the Sipwise APT repository for Webitel media relay.

## Configuration

`rtpengine.conf` is downloaded from `rtpengine_config_url`
(`{{ webitel_config_base_url }}/rtpengine/rtpengine.conf`) while `/etc/rtpengine/.bootstrap`
is absent. The role then sets the port range and addresses below on every run. To
download the config again, delete `/etc/rtpengine/.bootstrap` and re-run the role.

## Variables

See `defaults/main.yml` for configurable variables.

## Address resolution

- `global` mode: `interface = <host IP>!<public>`. The public address is
  `rtpengine_public_address`; when it is empty and the host IP is private, it is
  detected with `community.general.ipify_facts`.
- `local` mode, or `global` with no public address: `interface = <host IP>`.
- Multi-host inventories (`single_node: false`): also
  `listen-ng = <host IP>:{{ rtpengine_ng_port }}`.

## The `rtpengine` table

In multi-host inventories the role reconciles `public.rtpengine` in the webitel
database: one `udp:<ip>:<ng port>` row per host in the `rtpengine` group, tagged
with that host's `rtpengine_setid`. OpenSIPS uses this table when its datacenter
runs more than one rtpengine. Set `rtpengine_setid` per datacenter in `group_vars`.

Rows are replaced as a whole on the active primary (`webitel_pg_primary_host`), once
per run, and only when they differ from the inventory.
