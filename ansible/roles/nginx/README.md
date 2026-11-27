# nginx

Installs NGINX from nginx.org (`nginx_apt_uri`, see APT mirrors in `ansible/README.md`) as
the Webitel reverse proxy.
Runs the `certbot` role when `nginx_tls_mode` is `letsencrypt`.

See `defaults/main.yml` for configurable variables.

`nginx_site_name` and `nginx_mail_address` are also used by the `certbot` role (included from `playbooks/web.yml`).

## Configuration

`nginx.conf` and `sites-enabled/default` are downloaded from `nginx_config_url` and
`nginx_site_url` (`{{ webitel_config_base_url }}/nginx/...`) while `/etc/nginx/.bootstrap`
is absent, or copied from `nginx_config_src` and `nginx_site_src` when
`webitel_config_src_dir` is set. The role then sets the upstream addresses and ports on every run. To download
the configs again, delete `/etc/nginx/.bootstrap` and re-run the role.

## Consul discovery (multi-host)

In multi-host, upstreams are nginx variables (`$storage_backend`, etc.) defined by an
http-level `map` that the role inserts at the top of `sites-enabled/default`, together
with `resolver 127.0.0.1:8600 valid=3s`. `proxy_pass` uses these variables.

| Upstream | Address |
|---|---|
| storage | `storage.service.consul` |
| api/core | `webitel-api.query.consul` (prepared query → `go.webitel.api`) |
| messages bot | `webitel-messages-bot.query.consul` (prepared query → `webitel.chat.bot`) |
| engine WS | `engine.service.consul` |
| opensips (`/sip`) | under Nomad `$opensips_backend` (`opensips.service.consul`, or `external_opensips_host` when set); otherwise the OpenSIPS host address (`webitel_opensips_host`) |
| grafana | under Nomad `grafana.service.consul`; otherwise the first `grafana` host |

Prepared queries are created by the `consul` role (`prepared_queries.yml`). A single-host
inventory uses `127.0.0.1`.

## dcctl

On hosts with the `webitel_dcctl` service the role inserts `location ^~ /dcctl/` into the content
`server{}` before `location / {` (managed `blockinfile` region, `tasks/dcctl.yml`), proxying to
`127.0.0.1:{{ webitel_dcctl_http_port }}`. The region is removed on other hosts.

- The prefix is cut by the trailing `/` of `proxy_pass`.
- `Authorization` is passed on, `Cookie` is not, and `X-Forwarded-For` carries the client address.
- Request bodies are limited to 64k, and requests are limited per address by the `limitreqsbyaddr` zone of the site,
  because every unauthenticated request costs a password check.
- The location sets its own `add_header`, so the site-wide ones are not inherited and dcctl sets its security headers itself.
- The operation stream (`/dcctl/api/v1/operations/{id}:watch`) is a nested location with `proxy_buffering off`,
  `gzip off` and `proxy_read_timeout` set to `nginx_dcctl_watch_timeout`.
- The UI, its fallback for deep links and its CSP come from dcctl itself.

## TLS modes

`nginx_tls_mode` selects how the public certificate is provisioned:

| Mode | Behaviour |
|------|-----------|
| `letsencrypt` | Let's Encrypt cert via the `certbot` role (`playbooks/web.yml`). Public domains only. |
| `provided` | Operator supplies `nginx_tls_cert` / `nginx_tls_key` (controller-side paths); the role copies them to `/etc/nginx/ssl/<site>.{crt,key}` and enables TLS. Set `nginx_tls_chain` (list of intermediates) to assemble the full chain on the target. |
| `self_signed` | Default. The role generates a self-signed cert for `nginx_site_name` and enables TLS; browsers show a warning. |

For `provided` / `self_signed` the role adds, in managed `blockinfile` regions:

- `listen 443 ssl http2` + `ssl_certificate` / `ssl_certificate_key` into the existing content `server{}`, and
- a separate `server{}` on `:80` that `return 301`s to `https://$host$request_uri`.

Changing `nginx_tls_cert_path` or `nginx_site_name` re-renders these regions. In `letsencrypt` mode `certbot --nginx --redirect` configures TLS.

See `defaults/main.yml` for the TLS variables (`nginx_tls_*`).
