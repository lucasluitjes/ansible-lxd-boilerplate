#!/usr/bin/env bash

NAME=$1

if [ -z "$NAME" ]; then
  echo "Usage: $0 <name>"
  exit 1
fi

lxc list "$NAME" --format csv -c 4 | cut -d' ' -f1
