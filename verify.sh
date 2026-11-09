#!/usr/bin/env bash
# Run with: ./verify.sh   (it applies your playbook, so it takes a minute)
cd "$(dirname "$0")"
command -v ansible-playbook >/dev/null || { echo "Ansible is not installed (try: pipx install ansible-core)"; exit 1; }
docker inspect pa-web >/dev/null 2>&1 || { echo "Run ./setup.sh first (or the lab was already torn down)"; exit 1; }
pass=0; failn=0; total=0
check() { local d="$1"; shift; total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
on() { local h=$1; shift; docker exec "$h" sh -c "$*"; }
export ANSIBLE_FORCE_COLOR=0 ANSIBLE_NOCOLOR=1
# a PLAY RECAP line per host: ok=.. changed=.. unreachable=.. failed=..
clean3()   { [ "$(echo "$1" | grep 'ok=' | grep -c 'changed=0 .*unreachable=0 .*failed=0')" = 3 ]; }
changed3() { [ "$(echo "$1" | grep 'ok=' | grep -vc 'changed=0 ')" = 3 ] && ! echo "$1" | grep 'ok=' | grep -q 'failed=[1-9]'; }

echo "== Inventory and connection =="
check "ansible.cfg points at inventory.ini" bash -c "grep -Eq '^[[:space:]]*inventory[[:space:]]*=' ansible.cfg"
check "groups web, app, db hold pa-web, pa-app, pa-db and 'servers' holds all three" bash -c "ansible-inventory --list 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
def hosts(g):
    out=set(d.get(g,{}).get(\"hosts\",[]))
    for c in d.get(g,{}).get(\"children\",[]): out|=hosts(c)
    return out
ok = hosts(\"web\")=={\"pa-web\"} and hosts(\"app\")=={\"pa-app\"} and hosts(\"db\")=={\"pa-db\"} and hosts(\"servers\")=={\"pa-web\",\"pa-app\",\"pa-db\"}
sys.exit(0 if ok else 1)'"
check "ansible all -m ping reaches all three servers" bash -c "[ \"\$(ansible all -m ping 2>/dev/null | grep -c SUCCESS)\" = 3 ]"

echo "== Playbook =="
check "site.yml passes --syntax-check" ansible-playbook site.yml --syntax-check
check "site.yml uses modules, not shell/command/raw" python3 .lab/no_shell.py
check "site.yml has a handler and notifies it" bash -c "grep -q 'handlers:' site.yml && grep -q 'notify:' site.yml"
check "site.yml uses the template module" bash -c "grep -Eq '(ansible\.builtin\.)?template:' site.yml"
run1=$(ansible-playbook site.yml 2>&1); rc1=$?
check "the playbook applies without errors" bash -c "[ $rc1 -eq 0 ]"
run2=$(ansible-playbook site.yml 2>&1)
check "second run changes nothing (idempotent): changed=0 and failed=0 on all hosts" clean3 "$run2"
check "--check mode reports no changes" clean3 "$(ansible-playbook site.yml --check 2>&1)"

echo "== Baseline on all three servers =="
for h in pa-web pa-app pa-db; do
  check "$h: curl, htop and jq are installed" on $h 'dpkg -s curl htop jq'
  check "$h: user pollie exists with no login shell" on $h 'getent passwd pollie | grep -Eq "nologin|/bin/false"'
  check "$h: /opt/pollie belongs to pollie" on $h '[ "$(stat -c %U /opt/pollie)" = pollie ]'
  check "$h: /etc/motd says Managed by Ansible and names $h" on $h "grep -q 'Managed by Ansible' /etc/motd && grep -q $h /etc/motd"
done

echo "== Web server =="
check "nginx is running and enabled on pa-web" on pa-web 'systemctl is-active nginx && systemctl is-enabled nginx'
check "nginx configuration is valid (nginx -t)" on pa-web 'nginx -t'
check "Ubuntu's default site is gone" on pa-web 'dpkg -s nginx && [ ! -e /etc/nginx/sites-enabled/default ]'
check "the site config is /etc/nginx/conf.d/pollie.conf and is marked as managed" on pa-web 'grep -qi "ansible" /etc/nginx/conf.d/pollie.conf'
check "http://localhost:8080 serves Pollie" bash -c "curl -s --max-time 5 localhost:8080 | grep -q '<title>Pollie</title>'"
check "the page carries X-Served-By: pa-web" bash -c "curl -sI --max-time 5 localhost:8080 | tr -d '\r' | grep -qi '^X-Served-By: pa-web\$'"
check "the app and db servers do not have nginx" bash -c "! docker exec pa-app dpkg -s nginx && ! docker exec pa-db dpkg -s nginx"

echo "== Drift: three people logged in to fix one thing =="
./drift.sh >/dev/null 2>&1
drift_check=$(ansible-playbook site.yml --check 2>&1)
check "--check notices the drift on all three servers" changed3 "$drift_check"
fix=$(ansible-playbook site.yml 2>&1)
check "applying the playbook repairs it and runs the Nginx handler" bash -c "echo \"\$1\" | grep -q 'RUNNING HANDLER'" _ "$fix"
check "the hand-edited web config is back (X-Served-By again)" bash -c "curl -sI --max-time 5 localhost:8080 | tr -d '\r' | grep -qi '^X-Served-By: pa-web\$'"
check "the motd on pa-app is back" on pa-app 'grep -q "Managed by Ansible" /etc/motd'
check "jq is back on pa-db" on pa-db 'dpkg -s jq'
check "and a run after the repair changes nothing again" clean3 "$(ansible-playbook site.yml 2>&1)"

echo
if [ "$failn" -eq 0 ]; then echo "ALL CHECKS PASSED ($pass/$total)"; else echo "$failn check(s) failed, $pass passed. Fix the FAIL lines and run ./verify.sh again."; fi
exit "$failn"
