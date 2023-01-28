#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

check "version" swift --version
check "swift is installed at correct path" bash -c "which swift | grep /usr/local/bin/swift/usr/bin"

# Report result
reportResults