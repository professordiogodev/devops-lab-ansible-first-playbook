#!/usr/bin/env bash
rc=0
for f in ansible.cfg inventory.ini site.yml templates/pollie.conf.j2; do
  if [ -s "$f" ]; then echo "- ✅ $f exists"; else echo "- ❌ $f is missing or empty"; rc=1; fi
done
if grep -vE '^\s*#|^\s*$' inventory.ini 2>/dev/null | grep -q '\[web\]'; then echo "- ✅ inventory.ini defines the groups"; else echo "- ❌ inventory.ini has no [web] group yet"; rc=1; fi
if python3 .lab/no_shell.py; then echo "- ✅ site.yml uses modules only"; else echo "- ❌ site.yml uses shell/command/raw/script: use modules"; rc=1; fi
if grep -q 'handlers:' site.yml 2>/dev/null && grep -q 'notify:' site.yml 2>/dev/null; then echo "- ✅ site.yml has a handler and notifies it"; else echo "- ❌ site.yml needs a handler (handlers:) and a notify:"; rc=1; fi
grep -qE '^ALL CHECKS PASSED \(' SUBMISSION.md && echo "- ✅ SUBMISSION.md shows ALL CHECKS PASSED" || { echo "- ❌ paste the verify.sh output ('ALL CHECKS PASSED') into SUBMISSION.md"; rc=1; }
exit $rc
