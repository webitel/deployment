#!/usr/bin/env bash
# Runs roles/nomad/tasks/jobs.yml against a fake Nomad API per datacenter and
# checks which jobs are registered, with which Stop and stage.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fixtures=tests/fixtures/nomad-jobs
tmp=$(mktemp -d)
pids=()
trap 'kill "${pids[@]}" 2>/dev/null; rm -rf "${tmp}"' EXIT

dcs=(a b c)
for dc in "${dcs[@]}"; do
    python3 tests/fake_nomad.py --state "${tmp}/${dc}.json" --log "${tmp}/${dc}.log" \
        --port-file "${tmp}/${dc}.port" &
    pids+=($!)
done
for dc in "${dcs[@]}"; do
    for _ in $(seq 50); do [[ -s "${tmp}/${dc}.port" ]] && break; sleep 0.1; done
done

failed=0
fail() { echo "FAIL nomad-jobs $1"; failed=1; }

# Inventory files of the current scenario.
inv=()

run() {
    ansible-playbook "${inv[@]}" tests/nomad-jobs.yml \
        -e "dc_a_port=$(<"${tmp}/a.port") dc_b_port=$(<"${tmp}/b.port") dc_c_port=$(<"${tmp}/c.port")" "$@" 2>&1
}

# json <dc> <python expression over the job map `j`; service(hcl) is the meta.services constraint value>
json() {
    python3 -c '
import json, re, sys
j = json.load(open(sys.argv[1]))
def service(hcl):
    return re.search(r"meta.services}\"\s+operator\s+=\s+\"set_contains\"\s+value\s+=\s+\"(\w+)\"", hcl).group(1)
print(eval(sys.argv[2]))' "${tmp}/$1.json" "$2"
}

running() { json "$1" "sorted(k for k, v in j.items() if not v['Stop'])"; }
stopped() { json "$1" "sorted(k for k, v in j.items() if v['Stop'])"; }

all_jobs="['freeswitch', 'opensips', 'webitel-core', 'webitel-core-api']"
no_jobs="[]"

clear_logs() {
    for dc in "${dcs[@]}"; do : >"${tmp}/${dc}.log"; done
}

reset() {
    for dc in "${dcs[@]}"; do echo '{}' >"${tmp}/${dc}.json"; done
    clear_logs
}

# set_job <dc> <job> <python statement over the job `job`>
set_job() {
    python3 - "${tmp}/$1.json" "$2" "$3" <<'PY'
import json, sys
path, name, stmt = sys.argv[1:]
j = json.load(open(path))
job = j[name]
exec(stmt)
json.dump(j, open(path, "w"))
PY
}

expect() {
    [[ "$2" == "$3" ]] || fail "$1: got $2, expected $3"
}

# --- Two datacenters, dcctl present: only active_datacenter runs ---
inv=(-i "${fixtures}/hosts.yml" -i "${fixtures}/dcctl.yml")
reset
output=$(run -e active_datacenter=dc_a) || fail "first run: ${output}"
expect "active DC jobs" "$(json a "sorted(j)")" "${all_jobs}"
expect "active DC stopped jobs" "$(stopped a)" "${no_jobs}"
expect "inactive DC jobs" "$(json b "sorted(j)")" "${all_jobs}"
expect "inactive DC running jobs" "$(running b)" "${no_jobs}"
expect "stages" "$(json a "[j[k]['Meta']['dcctl_stage'] for k in ('freeswitch', 'webitel-core', 'opensips', 'webitel-core-api')]")" \
    "['1', '2', '3', '3']"
# Every job must be placeable: its meta.services constraint names a service some client lists.
expect "job constraints" "$(json a "sorted({service(v['HCL']) for v in j.values()})")" "['freeswitch', 'opensips', 'webitel_core']"
expect "webitel-core-api unit" "$(json a "re.findall(r'unit += \"(.*)\"', j['webitel-core-api']['HCL'])")" "['webitel-api.service']"
expect "webitel-core units" "$(json a "re.findall(r'unit += \"(.*)\"', j['webitel-core']['HCL'])")" \
    "['webitel-app.service', 'webitel-uac.service']"
expect "nomad.type of freeswitch" "$(json b "j['freeswitch']['Type']")" "system"
for dc in a b; do
    expect "dc_${dc} registrations enforce the index" \
        "$(grep -c '"enforce": true' "${tmp}/${dc}.log")/$(grep -c . "${tmp}/${dc}.log")" "4/4"
done

# dcctl starts a job in the inactive DC and stops one in the active DC. A repeated run leaves the
# first alone and starts the second again.
set_job b freeswitch "job['Stop'] = False"
set_job a opensips "job['Stop'] = True"
clear_logs
output=$(run -e active_datacenter=dc_a) || fail "repeated run: ${output}"
expect "repeated run keeps a started job in the inactive DC" "$(running b)" "['freeswitch']"
[[ ! -s "${tmp}/b.log" ]] || fail "repeated run registered jobs in the inactive DC: $(<"${tmp}/b.log")"
expect "repeated run starts a stopped job in the active DC" "$(stopped a)" "${no_jobs}"
expect "repeated run registrations in the active DC" "$(grep -c . "${tmp}/a.log")" "1"

# A changed job in an inactive DC keeps its Stop.
set_job b opensips "job['Meta']['dcctl_stage'] = '9'; job['Stop'] = False"
clear_logs
output=$(run -e active_datacenter=dc_a) || fail "changed job run: ${output}"
expect "changed job in inactive DC" "$(json b "(j['opensips']['Stop'], j['opensips']['Meta']['dcctl_stage'])")" "(False, '3')"

# A job changed between the read and the registration is a failure that says what to do.
set_job b opensips "job['Meta']['dcctl_stage'] = '9'"
touch "${tmp}/b.json.bump"
if output=$(run -e active_datacenter=dc_a); then
    fail "conflicting registration was accepted"
fi
grep -qF "changed during the run" <<<"${output}" || fail "conflict message: ${output}"
rm "${tmp}/b.json.bump"

# --- Two datacenters, no dcctl: every datacenter runs, as before dcctl ---
inv=(-i "${fixtures}/hosts.yml")
reset
output=$(run) || fail "run without dcctl: ${output}"
expect "no dcctl, dc_a stopped jobs" "$(stopped a)" "${no_jobs}"
expect "no dcctl, dc_b stopped jobs" "$(stopped b)" "${no_jobs}"
expect "no dcctl, dc_b jobs" "$(json b "sorted(j)")" "${all_jobs}"
reset
output=$(run -e active_datacenter=dc_a) || fail "run without dcctl and with active_datacenter: ${output}"
expect "no dcctl ignores active_datacenter" "$(stopped b)" "${no_jobs}"

# --- Two datacenters with dcctl but no active_datacenter: nothing starts, nothing is touched ---
inv=(-i "${fixtures}/hosts.yml" -i "${fixtures}/dcctl.yml")
for extra in "" "-e active_datacenter="; do
    reset
    # shellcheck disable=SC2086
    output=$(run ${extra}) || fail "run without active DC (${extra}): ${output}"
    expect "unknown active DC (${extra}), dc_a running jobs" "$(running a)" "${no_jobs}"
    expect "unknown active DC (${extra}), dc_b running jobs" "$(running b)" "${no_jobs}"
    expect "unknown active DC (${extra}), dc_b jobs" "$(json b "sorted(j)")" "${all_jobs}"
done
set_job b freeswitch "job['Stop'] = False"
set_job a opensips "job['Stop'] = False"
clear_logs
output=$(run) || fail "repeated run without active DC: ${output}"
expect "unknown active DC keeps a started job in dc_b" "$(running b)" "['freeswitch']"
expect "unknown active DC keeps a started job in dc_a" "$(running a)" "['opensips']"
[[ ! -s "${tmp}/a.log" && ! -s "${tmp}/b.log" ]] || fail "repeated run without active DC registered jobs"

# A stale primary_datacenter is not read: dc_a stays as dcctl left it.
reset
output=$(run -e primary_datacenter=dc_a) || fail "run with primary_datacenter: ${output}"
expect "primary_datacenter is ignored" "$(running a)" "${no_jobs}"
set_job a webitel-core "job['Stop'] = True"
clear_logs
output=$(run -e primary_datacenter=dc_a) || fail "repeated run with primary_datacenter: ${output}"
[[ ! -s "${tmp}/a.log" ]] || fail "stale primary_datacenter restarted dc_a jobs: $(<"${tmp}/a.log")"

# --- One datacenter runs, with or without dcctl ---
for single in "-i ${fixtures}/single.yml" "-i ${fixtures}/single.yml -i ${fixtures}/dcctl.yml"; do
    # shellcheck disable=SC2206
    inv=(${single})
    reset
    output=$(run) || fail "single datacenter run (${single}): ${output}"
    expect "single datacenter (${single}) running jobs" "$(running a)" "${all_jobs}"
done

# --- stretch: three datacenters with dcctl ---
inv=(-i "${fixtures}/stretch.yml")
reset
output=$(run) || fail "stretch run: ${output}"
for dc in a b c; do
    expect "stretch without active_datacenter, dc_${dc} running jobs" "$(running ${dc})" "${no_jobs}"
    expect "stretch without active_datacenter, dc_${dc} jobs" "$(json ${dc} "sorted(j)")" "${all_jobs}"
done
reset
output=$(run -e active_datacenter=dc_b) || fail "stretch run with active_datacenter: ${output}"
expect "stretch active dc_b running jobs" "$(running b)" "${all_jobs}"
expect "stretch dc_a running jobs" "$(running a)" "${no_jobs}"
expect "stretch dc_c running jobs" "$(running c)" "${no_jobs}"

# --- Settings that must be refused ---
inv=(-i "${fixtures}/hosts.yml")
reset
if output=$(run -e '{"nomad_jobs_node_constraints": {"freeswitch": ["n1"]}}'); then
    fail "node constraint on a system job was accepted"
fi
grep -qF "cannot be pinned" <<<"${output}" || fail "node constraint message: ${output}"
for stage in 1.5 3.0 true 0 ""; do
    reset
    if output=$(run -e "{\"nomad_jobs_stages\": {\"opensips\": \"${stage}\"}}"); then
        fail "stage '${stage}' was accepted"
    fi
    grep -qF "nomad.stage must be an integer" <<<"${output}" || fail "stage '${stage}' message: ${output}"
done

[[ "${failed}" -eq 0 ]] && echo "ok   nomad-jobs"
exit "${failed}"
