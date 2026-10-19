#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/logs
python3 scripts/build_native.py --jobs 4
python3 tests/test_worker_stack.py --worker 2>&1 | tee build/logs/worker-stack-tests.txt
swiftc -swift-version 5 -parse-as-library -O \
  -import-objc-header ios/Bridge.h -I native/include \
  ios/Models.swift ios/EmulationEngine.swift ios/MultiplayerProtocol.swift ios/LocalSession.swift \
  tests/MultiplayerTests.swift -L build/native-host -lAtariDiorama \
  -Xlinker -rpath -Xlinker "$PWD/build/native-host" -o build/multiplayer-tests
build/multiplayer-tests 2>&1 | tee build/logs/multiplayer-tests.txt
