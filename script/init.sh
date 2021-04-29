#!/usr/bin/env bash

set -uxo pipefail

pip install -r requirements-dev.txt || exit 1
pip install -e . || exit 1

if [ ! -f infra/test/terraform.tfvars ]; then
  cp infra/test/terraform.tfvars.example infra/test/terraform.tfvars
fi
