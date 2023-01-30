#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

check "version" swift --version
check "swift is installed at correct path" test 0 -ne "$(find /usr/local/bin/swift/usr/bin | wc -l)"

# Report result
reportResults