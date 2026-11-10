#!/usr/bin/env bash
set -euo pipefail

docker --version
docker buildx version
helm version --short
kubectl version --client=true
nbgv --version
node --version
npm --version
[[ $(node -p "process.versions.node.split('.')[0]") == 26 ]]
rsync --version
ssh -V

[[ $(dotnet --version) == 10.* ]]
sdks=$(dotnet --list-sdks)
printf '%s\n' "$sdks"
grep -q '^8\.' <<< "$sdks"
grep -q '^10\.' <<< "$sdks"

echo "verify-common: OK (SDK 8 и SDK 10)"
