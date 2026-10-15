#!/bin/bash
set -euo pipefail

# Source stays in AI Stuff; Xcode reads a temporary copy to avoid the host's
# Documents NSFileCoordinator stall. The directory is retained for diagnostics.
e_root="$(cd "$(dirname "$0")/.." && pwd)"
e_validation="$(mktemp -d /tmp/e-validation.XXXXXX)"
e_simulator="${1:-}"

cd "$e_root"
CLANG_MODULE_CACHE_PATH="$e_validation/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$e_validation/swift-cache" \
swift test --disable-sandbox \
    --scratch-path "$e_validation/core-build" \
    --cache-path "$e_validation/package-cache" \
    --config-path "$e_validation/package-config" \
    --security-path "$e_validation/package-security"

mkdir -p "$e_validation/project"
for e_folder in App Sources UITests; do
    ditto "$e_root/$e_folder" "$e_validation/project/$e_folder"
done
cp "$e_root/project.yml" "$e_validation/project/project.yml"
xcodegen generate --spec "$e_validation/project/project.yml"

e_destination='generic/platform=iOS Simulator'
e_action=build
if [[ -n "$e_simulator" ]]; then
    e_destination="platform=iOS Simulator,id=$e_simulator"
    e_action=test
fi
xcodebuild -project "$e_validation/project/Euler.xcodeproj" \
    -scheme Euler -configuration Debug \
    -destination "$e_destination" \
    -derivedDataPath "$e_validation/DerivedData" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO "$e_action"

if [[ -n "$e_simulator" ]]; then
    xcrun simctl install "$e_simulator" "$e_validation/DerivedData/Build/Products/Debug-iphonesimulator/Euler.app"
    xcrun simctl launch "$e_simulator" com.utkarsh.euler
fi
printf 'Validation output: %s\n' "$e_validation"
