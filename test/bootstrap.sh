#!/usr/bin/env bash
# The bootstrap playbook, run from damstack-toolbox against a fresh Ubuntu 24.04
# server with systemd for each scenario.
set -euo pipefail

stack=$(cd "$(dirname "$0")/.." && pwd)
toolbox=${TOOLBOX:-ghcr.io/eugene-panin/damstack-toolbox:1.0.0}
run=$$
net=damstack-bootstrap-$run
mkdir -p "$HOME/.cache"
work=$(mktemp -d "$HOME/.cache/damstack-bootstrap.XXXXXX")
cleanup() {
  if [[ -n ${KEEP_LOGS:-} ]]; then mkdir -p "$KEEP_LOGS" && cp "$work"/*.log "$KEEP_LOGS"/ 2>/dev/null; fi
  docker ps -aq --filter "label=damstack-bootstrap=$run" | xargs -r docker rm -f >/dev/null
  docker network rm "$net" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

step() { printf '\n== %s\n' "$*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

ssh-keygen -q -t ed25519 -N "" -C damstack-test -f "$work/key"
ssh-keygen -q -t ed25519 -N "" -C someone-else -f "$work/other"
docker build -q -t damstack-bootstrap-target "$stack/test/bootstrap" >/dev/null
docker network create "$net" >/dev/null

tool() {
  docker run --rm --network "$net" --user "$(id -u):$(id -g)" \
    -v "$stack:/stack:ro" -v "$work:/work" \
    -e ANSIBLE_CONFIG=/stack/ansible/ansible.cfg -e ANSIBLE_COLLECTIONS_PATH=/work/collections \
    -e ANSIBLE_SSH_ARGS="-F /dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
    -e "DAMSTACK_SSH_PUBLIC_KEY=$(cat "$work/key.pub")" "$@"
}

tool "$toolbox" ansible-galaxy collection install -r /stack/ansible/requirements.yml -p /work/collections >/dev/null

# target <name>: a fresh server that root logs in to with the test key
target() {
  docker run -d --name "$1-$run" --hostname "$1" --network "$net" --network-alias "$1" \
    --label "damstack-bootstrap=$run" --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    damstack-bootstrap-target >/dev/null
  for _ in $(seq 60); do
    docker exec "$1-$run" systemctl is-active --quiet ssh 2>/dev/null && break
    sleep 1
  done
  docker exec -i "$1-$run" sh -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' <"$work/key.pub"
}

on() { docker exec "$1-$run" "${@:2}"; }

# project <name> <server> <ops user> [adopt]: a project whose stack.yaml points at the server
project() {
  mkdir -p "$work/$1/.damstack"
  cat >"$work/$1/stack.yaml" <<EOF
name: $1
server:
  address: $2
  bootstrap_user: ${5:-root}
  ops_user: $3
  adopt_user: ${4:-false}
  public_interface: eth0
  public_ports: [80, 443]
network: {cidr: 10.77.0.0/24, clients: [laptop]}
EOF
}

# bootstrap <project>: run the playbook, its output in $work/<project>.log
bootstrap() {
  tool -e "DAMSTACK_PROJECT=/work/$1" "$toolbox" \
    ansible-playbook -i /stack/ansible/inventory --private-key /work/key /stack/ansible/playbooks/bootstrap.yml \
    >"$work/$1.log" 2>&1
}

logs_in() { tool "$toolbox" ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o BatchMode=yes -o ConnectTimeout=5 -i /work/key "$1@$2" "${@:3}" >/dev/null 2>&1; }

step "a fresh server: ops is created, only its key logs in, root and passwords are off"
target fresh
project fresh fresh ops
bootstrap fresh || { cat "$work/fresh.log"; fail "bootstrap of a fresh server"; }
logs_in ops fresh sudo -n true || fail "ops does not log in or use sudo"
logs_in root fresh true && fail "root still logs in"
on fresh sshd -T | grep -qx 'passwordauthentication no' || fail "password logins are on"
on fresh cat /etc/damstack/ops-user | grep -qx 'created: true' || fail "the marker does not say created"

step "a second run changes nothing"
bootstrap fresh || { cat "$work/fresh.log"; fail "second run"; }
grep -Eq 'changed=0 .*failed=0' "$work/fresh.log" || { cat "$work/fresh.log"; fail "the second run changed something"; }

step "another ops user in stack.yaml after the bootstrap is refused"
sed -i.bak 's/ops_user: ops/ops_user: admin/' "$work/fresh/stack.yaml"
tool -e "DAMSTACK_PROJECT=/work/fresh" "$toolbox" \
  ansible-playbook -i /stack/ansible/inventory --private-key /work/key /stack/ansible/playbooks/bootstrap.yml \
  >"$work/renamed.log" 2>&1 && fail "the server took another ops user"
mv "$work/fresh/stack.yaml.bak" "$work/fresh/stack.yaml"
grep -q "This server is set up for ops" "$work/renamed.log" || { cat "$work/renamed.log"; fail "no explanation"; }

step "a user damstack did not create is left alone"
target foreign
on foreign useradd -m -s /bin/sh ops
on foreign install -d -m 0700 -o ops -g ops /home/ops/.ssh
docker exec -i "foreign-$run" sh -c 'cat > /home/ops/.ssh/authorized_keys' <"$work/other.pub"
project foreign foreign ops
bootstrap foreign && fail "an existing user was taken over without adopt_user"
grep -q "already exists on the server and damstack did not create it" "$work/foreign.log" || { cat "$work/foreign.log"; fail "no explanation"; }
[[ $(on foreign cat /home/ops/.ssh/authorized_keys) == "$(cat "$work/other.pub")" ]] || fail "its keys were changed"
on foreign test ! -e /etc/damstack/ops-user || fail "a marker was left"
logs_in root foreign true || fail "the server was locked down anyway"

step "with adopt_user it is taken over, and its other keys stay"
project adopted foreign ops true
bootstrap adopted || { cat "$work/adopted.log"; fail "adopting"; }
logs_in ops foreign sudo -n true || fail "ops does not log in with the damstack key"
on foreign grep -q someone-else /home/ops/.ssh/authorized_keys || fail "its other key was removed"
on foreign grep -q damstack-test /home/ops/.ssh/authorized_keys || fail "the damstack key was not added"
on foreign cat /etc/damstack/ops-user | grep -qx 'created: false' || fail "the marker does not say taken over"
on foreign getent passwd ops | grep -q ':/bin/sh$' || fail "its shell was changed"
bootstrap adopted || { cat "$work/adopted.log"; fail "second run of the adopted"; }
on foreign grep -q someone-else /home/ops/.ssh/authorized_keys || fail "a second run removed its other key"

step "a system user is refused"
target system
project system system backup
bootstrap system && fail "a system user was accepted"
grep -q "is a system user of the server" "$work/system.log" || { cat "$work/system.log"; fail "no explanation"; }
logs_in root system true || fail "the server was locked down anyway"

step "the user the server came with can stay the ops user"
target cloud
on cloud useradd -m -s /bin/bash -G sudo cloud
on cloud sh -c 'echo "cloud ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-cloud && chmod 440 /etc/sudoers.d/90-cloud'
on cloud install -d -m 0700 -o cloud -g cloud /home/cloud/.ssh
cat "$work/key.pub" "$work/other.pub" | docker exec -i "cloud-$run" sh -c 'cat > /home/cloud/.ssh/authorized_keys && chown cloud:cloud /home/cloud/.ssh/authorized_keys'
project cloud cloud cloud false cloud
bootstrap cloud || { cat "$work/cloud.log"; fail "keeping the bootstrap user"; }
logs_in cloud cloud sudo -n true || fail "cloud does not log in"
on cloud grep -q someone-else /home/cloud/.ssh/authorized_keys || fail "its other key was removed"

printf '\nall bootstrap scenarios passed\n'
