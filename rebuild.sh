#!/usr/bin/env bash

if [[ "$1" != "fast" ]]; then
  echo "Doing full rebuild. Alternatively you can run:"
  echo "  Skip lxc provisioning: $0 fast"
  echo "  Skip lxc provisioning and pass args to ansible: $0 fast -t caddy --check --diff"
  echo
  /vagrant/lxc-scripts/lxc-start.sh caddy
else
  echo "Fast mode - skipping lxc reprovisioning step!"
fi

extra_ansible_args=("${@:2}")
container_ip=$(/vagrant/lxc-scripts/lxc-get-ip.sh caddy)
inventory_tmp_path=$(mktemp)

ansible_inventory="
[all]
$container_ip ansible_user=root
"

echo "Writing inventory to $inventory_tmp_path"
echo "$ansible_inventory" > "$inventory_tmp_path"

echo "Running: ansible-playbook -i $inventory_tmp_path caddy.yml ${extra_ansible_args[*]}"
ansible-playbook -i "$inventory_tmp_path" caddy.yml "${extra_ansible_args[@]}"

echo "Testing if https://caddy.local responds with 'success!' as configured"
response=$(curl -sk https://caddy.local --connect-to "caddy.local:443:$container_ip:443")

if [[ "$response" != "success!" ]]; then
  echo "Error: expected 'success!' but got '$response'" >&2
  exit 1
fi

echo "Tests passed!"

