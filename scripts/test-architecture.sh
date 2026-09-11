#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_binary="$(mktemp -d)/architecture-tests"
xcrun swiftc -parse-as-library \
  nyawits/Domain/Models/*.swift nyawits/Domain/Services/*.swift \
  nyawits/Domain/Repositories/*.swift nyawits/Data/Repositories/*.swift \
  nyawits/Application/*.swift nyawits/Shared/PreviewData/*.swift \
  Tests/ArchitectureSmokeTests.swift -o "$test_binary"
"$test_binary"
