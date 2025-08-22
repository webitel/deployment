# RabbitMQ

[RabbitMQ](https://rabbitmq.com) is a [feature rich](https://www.rabbitmq.com/docs),
multi-protocol messaging and streaming broker.

## Install
```shell
sudo apt-get update -y
sudo apt-get install curl gnupg apt-transport-https -y

## Team RabbitMQ's main signing key
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null

## Community mirror of Cloudsmith: modern Erlang repository
curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null

## Community mirror of Cloudsmith: RabbitMQ repository
curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Provides modern Erlang/OTP releases from a Cloudsmith mirror
##
deb [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-erlang/deb/debian bookworm main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-erlang/deb/debian bookworm main

deb [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.novemberain.com/rabbitmq/rabbitmq-erlang/deb/debian bookworm main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.novemberain.com/rabbitmq/rabbitmq-erlang/deb/debian bookworm main

## Provides RabbitMQ from a Cloudsmith mirror
##
deb [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-server/deb/debian bookworm main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-server/deb/debian bookworm main

# another mirror for redundancy
deb [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.novemberain.com/rabbitmq/rabbitmq-server/deb/debian bookworm main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.novemberain.com/rabbitmq/rabbitmq-server/deb/debian bookworm main
EOF

sudo apt-get update

## Install Erlang packages
sudo apt-get install -y erlang-base \
  erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
  erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
  erlang-runtime-tools erlang-snmp erlang-ssl \
  erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

## Install rabbitmq-server and its dependencies
sudo apt-get install rabbitmq-server -y --fix-missing
```

## Configure

### Increase the open file limit
```shell
sudo mkdir -p /etc/systemd/system/rabbitmq-server.service.d
sudo tee /etc/systemd/system/rabbitmq-server.service.d/limits.conf <<EOF
[Service]
LimitNOFILE=64000
EOF

sudo systemctl daemon-reload
```

### Download configuration files
```shell
sudo mkdir -p /etc/rabbitmq
curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/rabbitmq/enabled_plugins \
  -o /etc/rabbitmq/enabled_plugins

curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/rabbitmq/rabbitmq.conf \
  -o /etc/rabbitmq/rabbitmq.conf
```

### Change IPs
```diff
- cluster_formation.consul.host = 127.0.0.1
+ cluster_formation.consul.host = 1.1.1.1

- listeners.tcp.1 = 127.0.0.1:5672
+ listeners.tcp.1 = 2.2.2.2:5672
```

### Create Webitel user
```shell
rabbitmqctl add_user webitel webitel
rabbitmqctl set_user_tags webitel administrator
rabbitmqctl set_permissions -p / webitel ".*" ".*" ".*"
rabbitmqctl delete_user guest
```

## Run
```shell
systemctl enable rabbitmq-server
systemctl restart rabbitmq-server
```

    



