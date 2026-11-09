#!/usr/bin/env bash
# Simulates three people logging in to "just fix one thing". Run:  ./drift.sh
set -uo pipefail
docker inspect pa-web >/dev/null 2>&1 || { echo "Run ./setup.sh first"; exit 1; }
# 1. Somebody edits the web config by hand and leaves a note.
docker exec pa-web sh -c '[ -f /etc/nginx/conf.d/pollie.conf ] && { sed -i "s/X-Served-By/X-Edited-By-Hand/" /etc/nginx/conf.d/pollie.conf; echo "# quick fix, TODO tell the team" >> /etc/nginx/conf.d/pollie.conf; }' 
# 2. Somebody deletes the message of the day because "it is annoying".
docker exec pa-app rm -f /etc/motd
# 3. Somebody removes a package "to free some space".
docker exec pa-db sh -c 'apt-get remove -y -qq jq >/dev/null 2>&1'
echo "Done. Three servers drifted away from what your playbook says. Find out what changed, then fix it with Ansible, not by hand."
