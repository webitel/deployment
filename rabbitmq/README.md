# RabbitMQ

[RabbitMQ](https://rabbitmq.com) is a [feature rich](https://www.rabbitmq.com/docs),
multi-protocol messaging and streaming broker.
Webitel uses it as the message bus between services — every service publishes and consumes
events and RPC calls through it.

> [!NOTE]
> The configuration below already enables
> Consul-based peer discovery, so the same config can be reused for a cluster.

## Install

Team RabbitMQ publishes its own APT repositories — the `rabbitmq-server` package in the
distribution repositories is outdated. Add the repository and install the packages
([official instructions](https://www.rabbitmq.com/docs/install-debian)):

```shell
sudo apt-get update -y
sudo apt-get install curl gnupg apt-transport-https lsb-release -y

## Team RabbitMQ's signing key
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null

## Add apt repositories maintained by Team RabbitMQ.
## deb1/deb2 are two mirrors of the same content — both are listed for redundancy.
sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Latest RabbitMQ releases
##
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-server/debian/`lsb_release -sc` `lsb_release -sc` main
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb2.rabbitmq.com/rabbitmq-server/debian/`lsb_release -sc` `lsb_release -sc` main
EOF

## Update package indices
sudo apt-get update -y

## Install Erlang packages
sudo apt-get install -y erlang-base \
                        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                        erlang-runtime-tools erlang-snmp erlang-ssl \
                        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

## Install rabbitmq-server and its dependencies
sudo apt-get install rabbitmq-server -y --fix-missing
```

> [!IMPORTANT]
> Erlang comes from the Debian repositories, which ship a suitable version (27.x) starting with
> Debian 13 `trixie`. On Debian 12 `bookworm` the bundled Erlang is 25.x and RabbitMQ 4.x will
> not start — add the Erlang repository to `/etc/apt/sources.list.d/rabbitmq.list` as well,
> before `apt-get update`:
> ```
> deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-erlang/debian/`lsb_release -sc` `lsb_release -sc` main
> deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb2.rabbitmq.com/rabbitmq-erlang/debian/`lsb_release -sc` `lsb_release -sc` main
> ```

> [!IMPORTANT]
> The repositories above serve `amd64` only. On `arm64` use the
> [Launchpad PPA](https://www.rabbitmq.com/docs/install-debian#apt-launchpad-erlang)
> for Erlang and install `rabbitmq-server` from the same RabbitMQ repository
> (the server package is architecture independent).

Check the installed versions:
```shell
rabbitmqctl version
erl -noshell -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().'
```

The package installs and starts the `rabbitmq-server` unit with a default configuration —
it is replaced by the Webitel configuration below.

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
sudo curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/rabbitmq/enabled_plugins \
  -o /etc/rabbitmq/enabled_plugins

sudo curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/rabbitmq/rabbitmq.conf \
  -o /etc/rabbitmq/rabbitmq.conf
```

[`enabled_plugins`](enabled_plugins) enables the management UI/HTTP API, Consul peer discovery,
federation and shovel (with their management extensions).

[`rabbitmq.conf`](rabbitmq.conf) binds the AMQP listener and the management HTTP API to
`127.0.0.1`, registers the node in Consul for peer discovery, resolves network partitions
with `autoheal` and sets the memory (60% of RAM) and free disk (5GB) alarm thresholds.

### Change IPs
```diff
- cluster_formation.consul.host = 127.0.0.1
+ cluster_formation.consul.host = 1.1.1.1

- listeners.tcp.1 = 127.0.0.1:5672
+ listeners.tcp.1 = 2.2.2.2:5672
```

> [!IMPORTANT]
> With `127.0.0.1` the broker is reachable only from the same host.
> If Webitel services or FreeSWITCH run on other nodes, bind the listener to an address
> they can reach and restrict the access on the firewall level.

### Create Webitel user
```shell
sudo rabbitmqctl add_user webitel webitel
sudo rabbitmqctl set_user_tags webitel administrator
sudo rabbitmqctl set_permissions -p / webitel ".*" ".*" ".*"
sudo rabbitmqctl delete_user guest
```

> [!CAUTION]
> `webitel:webitel` is a well-known default and **must be changed on production**.
> Set a strong password:
> ```shell
> sudo rabbitmqctl change_password webitel '<strong-password>'
> ```
> The password is used in the connection strings of every Webitel service, so it has to be
> updated in all of them and the services restarted afterwards.
>
> If the password contains characters reserved in a URI (`@`, `:`, `/`, `?`, `#`), percent-encode
> it inside the `amqp://` connection strings.

## Run
```shell
sudo systemctl enable rabbitmq-server
sudo systemctl restart rabbitmq-server
```

Verify that the node is up and the plugins are running:
```shell
sudo rabbitmqctl status
sudo rabbitmq-plugins list --enabled
```

## Addons

### Management UI

The management HTTP API and UI listen on `127.0.0.1:15672` (see `management.tcp.ip`).
To reach them from a workstation without exposing the port, forward it over SSH:
```shell
ssh -L 15672:127.0.0.1:15672 <user>@<node>
```
and open <http://127.0.0.1:15672> with the `webitel` credentials.

> [!NOTE]
> `loopback_users.admin = false` in [`rabbitmq.conf`](rabbitmq.conf) is a leftover of an
> `admin` user that is not created by this guide — it has no effect on the `webitel` user.
> By default RabbitMQ restricts only `guest` to loopback connections, and that user is deleted.

### Debug

- Show the cluster status and the members:
    ```shell
    sudo rabbitmqctl cluster_status
    ```

- List the client connections and the channels:
    ```shell
    sudo rabbitmqctl list_connections name user peer_host state
    sudo rabbitmqctl list_channels connection name consumer_count messages_unacknowledged
    ```

- Show the queues with a backlog (messages are piling up — a consumer is down or too slow):
    ```shell
    sudo rabbitmqctl list_queues name messages messages_ready consumers --no-table-headers | awk '$2 > 0'
    ```

- List the exchanges and the bindings of a queue (replace `<queue>`):
    ```shell
    sudo rabbitmqctl list_exchanges name type
    sudo rabbitmqctl list_bindings | grep <queue>
    ```

- Check the memory and disk alarms (`{resource_limit,...}` in the logs means an alarm blocks
  the publishers):
    ```shell
    sudo rabbitmqctl status | grep -A5 -E 'Memory|Alarms'
    ```

- Show the users and their permissions:
    ```shell
    sudo rabbitmqctl list_users
    sudo rabbitmqctl list_permissions -p /
    ```

- Follow the logs:
    ```shell
    sudo journalctl -u rabbitmq-server -f
    sudo tail -f /var/log/rabbitmq/rabbit@$(hostname -s).log
    ```

- Run the health checks (used by the Consul service check as well):
    ```shell
    sudo rabbitmq-diagnostics check_running
    sudo rabbitmq-diagnostics check_port_connectivity
    sudo rabbitmq-diagnostics check_alarms
    ```
