#!/usr/bin/env bash
# Creates the three servers. Run:  ./setup.sh   (needs Docker, git and ssh-keygen)
set -uo pipefail
cd "$(dirname "$0")"
LAB=ansible-first-playbook
for c in docker git ssh-keygen; do command -v "$c" >/dev/null || { echo "$c is not installed or not on PATH"; exit 1; }; done
docker info >/dev/null 2>&1 || { echo "Docker is not running (or your user may not use it). Start Docker and try again."; exit 1; }
if docker ps -a --filter label=lab=$LAB -q | grep -q .; then
  echo "The lab is already set up. Run ./teardown.sh first if you want to start over."; exit 1
fi
for port in 2221 2222 2223 8080; do
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then echo "Port $port is in use on your machine. Free it first."; exit 1; fi
done

echo "Getting the Pollie web app (v0.1.1)..."
if [ ! -d pollie ]; then
  git clone -q -c advice.detachedHead=false --depth 1 --branch v0.1.1 https://github.com/professordiogodev/pollie.git pollie || { echo "could not clone pollie"; exit 1; }
fi

echo "Building the server image (first run takes a minute)..."
docker build -q -t pollie-node:lab servers >/dev/null || { echo "image build failed"; exit 1; }

echo "Creating an SSH key for the lab (keys/id_ed25519)..."
mkdir -p keys
[ -f keys/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -C ansible-lab -f keys/id_ed25519
chmod 600 keys/id_ed25519

docker network create --label lab=$LAB pa-net >/dev/null

start() { # name sshport extra-args
  local name=$1 port=$2; shift 2
  docker run -d --name "$name" --hostname "$name" --label lab=$LAB --network pa-net \
    --privileged --cgroupns=host --tmpfs /run --tmpfs /run/lock \
    -p "127.0.0.1:$port:22" "$@" pollie-node:lab >/dev/null || { echo "could not start $name"; exit 1; }
}
start pa-web 2221 -p 127.0.0.1:8080:80
start pa-app 2222
start pa-db  2223

for name in pa-web pa-app pa-db; do
  n=0
  until docker exec "$name" systemctl is-active ssh >/dev/null 2>&1; do
    n=$((n+1)); [ $n -gt 40 ] && { echo "$name did not boot"; exit 1; }; sleep 1
  done
  docker exec "$name" sh -c 'mkdir -p /home/deploy/.ssh && chmod 700 /home/deploy/.ssh'
  docker cp keys/id_ed25519.pub "$name:/home/deploy/.ssh/authorized_keys"
  docker exec "$name" sh -c 'chown -R deploy:deploy /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys'
done

cat <<TXT

Three fresh Ubuntu 24.04 servers are running. Nothing is installed on them.

  name     SSH (from your machine)                       also published
  pa-web   127.0.0.1 port 2221                           http://localhost:8080 -> port 80 in the server
  pa-app   127.0.0.1 port 2222
  pa-db    127.0.0.1 port 2223

  user: deploy (passwordless sudo)     key: keys/id_ed25519

Try it by hand first:  ssh -i keys/id_ed25519 -p 2221 deploy@127.0.0.1
(Add  -o StrictHostKeyChecking=no  if SSH complains about an unknown or changed host key: the servers are new every time.)
TXT
