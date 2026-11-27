#!/usr/bin/env bash
# Runs roles/nomad/tasks/jobs.yml against a fake Nomad API per datacenter and
# checks which jobs are registered, with which Stop and stage.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

tmp=$(mktemp -d)
pids=()
trap 'kill "${pids[@]}" 2>/dev/null; rm -rf "${tmp}"' EXIT

for dc in a b; do
    python3 tests/fake_nomad.py --state "${tmp}/${dc}.json" --log "${tmp}/${dc}.log" \
        --port-file "${tmp}/${dc}.port" &
    pids+=($!)
done
for dc in a b; do
    for _ in $(seq 50); do [[ -s "${tmp}/${dc}.port" ]] && break; sleep 0.1; done
done

failed=0
fail() { echo "FAIL nomad-jobs $1"; failed=1; }

run() {
    ansible-playbook -i tests/fixtures/nomad-jobs/hosts.yml tests/nomad-jobs.yml \
        -e "dc_a_port=$(<"${tmp}/a.port") dc_b_port=$(<"${tmp}/b.port")" "$@" 2>&1
}

# json <dc> <python expression over the job map `j`>
json() {
    python3 -c 'import json, sys; j = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' \
        "${tmp}/$1.json" "$2"
}

clear_logs() {
    : >"${tmp}/a.log"
    : >"${tmp}/b.log"
}

reset() {
    echo '{}' >"${tmp}/a.json"
    echo '{}' >"${tmp}/b.json"
    clear_logs
}

reset
output=$(run -e primary_datacenter=dc_a) || fail "first run: ${output}"
[[ "$(json a "sorted(j)")" == "['freeswitch', 'nginx-vip', 'opensips', 'webitel-core', 'webitel-core-api']" ]] \
    || fail "active DC jobs: $(json a "sorted(j)")"
[[ "$(json a "[k for k, v in j.items() if v['Stop']]")" == "[]" ]] || fail "active DC has stopped jobs"
[[ "$(json b "sorted(k for k, v in j.items() if not v['Stop'])")" == "[]" ]] || fail "new jobs of an inactive DC are not stopped"
[[ "$(json b "len(j)")" == "5" ]] || fail "inactive DC jobs: $(json b "sorted(j)")"
[[ "$(json a "[j[k]['Meta']['dcctl_stage'] for k in ('freeswitch', 'webitel-core', 'opensips', 'webitel-core-api', 'nginx-vip')]")" \
    == "['1', '2', '3', '3', '3']" ]] || fail "stages: $(json a "[j[k]['Meta'] for k in j]")"
grep -q 'unit = "webitel-api.service"' <<<"$(json a "j['webitel-core-api']['HCL']")" || fail "webitel-core-api has no webitel-api unit"
grep -q 'webitel-api' <<<"$(json a "j['webitel-core']['HCL']")" && fail "webitel-core still runs webitel-api"
grep -q 'unit = "webitel-app.service"' <<<"$(json a "j['webitel-core']['HCL']")" || fail "webitel-core lost webitel-app"
[[ "$(json a "j['nginx-vip']['Type']")" == "service" ]] || fail "nginx-vip is not a service job"
[[ "$(json b "j['freeswitch']['Type']")" == "system" ]] || fail "freeswitch is not a system job"

# dcctl starts one job in the inactive DC and stops one in the active one; a repeated run leaves
# the first alone and starts the second again.
python3 - "${tmp}" <<'PY'
import json, sys
t = sys.argv[1]
for dc, job, stop in (("b", "freeswitch", False), ("a", "opensips", True)):
    path = f"{t}/{dc}.json"
    j = json.load(open(path))
    j[job]["Stop"] = stop
    json.dump(j, open(path, "w"))
PY
clear_logs
output=$(run -e primary_datacenter=dc_a) || fail "repeated run: ${output}"
[[ "$(json b "j['freeswitch']['Stop']")" == "False" ]] || fail "repeated run stopped a job dcctl started"
[[ "$(json b "sorted(k for k, v in j.items() if not v['Stop'])")" == "['freeswitch']" ]] || fail "repeated run changed other stopped jobs"
[[ ! -s "${tmp}/b.log" ]] || fail "repeated run registered jobs in the inactive DC: $(<"${tmp}/b.log")"
[[ "$(json a "j['opensips']['Stop']")" == "False" ]] || fail "active DC job was not started again"
[[ "$(grep -c . "${tmp}/a.log")" == "1" ]] || fail "active DC registrations: $(<"${tmp}/a.log")"

# A changed job in an inactive DC keeps its Stop and is registered against the current index.
python3 - "${tmp}" <<'PY'
import json, sys
path = f"{sys.argv[1]}/b.json"
j = json.load(open(path))
j["opensips"]["Meta"]["dcctl_stage"] = "9"
j["opensips"]["Stop"] = False
json.dump(j, open(path, "w"))
PY
clear_logs
output=$(run -e primary_datacenter=dc_a) || fail "changed job run: ${output}"
[[ "$(json b "(j['opensips']['Stop'], j['opensips']['Meta']['dcctl_stage'])")" == "(False, '3')" ]] \
    || fail "changed job in inactive DC: $(json b "j['opensips']['Meta']")"
grep -q '"enforce": true' "${tmp}/b.log" || fail "inactive DC registration does not enforce the index"

# No active datacenter known: new jobs are stopped everywhere.
reset
output=$(run) || fail "run without active datacenter: ${output}"
[[ "$(json a "sorted(k for k, v in j.items() if not v['Stop'])")" == "[]" ]] || fail "unknown active DC started jobs"
[[ "$(json b "len(j)")" == "5" ]] || fail "unknown active DC jobs missing"

# An explicit active_datacenter wins over primary_datacenter.
reset
output=$(run -e primary_datacenter=dc_a -e active_datacenter=dc_b) || fail "active_datacenter run: ${output}"
[[ "$(json b "sorted(k for k, v in j.items() if v['Stop'])")" == "[]" ]] || fail "active_datacenter: dc_b has stopped jobs"
[[ "$(json a "sorted(k for k, v in j.items() if not v['Stop'])")" == "[]" ]] || fail "active_datacenter: dc_a has running jobs"

# A system job cannot be pinned to a node name.
reset
if output=$(run -e primary_datacenter=dc_a -e '{"nomad_jobs_node_constraints": {"freeswitch": ["n1"]}}'); then
    fail "node constraint on a system job was accepted"
fi
grep -qF "cannot be pinned" <<<"${output}" || fail "node constraint message: ${output}"

[[ "${failed}" -eq 0 ]] && echo "ok   nomad-jobs"
exit "${failed}"
