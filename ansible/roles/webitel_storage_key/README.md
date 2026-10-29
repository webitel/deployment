# Role: webitel_storage_key

Generates the `webitel-storage` URL-signing key once on the Ansible controller and copies it to every consuming host (storage, engine, flow_manager) in all datacenters.

## Overview

`webitel-storage`, `webitel-engine` and `webitel-flow-manager` read the RSA URL-signing key at `/opt/storage/key.pem`.

- The key is created once on the controller under `webitel_storage_key_local_path` (defaults to `{{ inventory_dir }}/storage/key.pem`), in **PKCS#1** format.
- It is copied to `webitel_storage_key_remote_path` (`/opt/storage/key.pem`) on each host, owned by the User/Group of the consumer unit (fallback `webitel_storage_key_owner:webitel_storage_key_group`), mode `0600`.
- When the key changes, affected units on the host are restarted; under nomad (`nomad_managed`) only units active on this node. The consumer units are the catalog units (`roles/topology/vars/services.yml`) of the services in `webitel_storage_key_services`.

**Important:** The signing key is stored only on the controller in `webitel_storage_key_local_path`, excluded from version control via `.gitignore` (`inventories/*/storage/`). Losing it invalidates all previously signed URLs. Back it up securely.

## Requirements

Collection `community.crypto` (listed in `requirements.yml`) and the Python `cryptography` package must be installed on the controller.

## Variables

See `defaults/main.yml` for configurable variables.

## Tags

Tag: `webitel_storage_key` (run_once, controller-side generation + distribution).

## Usage

Applied as the final play in `playbooks/webitel.yml`, after the service plays.

```yaml
- name: Webitel storage signing key
  hosts: webitel_storage:webitel_engine:webitel_flow_manager
  become: true
  roles:
    - { role: webitel_storage_key, tags: [webitel_storage_key] }
```
