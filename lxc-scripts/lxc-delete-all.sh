#!/usr/bin/env bash

lxc list --format csv -c n | xargs -r -I{} lxc delete {} --force
lxc storage volume list default -f csv | awk -F, '$1=="custom" {print $2}' | xargs -I{} lxc storage volume delete default {}
