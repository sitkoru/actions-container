#!/usr/bin/env bash
set -euo pipefail

# Выполняется внутри образа; внешние сервисы и публикация не нужны.
docker --version
docker buildx version
helm version --short
kubectl version --client=true
nbgv --version
rsync --version
ssh -V

[[ $(dotnet --version) == 10.* ]]
for tool in google-chrome-stable chromium trx2junit; do
    if command -v "$tool"; then
        echo "Лишний инструмент: $tool" >&2
        exit 1
    fi
done
for package in google-chrome-stable libxss1 libxtst6 libx11-xcb1; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
        echo "Лишняя браузерная зависимость: $package" >&2
        exit 1
    fi
done

task_dir=$(mktemp -d)
trap 'rm -rf "$task_dir"' EXIT
git init -q "$task_dir/version"
cd "$task_dir/version"
printf '{"version":"1.2"}\n' > version.json
git add version.json
git -c user.name='CI Smoke' -c user.email='ci@example.invalid' commit -qm 'Smoke'
version=$(nbgv get-version -v SemVer2)
[[ "$version" == 1.2.* ]]
echo "NBGV get-version: $version"

for major in 8 10; do
    sdk=$(dotnet --list-sdks | awk -v prefix="$major." 'index($1, prefix) == 1 { version = $1 } END { print version }')
    [[ -n "$sdk" ]]
    mkdir "$task_dir/$major"
    cd "$task_dir/$major"
    printf '{"sdk":{"version":"%s","rollForward":"disable"}}\n' "$sdk" > global.json
    [[ $(dotnet --version) == "$sdk" ]]
    echo "Проверяем SDK $sdk"
    printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net%s.0</TargetFramework></PropertyGroup></Project>\n' "$major" > Smoke.csproj
    printf 'System.Console.WriteLine("SDK %s OK");\n' "$major" > Program.cs
    dotnet build -c Release
    [[ $(dotnet "bin/Release/net$major.0/Smoke.dll") == "SDK $major OK" ]]
done

echo "verify-common: OK (SDK 8 и SDK 10)"
