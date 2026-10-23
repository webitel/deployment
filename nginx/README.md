# NGINX

NGINX has evolved from a web server to a comprehensive platform for app delivery, optimization, and security

## Install

### NGINX
```shell
apt-get install -qqy --no-install-recommends gnupg2 wget lsb-release curl

apt update
apt install nginx
```

### Webitel UI applications

Make sure that you have added the Webitel Debian repository to your system.

```shell
apt install webitel-auth-app webitel-admin-app webitel-agent-workspace \
  webitel-supervisor-workspace webitel-flow-diagram webitel-history \
  webitel-audit-app webitel-web-widget webitel-crm
```

## Configure

### Layout

| File                                        | Owner   | Purpose                                                   |
|---------------------------------------------|---------|-----------------------------------------------------------|
| `/etc/nginx/nginx.conf`                     | Webitel | Global NGINX settings                                     |
| `/etc/nginx/conf.d/webitel.conf`            | Webitel | Shared `map` and rate limit definitions                   |
| `/etc/nginx/snippets/webitel.conf`          | Webitel | Security headers, static applications and proxy locations |
| `/etc/nginx/sites-available/webitel`        | Webitel | HTTP site                                                 |
| `/etc/nginx/sites-available/webitel-ssl`    | Webitel | HTTPS site with HTTP to HTTPS redirect                    |
| `/etc/nginx/conf.d/webitel-upstreams.conf`  | **You** | Addresses of Webitel services, the only file you edit     |
| `/etc/nginx/ssl/webitel.crt`, `webitel.key` | **You** | TLS certificate and key for `webitel-ssl`                 |

Files owned by Webitel are safe to overwrite on every update. Do not edit them, any change will be lost.

### Install config files
```shell
NGINX_SRC=https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/nginx

curl -fsSL $NGINX_SRC/nginx.conf -o /etc/nginx/nginx.conf
curl -fsSL $NGINX_SRC/conf.d/webitel.conf -o /etc/nginx/conf.d/webitel.conf
curl -fsSL $NGINX_SRC/conf.d/webitel-upstreams.conf -o /etc/nginx/conf.d/webitel-upstreams.conf
curl -fsSL $NGINX_SRC/snippets/webitel.conf -o /etc/nginx/snippets/webitel.conf
curl -fsSL $NGINX_SRC/sites-available/webitel -o /etc/nginx/sites-available/webitel
curl -fsSL $NGINX_SRC/sites-available/webitel-ssl -o /etc/nginx/sites-available/webitel-ssl

mkdir -p /var/www/letsencrypt
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/webitel /etc/nginx/sites-enabled/webitel
```

### Proxy target hosts

`NGINX` acts not only as a server for static files, but also as a proxy for other services.
By default all of them are expected on `127.0.0.1`. If your Webitel deployment is spread over several hosts,
point the upstreams in `/etc/nginx/conf.d/webitel-upstreams.conf` to the correct hosts:
```diff
 upstream webitel_api {
-    server 127.0.0.1:8080;
+    server 10.0.0.11:8080;
 }
```

| Upstream               | Service                  | Default port |
|------------------------|--------------------------|--------------|
| `webitel_api`          | `webitel-api`            | 8080         |
| `webitel_storage`      | `storage` (public API)   | 10023        |
| `webitel_engine`       | `engine` (WebSocket API) | 10022        |
| `webitel_messages_bot` | `messages-bot`           | 10031        |
| `webitel_portal`       | `webitel-portal` (gRPC)  | 10028        |
| `opensips_websocket`   | OpenSIPS WebSocket       | 5070         |
| `grafana`              | Grafana                  | 3000         |

A service running on several hosts may be listed with several `server` lines, NGINX balances requests between them.
Hostnames are resolved once at NGINX start, so they must be resolvable at that moment.

Apply the change:
```shell
nginx -t && systemctl reload nginx
```

### Secure communication

`webitel-ssl` site serves Webitel over HTTPS and redirects plain HTTP to it.
It reads the certificate from `/etc/nginx/ssl/webitel.crt` and the key from `/etc/nginx/ssl/webitel.key`,
so the site file is the same for every environment, and you only need to put a certificate there:
- [Let's Encrypt](#lets-encrypt) with `certbot`
- Custom certificate: copy the full chain to `/etc/nginx/ssl/webitel.crt` and the key to `/etc/nginx/ssl/webitel.key`
- Self-signed certificate:
    ```shell
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 -subj "/CN=$(hostname -f)" \
      -keyout /etc/nginx/ssl/webitel.key -out /etc/nginx/ssl/webitel.crt
    ```

Switch to the HTTPS site:
```shell
rm -f /etc/nginx/sites-enabled/webitel
ln -sf /etc/nginx/sites-available/webitel-ssl /etc/nginx/sites-enabled/webitel-ssl
nginx -t && systemctl reload nginx
```

## Run
```shell
systemctl enable --now nginx
systemctl restart nginx
```

## Update

Download everything except `conf.d/webitel-upstreams.conf`, which holds your hosts:
```shell
NGINX_SRC=https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/nginx

curl -fsSL $NGINX_SRC/nginx.conf -o /etc/nginx/nginx.conf
curl -fsSL $NGINX_SRC/conf.d/webitel.conf -o /etc/nginx/conf.d/webitel.conf
curl -fsSL $NGINX_SRC/snippets/webitel.conf -o /etc/nginx/snippets/webitel.conf
curl -fsSL $NGINX_SRC/sites-available/webitel -o /etc/nginx/sites-available/webitel
curl -fsSL $NGINX_SRC/sites-available/webitel-ssl -o /etc/nginx/sites-available/webitel-ssl

nginx -t && systemctl reload nginx
```

## Addons

### Let's encrypt

The domain must point to this host and port 80 must be reachable from the Internet.
`certbot` only obtains the certificate, NGINX config files stay untouched.

- Install a `Let's encrypt` client:
    ```shell
    apt-get install certbot
    ```

- Obtain a certificate for your domain while the `webitel` (HTTP) site is enabled:
    ```shell
    certbot certonly --webroot -w /var/www/letsencrypt \
      -d webitel.example.com -m admin@example.com --agree-tos --no-eff-email \
      --deploy-hook "systemctl reload nginx"
    ```

- Link it to the place `webitel-ssl` reads it from, then [switch to the HTTPS site](#secure-communication):
    ```shell
    mkdir -p /etc/nginx/ssl
    ln -sf /etc/letsencrypt/live/webitel.example.com/fullchain.pem /etc/nginx/ssl/webitel.crt
    ln -sf /etc/letsencrypt/live/webitel.example.com/privkey.pem /etc/nginx/ssl/webitel.key
    ```

Renewal runs automatically by `certbot.timer`, the deploy hook reloads NGINX with the renewed certificate.
Check it with `certbot renew --dry-run`.

### Grafana

- Add `Grafana` stable repositories and install `Grafana OSS` server package:
    ```shell
    sudo mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
    
    sudo apt-get update
    sudo apt-get install grafana
    ```

- Change the public-face root url of `Grafana` instance:
    ```diff
    - root_url = %(protocol)s://%(domain)s:%(http_port)s/
    + root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/
    ```
