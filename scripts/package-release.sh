#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/test.sh
./scripts/build-app.sh
app_bundle='build/Zen Writer.app'
codesign --verify --deep --strict "$app_bundle"
release_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_bundle/Contents/Info.plist")
release_arch=$(lipo -archs "$app_bundle/Contents/MacOS/ZenWriter" | tr ' ' '-')
release_name="Zen-Writer-${release_version}-macOS-${release_arch}.zip"
mkdir -p build/releases
COPYFILE_DISABLE=1 ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "build/releases/$release_name"
(cd build/releases && shasum -a 256 "$release_name" > "$release_name.sha256")
print "Packaged build/releases/$release_name"
