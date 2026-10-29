DOCUMENTATION = r"""
name: webitel_services
short_description: YAML inventory whose hosts declare the services they run
description:
  - Parses the file like ansible.builtin.yaml and puts each host into the
    groups named in its C(services) list.
  - Declares every service from roles/topology/vars/services.yml as a group.
  - Sets C(datacenter=dc1) on the C(all) group unless the file sets it there.
options:
  yaml_extensions:
    description: list of 'valid' extensions for files containing YAML
    type: list
    elements: string
    default: ['.yaml', '.yml', '.json']
    env:
      - name: ANSIBLE_YAML_FILENAME_EXT
      - name: ANSIBLE_INVENTORY_PLUGIN_EXTS
    ini:
      - key: yaml_valid_extensions
        section: defaults
      - section: inventory_plugin_yaml
        key: yaml_valid_extensions
"""

import os

from ansible.inventory.helpers import get_group_vars
from ansible.plugins.inventory.yaml import InventoryModule as YamlInventoryModule
from ansible.utils.vars import combine_vars

CATALOG = os.path.join(os.path.dirname(__file__), "..", "..", "roles", "topology", "vars", "services.yml")


class InventoryModule(YamlInventoryModule):
    NAME = "webitel_services"

    def parse(self, inventory, loader, path, cache=True):
        super().parse(inventory, loader, path, cache)

        if "datacenter" not in inventory.groups["all"].get_vars():
            inventory.set_variable("all", "datacenter", "dc1")

        for service in loader.load_from_file(CATALOG)["webitel_services"]:
            inventory.add_group(service)

        for host in list(inventory.hosts.values()):
            host_vars = combine_vars(get_group_vars(host.get_groups()), host.get_vars())
            for service in host_vars.get("services") or []:
                inventory.add_group(service)
                inventory.add_host(host.name, group=service)
