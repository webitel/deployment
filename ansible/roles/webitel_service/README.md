# webitel_service

Generic, data-driven role for all Webitel microservices. Installs the deb
package, sets keys in the package-shipped env files, and enables the systemd units.

## Usage

```yaml
- name: Webitel engine
  hosts: webitel_engine
  become: true
  roles:
    - { role: webitel_service, webitel_service_name: engine, tags: [webitel_engine] }
```

## Input

| Variable | Description |
|---|---|
| `webitel_service_name` | Required. Service name; selects which `vars/services/<name>.yml` gets loaded |
| `webitel_service_env_extra` | dict of env keys overriding every env block's env (per-host; applied to all files in multi-unit services) |

## Service catalog (`vars/services/<name>.yml`)

A single `webitel_service_spec` dict:

| Key | Default | Description |
|---|---|---|
| `package` | — (required) | deb package name |
| `env_files` | `[]` | list of env blocks `{path, env}`, one per unit for multi-unit packages (core api/app/uac/portal, messages srv/bot). Each file ships with the package; the role overrides keys in place. Empty/missing skips the env configuration step |

Systemd units come from the service catalog (`roles/topology/vars/services.yml`,
key `webitel_<name>`).

Under `nomad_managed` units are installed but left disabled; Nomad starts them. The
restart handler then restarts a unit only where it is currently active.

Each `env_files` entry:

| Key | Description |
|---|---|
| `path` | path to the package's env file; check with `dpkg -L <package> \| grep /etc/default/` |
| `env` | dict of env keys (values are Jinja, referencing shared group_vars) |

## Tunables (ports, DSN, log level)

Ports, DSN parameters, and log level are configured via namespaced vars
in `group_vars`/`host_vars`. Defaults live in `roles/topology/defaults`; nginx reads
the same variables.

### Listener ports

| Service | listener | knob | port | nginx |
|---|---|---|---|---|
| core api | HTTP | `webitel_core_api_http_port` | 10001 | yes |
| core api | micro-gRPC | `webitel_core_api_grpc_port` | 10002 |  |
| core app | micro-gRPC | `webitel_core_app_grpc_port` | 10003 |  |
| core uac | micro-gRPC | `webitel_core_uac_grpc_port` | 10004 |  |
| core portal | micro-gRPC | `webitel_core_portal_grpc_port` | 10005 |  |
| engine | WebSocket | `webitel_engine_websocket_port` | 10007 | yes |
| engine | gRPC | `webitel_engine_grpc_port` | 10008 |  |
| call_center | gRPC | `webitel_call_center_grpc_port` | 10009 |  |
| flow_manager | ESL | `webitel_flow_manager_esl_port` | 10010 |  |
| flow_manager | gRPC | `webitel_flow_manager_grpc_port` | 10011 |  |
| flow_manager | web | `webitel_flow_manager_web_port` | 10012 |  |
| storage | internal HTTP | `webitel_storage_internal_port` | 10013 |  |
| storage | public HTTP | `webitel_storage_public_port` | 10014 | yes |
| storage | gRPC | `webitel_storage_grpc_port` | 10015 |  |
| logger | gRPC | `webitel_logger_grpc_port` | 10016 |  |
| messages | micro service | `webitel_messages_service_port` | 10017 |  |
| messages | bot HTTP | `webitel_messages_bot_port` | 10018 | yes |
| messages bot | micro-gRPC | `webitel_messages_bot_service_port` | 10019 |  |
| cases | gRPC | `webitel_cases_grpc_port` | 10020 |  |
| media_exporter | gRPC | `webitel_media_exporter_grpc_port` | 10021 |  |

> core (api/app/uac/portal) and messages-bot micro-gRPC use `MICRO_SERVICE_ADDRESS`
> on the **host IP + fixed port**. `MICRO_API_ADDRESS` (HTTP gateway api) is
> `{{ webitel_core_bind_host }}:{{ webitel_core_api_http_port }}` (single -> `127.0.0.1:10001`, multihost -> `hostIP:10001`).

`nginx: yes` marks the listener nginx proxies to; the `nginx` role sets the same
knob in `/etc/nginx/sites-enabled/default` on every run. To download the nginx configs
again, delete `/etc/nginx/.bootstrap` and re-run the `nginx` role.

### DSN / AMQP tuning (two-level: cluster, then service)

| knob (cluster) | default | per-service override |
|---|---|---|
| `webitel_pg_sslmode` | `disable` | `webitel_<svc>_pg_sslmode` |
| `webitel_pg_connect_timeout` | `10` | `webitel_<svc>_pg_connect_timeout` |
| `webitel_amqp_heartbeat` | `10` | `webitel_<svc>_amqp_heartbeat` |

`search_path` is not configurable.

### Log level (two-level)

`webitel_log_level` (default `info`) applies cluster-wide; `webitel_<svc>_log_level`
overrides it per service (core, engine, call_center, flow_manager, storage, messages).
The `logger`, `cases` and `media_exporter` services have no log level setting.

### Service-specific

| knob | default | service |
|---|---|---|
| `webitel_storage_media_directory` | `/opt/storage/data` | storage |
| `webitel_call_center_omnichannel` | `0` | call_center |

## Tags

- `install` / `configure`: phases (all services)
- `webitel_<name>`: applied at the include level in the playbook (whole service)
- Scope to one service: `--limit webitel_<name> --tags <phase>`

## Notes

Check env file paths with `dpkg -L <package> | grep /etc/default/`.
The role fails if an env file is missing.
