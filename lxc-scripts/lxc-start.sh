#!/usr/bin/env bash

NAME=$1

if [ -z "$NAME" ]; then
  echo "Usage: $0 <name>"
  exit 1
fi

HOST_IP=$(ip addr show lxdbr0 | awk '/inet / {print $2}' | cut -d/ -f1)

if lxc info "$NAME" &>/dev/null; then
  echo "$NAME already exists. Restoring to base snapshot and starting"
  lxc stop "$NAME" 
  lxc restore  "$NAME" base
  lxc start "$NAME" 
else
  if ! lxc storage volume show default "$NAME-data" &>/dev/null; then
    lxc storage volume create default "$NAME-data"
  fi

  lxc launch ubuntu:24.04 "$NAME"

  lxc config device add "$NAME" data disk pool=default source="$NAME-data" path="/data"

  echo "Pushing SSH key"
  lxc file push --mode 600 --uid 0 --gid 0 ~/.ssh/id_rsa.pub "$NAME"/root/.ssh/authorized_keys

  echo "Setting up apt to use caching proxy"
  echo "Acquire::http::Proxy \"http://$HOST_IP:3142\";" | lxc exec "$NAME" -- tee /etc/apt/apt.conf.d/00-apt-cacher-ng > /dev/null

  echo "Set up eatmydata for apt installs"
  lxc exec "$NAME" -- ln -s /usr/bin/eatmydata /usr/local/bin/dpkg
  echo 'Dir::Bin::dpkg "/usr/local/bin/dpkg";' | lxc exec "$NAME" -- tee /etc/apt/apt.conf.d/25-eatmydata-action > /dev/null

  echo "Disabling man-db updates during apt installs" 
  echo "set man-db/auto-update false" | lxc exec "$NAME" -- debconf-communicate > /dev/null
  lxc exec "$NAME" -- dpkg-reconfigure -f noninteractive man-db > /dev/null

  echo "Doing apt-get update before snapshotting to speed up future runs"
  lxc exec "$NAME" -- apt-get update -qq

  echo "Making base snapshot"
  lxc stop "$NAME"
  lxc snapshot "$NAME" base
  lxc start "$NAME"
fi

echo "Verifying ssh is reachable"
MAX_ATTEMPTS=10
for i in $(seq 1 $MAX_ATTEMPTS); do
  CONTAINER_IP=$(lxc list "$NAME" --format csv -c 4 | cut -d' ' -f1)
  if [ -n "$CONTAINER_IP" ]; then
    if ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=3 root@"$CONTAINER_IP" true 2>/dev/null; then
      ssh-keygen -f "/home/vagrant/.ssh/known_hosts" -R "$CONTAINER_IP" > /dev/null
      ssh-keyscan -H "$CONTAINER_IP" >> ~/.ssh/known_hosts 2>/dev/null
      echo "$NAME is up at $CONTAINER_IP"
      exit 0
    fi
  fi
  [ $i -gt 3 ] && echo "Attempt $i/$MAX_ATTEMPTS failed, retrying..."
  sleep 1
done

echo "SSH did not become available in time"
exit 1
