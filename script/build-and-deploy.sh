#!/usr/bin/env bash

set -uo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <env>"
  exit 1
fi

./script/package.sh

cd "infra/${1}" || exit 1
terraform apply
