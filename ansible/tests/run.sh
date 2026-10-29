#!/usr/bin/env bash
# Runs playbooks/validate_topology.yml against every fixture listed in
# tests/cases.txt and compares exit code and message with the expectation.
# Needs no SSH or managed hosts.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

failed=0
while IFS='|' read -r fixture expected_rc expected_msg; do
    [[ -z "${fixture// }" || "${fixture}" == \#* ]] && continue
    inventory="tests/fixtures/${fixture}"
    [[ -d "${inventory}" ]] || inventory="${inventory}.yml"
    output=$(ansible-playbook -i "${inventory}" playbooks/validate_topology.yml 2>&1)
    rc=$?
    if [[ "${rc}" -ne "${expected_rc}" ]]; then
        echo "FAIL ${fixture}: rc=${rc}, expected ${expected_rc}"
        echo "${output}" | tail -20
        failed=1
        continue
    fi
    if [[ -n "${expected_msg// }" ]] && ! grep -qF "${expected_msg}" <<<"${output}"; then
        echo "FAIL ${fixture}: output does not contain '${expected_msg}'"
        echo "${output}" | tail -20
        failed=1
        continue
    fi
    echo "ok   ${fixture}"
done < tests/cases.txt

canary='Canary-7f3a9c-secret'
output=$(ansible-playbook -v -i tests/fixtures/valid-secret-not-logged.yml \
    playbooks/validate_topology.yml 2>&1)
rc=$?
if [[ "${rc}" -ne 0 ]]; then
    echo "FAIL secret-not-logged: rc=${rc}, expected 0"
    echo "${output}" | tail -20
    failed=1
elif grep -qF "${canary}" <<<"${output}"; then
    echo "FAIL secret-not-logged: -v output contains a secret value"
    grep -F "${canary}" <<<"${output}" | head -5 | cut -c1-200
    failed=1
else
    echo "ok   secret-not-logged"
fi

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
for inv in inventories/*.example; do
    copy="${tmp}/$(basename "${inv}")"
    cp -R "${inv}" "${copy}"
    rm -f "${copy}/group_vars/all/vault.yml"
    if ! output=$(ansible-playbook -i "${copy}" playbooks/validate_topology.yml 2>&1); then
        echo "FAIL ${inv}: validate_topology.yml without vault.yml"
        echo "${output}" | tail -20
        failed=1
        continue
    fi
    echo "ok   ${inv}: validate"
done

# Service groups built by plugins/inventory/webitel_services.
if ! python3 -c 'import yaml' 2>/dev/null; then
    echo "FAIL service groups: python3 has no PyYAML"
    exit 1
fi
for inv in inventories/*.example; do
    if ! ansible-inventory -i "${inv}" --list 2>/dev/null | python3 -c '
import json, sys, yaml
catalog = set(yaml.safe_load(open("roles/topology/vars/services.yml"))["webitel_services"])
inv = json.load(sys.stdin)
members = {g: set(v.get("hosts", [])) for g, v in inv.items() if g != "_meta"}
missing = sorted(catalog - set(inv["all"]["children"]))
wrong = sorted(f"{h}->{s}" for h, hv in inv["_meta"]["hostvars"].items()
               for s in hv.get("services", []) if h not in members.get(s, set()))
if missing or wrong:
    print(f"missing groups {missing}, hosts not grouped {wrong}")
    sys.exit(1)
'; then
        echo "FAIL ${inv}: service groups"
        failed=1
        continue
    fi
    echo "ok   ${inv}: service groups"
done

exit "${failed}"
