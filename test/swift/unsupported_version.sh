#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

check "swift version" swift --version | grep 5.7

# Report result
reportResults