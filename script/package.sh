#!/usr/bin/env bash

set -euxo pipefail

pip install --target build/deps -r requirements.txt
cd build/deps
zip -ur ../package.zip .
cd ../../lambda
zip -ur ../build/package.zip .
