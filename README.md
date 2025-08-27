# Webitel Deployment (v25.05)

This repository provides infrastructure assets to deploy a Webitel-based real-time communications stack. 
It supports two installation approaches:
- Automated provisioning with Ansible (recommended)
- Manual installation (component-by-component)

The stack includes:
- Webitel core services (applications, APIs, workers)
- SIP proxy: OpenSIPS
- RTP media proxy: rtpengine
- Database: PostgreSQL
- Message broker: RabbitMQ
- Service discovery/kv: Consul
- Edge proxy: NGINX

> [!TIP]
> Use this repository to provision a production-like environment or to bootstrap a lab.

---

## Prerequisites

- Linux hosts (e.g., Debian) with root or sudo privileges
- Proper DNS/hostnames for SIP, media, APIs, and web endpoints
- Open firewall ports:
  - SIP (e.g., 5060/5061 TCP/UDP) and media RTP ranges (UDP)
  - Web/API (80/443 TCP)
  - DB/Broker/Discovery
- Time sync (NTP/chrony)
- For TLS: valid server certificates or ACME support

## Install

### Option A: Install with Ansible (recommended)

Detailed guide: see [ansible/README.md](./ansible/README.md).

### Option B: Manual installation

Install and configure each component in the order below. Use the corresponding directory for configuration examples, service files, and guidance.

1. PostgreSQL
   - Install PostgreSQL, create databases/users, tune memory and I/O.
   - Apply schema and ensure secure auth (pg_hba.conf).
   - See: [postgresql/](./postgresql)

2. RabbitMQ
   - Install broker, create vhosts/users, configure policies (HA/mirroring), TLS if required.
   - See: [rabbitmq/](./rabbitmq)

3. Consul (optional but recommended)
   - Deploy agents/servers for service discovery and health checks.
   - See: [consul/](./consul)

4. OpenSIPS
   - Install OpenSIPS, configure SIP listeners, routing logic, auth/registrar, and failover.
   - Integrate with Webitel and Consul (if used).
   - See: [opensips/](./opensips)

5. rtpengine
   - Install rtpengine, configure media ports and advertised/public addresses (NAT).
   - Connect to OpenSIPS and ensure kernel/modules are present where required.
   - See: [rtpengine/](./rtpengine)

6. Webitel services
    - Deploy core applications, set environment/config for DB/Broker/Consul endpoints.
    - Configure domains, routing, and any required licensing/config secrets.
    - See: [webitel/](./webitel)

7. FreeSWITCH
    - Deploy FreeSWITCH, configure SIP listeners.
    - Integrate with Webitel and Consul.
    - See: [freeswitch/](./freeswitch)

8. NGINX
   - Configure TLS termination, upstreams to Webitel APIs/UI and auxiliary endpoints.
   - Add rate limiting, security headers, and observability as appropriate.
   - See: [nginx/](./nginx)

9. Validation
   - Confirm SIP registration and basic call flows (B2BUA/proxy → media).
   - Verify Web/API health via NGINX.
   - Inspect logs and metrics for DB/Broker/Discovery and media paths.

## Documentation

The Webitel documentation is available at [webitel.atlassian.net/wiki](https://webitel.atlassian.net/wiki/spaces/WEP/overview).

## Get involved

- Follow [@news on Mastodon](https://social.webitel.me/@news) or [@webitel on Telegram](https://t.me/webitel).
- Read and subscribe to the [Webitel Medium blog](https://medium.com/@webitel).
- If you have a specific question, check out our [Support Portal](https://cs.my.webitel.com/).