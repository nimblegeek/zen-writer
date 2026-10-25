#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcrun swift build -c release
mkdir -p 'build/Zen Writer.app/Contents/MacOS' 'build/Zen Writer.app/Contents/Resources'
cp .build/release/ZenWriter 'build/Zen Writer.app/Contents/MacOS/ZenWriter'
cp Resources/Info.plist 'build/Zen Writer.app/Contents/Info.plist'
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns 'build/Zen Writer.app/Contents/Resources/AppIcon.icns'
fi
# Recreate bundled fonts so removed families do not linger in incremental builds.
rm -rf 'build/Zen Writer.app/Contents/Resources/Fonts'
mkdir -p 'build/Zen Writer.app/Contents/Resources/Fonts'
cp Resources/Fonts/* 'build/Zen Writer.app/Contents/Resources/Fonts/'
codesign --force --sign - 'build/Zen Writer.app'
print 'Built build/Zen Writer.app'
