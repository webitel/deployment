# Consul

[Consul](https://developer.hashicorp.com/consul) is a distributed, highly available, and data center aware
solution to connect and configure applications across dynamic, distributed infrastructure.
Webitel uses it for service discovery and health checking — every service registers itself in Consul,
and the services find each other through it.

> [!NOTE]
> Currently adopted a single-node Consul cluster.
> In HA deployments it is recommended to use the cluster with minimum of three nodes (or odd number to keep quorum).

## Install

Add the HashiCorp APT repository and install the package
([official instructions](https://developer.hashicorp.com/consul/install)):

```shell
sudo apt-get update -y
sudo apt-get install -y wget gpg coreutils lsb-release

wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update -y
sudo apt-get install consul -y
```

Check the installed version:
```shell
consul --version
```

The package creates the `consul` system user, the `/etc/consul.d` configuration directory
and its own `consul.service` unit — all of them are replaced by the Webitel configuration below.

## Configure

### Prepare directories
```shell
sudo systemctl stop consul 2>/dev/null

sudo rm -rf /etc/consul.d
sudo mkdir -p /var/consul /etc/consul.d

sudo chown -R consul:consul /var/consul /etc/consul.d
```

### Download config (server)
```shell
sudo curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/consul/server.json \
  -o /etc/consul.d/config.json
```

The [`server.json`](server.json) config runs the agent in server mode, bootstraps a single-node
cluster (`bootstrap_expect: 1`) and binds the client interfaces (HTTP API, DNS) to `127.0.0.1`.
Keep the data directory in sync with the `data_dir` value if you change it.

> [!IMPORTANT]
> With `client_addr: 127.0.0.1` the API is reachable only from the same host.
> If Webitel services run on other nodes, set `client_addr` to an address they can reach
> and restrict the access on the firewall level.

### Create systemd service
```shell
sudo curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/consul/consul.service \
  -o /etc/systemd/system/consul.service

sudo systemctl daemon-reload
```

The [`consul.service`](consul.service) unit starts the agent with `-bind=127.0.0.1` and
`-node=consul01.wbtl.local`. Change both to the real address and hostname of the node
in a multi-node setup.

### Gossip encryption (optional)

Generate a shared key and add it to the config — the same key must be used on every node
of the cluster:
```shell
consul keygen
```
```shell
sudo tee -a /etc/consul.d/encrypt.json >/dev/null <<EOF
{
  "encrypt": "<key-from-consul-keygen>"
}
EOF

sudo chown consul:consul /etc/consul.d/encrypt.json
```

## Run
```shell
sudo systemctl enable consul
sudo systemctl start consul
```

Verify that the agent is up and has elected itself a leader:
```shell
systemctl status consul
consul info -http-addr=127.0.0.1:8500 | grep leader
```

## Addons

### Debug

> [!IMPORTANT]
> Replace `127.0.0.1:8500` with the address of the Consul server.

- Show Consul cluster members:
    ```shell
    consul members -detailed -http-addr=127.0.0.1:8500
    ```

- Get a list of registered services:
    ```shell
    consul catalog services -http-addr=127.0.0.1:8500
    ```

- Show the instances and health checks of a single service (replace `<service>` with a name
  from the catalog):
    ```shell
    curl -s http://127.0.0.1:8500/v1/health/service/<service>
    ```

- Show all failing health checks:
    ```shell
    curl -s http://127.0.0.1:8500/v1/health/state/critical
    ```

- Follow the agent logs:
    ```shell
    journalctl -u consul -f
    ```

- Validate the configuration before restarting the agent:
    ```shell
    consul validate /etc/consul.d
    ```
