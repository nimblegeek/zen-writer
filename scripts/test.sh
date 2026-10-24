#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcrun swift test
