#!/usr/bin/env bash
set -euo pipefail

# Проверяем workloads выбранного SDK на стандартном приложении, без кода сервисов.
task_dir=$(mktemp -d)
trap 'rm -rf "$task_dir"' EXIT
for major in 8 10; do
    sdk=$(dotnet --list-sdks | awk -v prefix="$major." 'index($1, prefix) == 1 { version = $1 } END { print version }')
    [[ -n "$sdk" ]]
    mkdir "$task_dir/$major"
    cd "$task_dir/$major"
    printf '{"sdk":{"version":"%s","rollForward":"disable"}}\n' "$sdk" > global.json
    [[ $(dotnet --version) == "$sdk" ]]
    echo "Проверяем WASM SDK $sdk"
    dotnet workload list | grep -q '^wasm-tools '
    dotnet new blazorwasm --framework "net$major.0" --no-restore -o App --name WasmSmoke
    dotnet publish App/WasmSmoke.csproj -c Release -o "$PWD/publish" -v normal > publish.log 2>&1 || { cat publish.log; exit 1; }
    cat publish.log
    grep -q 'Optimizing assemblies for size' publish.log
    find App/obj/Release -path '*/for-publish/dotnet.native.wasm' -type f | grep -q .
    find publish/wwwroot/_framework -name 'dotnet.native*.wasm' -type f | grep -q .
done

echo "verify-wasm: OK (SDK 8 и SDK 10, trimming и runtime relinking)"
