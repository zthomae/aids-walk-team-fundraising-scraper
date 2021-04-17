#!/usr/bin/env bash

set -uxo pipefail

if [ ! -f infra/test/terraform.tfvars ]; then
  cp infra/test/terraform.tfvars.example infra/test/terraform.tfvars
fi
