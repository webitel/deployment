# Consul

Consul is a distributed, highly available, and data center aware solution to connect and configure 
applications across dynamic, distributed infrastructure.

> [!NOTE]
> Currently adopted a single-node Consul cluster.  
> In HA deployments it is recommended to use the cluster with minimum of three nodes (or odd number to keep quorum).

## Install
```shell
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com `lsb_release -c -s` main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update -y
sudo apt-get install consul -y
```

## Configure

### Create unix user
```shell
rm -rf /etc/consul.d
mkdir /var/consul /etc/consul.d

useradd --system --home /etc/consul.d --shell /bin/false consul
chown -R consul /var/consul
```

### Download config (server)
```shell
curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/consul/server.json \
  -o /etc/consul.d/config.json
```

### Create systemd service
```shell
curl https://raw.githubusercontent.com/webitel/deployment/refs/heads/main/consul/consul.service \
  -o /etc/systemd/system/consul.service
```

### Generate keys
```shell
cd /etc/consul.d
consul keygen
```

## Run
```shell
systemctl enable consul
systemctl start consul
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
    