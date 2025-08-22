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

### NGINX config file
```shell
rm /etc/nginx/sites-enabled/default && rm /etc/nginx/nginx.conf
curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/nginx/nginx.conf -o /etc/nginx/nginx.conf
curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/nginx/default -o /etc/nginx/sites-enabled/default
```

### Secure communication

Here you have a several option how to get your Webitel instalation secured by using TLS:
- Self-signed certificates
- `Let's encrypt` with `certbot`
- Custom certificate

For configuring self-signed or your custom certificates please refer to the [config file](nginx.conf).  
Certificate generation process via `Let's encrypt` using `certbot` described [bellow](#lets-encrypt).

### Proxy target hosts

`NGINX` acts not only as a server for static files, but also as a proxy for other services. 
If your Webitel deployment spread over several hosts, you need to configure proxy targets to forward requests to the correct host.
```diff
map $request_method     $api_backend {
     - default "127.0.0.1:8080";
     + default "webitel-api-service"
     
     - POST    "127.0.0.1:10023";
     + POST    "webitel-storage-service-public";
}

server {
    location ~ ^/api/storage/(media|recordings|file|tts)/?(.*/)(stream|download|upload|transcript).* {
        - proxy_pass http://127.0.0.1:10023;
        + proxy_pass http://webitel-storage-service-public;
   }
   
   location ~ ^/any/file(/\d+)?/download(/.*)? {
        - proxy_pass http://127.0.0.1:10023;
        + proxy_pass http://webitel-storage-service-public;
   }
   
   location ~ ^/any/file/(.*) {
        - proxy_pass http://127.0.0.1:10023;
        + proxy_pass http://webitel-storage-service-public;
   }
   
   location ~ ^/api(/?)(.*) {
        - proxy_pass http://127.0.0.1:8080;
        + proxy_pass http://webitel-api-service;
   }
   
   location ~ ^/chat(/?)(.*) {
        - proxy_pass http://127.0.0.1:10031;
        + proxy_pass http://webitel-messages-bot-service;
   }

    location ~ ^(/appointments/.*) {
        - proxy_pass http://127.0.0.1:10022;
        + proxy_pass http://webitel-engine-service-websocket;
    }

    location ~ ^(/endpoint/oauth2/.*) {
        - proxy_pass http://127.0.0.1:10022;
        + proxy_pass http://webitel-engine-service-websocket;
    }

    location ~ ^/ws(/?)(.*) {
        - proxy_pass http://127.0.0.1:10022;
        + proxy_pass http://webitel-engine-service;
   }

    location ~ ^/sip(/?) {
        - proxy_pass http://127.0.0.1:5070;
        + proxy_pass http://opensips-websocket-socket;
   }

    location /webitel.portal. {
        - grpc_pass grpc://127.0.0.1:10028;
        + grpc_pass grpc://webitel-portal-service;
    }

   location ~ ^/grafana(/?)(.*) {
        - proxy_pass http://127.0.0.1:3000;
        + proxy_pass http://grafana-server-service;
   }
}
```

## Run
```shell
systemctl enable --now nginx
systemctl restart nginx
```

## Addons

### Let's encrypt

- Install a `Let's encrypt` client:
    ```shell
    sudo apt-get install python3-certbot-nginx
    ```

- Run `certbot` to generate a TLS certificate for your domain:
    ```shell
    certbot --nginx
    ```

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
