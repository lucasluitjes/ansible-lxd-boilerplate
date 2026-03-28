#!/usr/bin/env bash

echo "WARNING: this will make a bunch of changes to your OS. Review script and ideally run in an isolated VM!"

read -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

cat <<EOF | lxd init --preseed
config:
  images.auto_update_interval: "0"
networks:
- config:
    ipv4.address: auto
    ipv6.address: auto
  description: ""
  name: lxdbr0
  type: ""
  project: default
storage_pools:
- config:
    size: 5GB
  description: ""
  name: default
  driver: zfs
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
projects: []
cluster: null
EOF

ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ""
sudo apt update
sudo apt-get install apt-cacher-ng software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y
sudo sh -c 'echo "PassThroughPattern: ^(.*):443$" >> /etc/apt-cacher-ng/acng.conf'
sudo systemctl restart apt-cacher-ng

sudo apt install nginx -y 

sudo mkdir -p /var/www/ruby-mirror/ruby
sudo wget -P /var/www/ruby-mirror/ruby https://github.com/jdx/ruby/releases/download/3.2.10/ruby-3.2.10.arm64_linux.tar.gz

sudo tee /etc/nginx/sites-available/ruby-mirror <<'EOF'
server {
    listen 8080;
    root /var/www/ruby-mirror;
    autoindex on;
}
EOF

sudo ln -s /etc/nginx/sites-available/ruby-mirror /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
