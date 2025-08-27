# Webitel v25.05

This repository provides infrastructure assets to deploy a Webitel-based real-time communications stack. 
It supports two installation approaches:
- [Automated provisioning with Ansible (recommended)](#option-a-install-with-ansible-recommended)
- [Manual installation (component-by-component)](#option-b-manual-installation)

> [!TIP]
> Use this repository to provision a production-like environment or to bootstrap a lab.

---

## Prerequisites

See requirements for your deployment type:
- [Basic Architecture of the Industrial Environment](https://webitel.atlassian.net/wiki/x/6wNeAQ): suits for average load of up to 400 thousand calls per day (250-350 simultaneous calls with call recording) and about 100 thousand chats per day.
- [Extended Architecture of the Industrial Environment](https://webitel.atlassian.net/wiki/x/3ANeAQ): 400-500 simultaneous calls (about 1 million calls per day) and from 200 thousand chats per day.

## Install

### Option A: Install with Ansible (recommended)

Detailed guide: see [ansible/README.md](./ansible/README.md).

### Option B: Manual installation

Install and configure each component in the order below one-by-one. 

> [!TIP]
> Use the corresponding directory for configuration examples, service files, and guidance.

- [PostgreSQL](./postgresql)
- [RabbitMQ](./rabbitmq)
- [Consul service discovery](./consul)
- [OpenSIPs](./opensips)
- [RTPEngine](./rtpengine)
- [Webitel services](./webitel)
- [FreeSWITCH](./freeswitch)
- [NGINX](./nginx)

## Get started

- [Guides](https://webitel.atlassian.net/wiki/x/zQJeAQ)
- [Basic Installation](https://webitel.atlassian.net/wiki/x/AQNeAQ)
- [Webitel Mobile App](https://webitel.atlassian.net/wiki/x/Xg5eAQ)
- [Terms and Conditions](https://webitel.atlassian.net/wiki/x/JwCfIg)

The full Webitel documentation is available at [webitel.atlassian.net/wiki](https://webitel.atlassian.net/wiki/spaces/WEP/overview).

## Get involved

- Follow [@news on Mastodon](https://social.webitel.me/@news) or [@webitel on Telegram](https://t.me/webitel).
- Read and subscribe to the [Webitel Medium blog](https://medium.com/@webitel).
- If you have a specific question, check out our [Support Portal](https://cs.my.webitel.com/).