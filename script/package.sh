#!/usr/bin/env bash

set -uxo pipefail

pip install --target build/deps -r requirements.txt
cd build/deps || exit 1
zip -ur ../package.zip .
cd ../../src/handlers || exit 1
zip -ur ../../build/package.zip .
