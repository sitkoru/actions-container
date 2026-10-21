# actions-container

Образы для GitHub Actions и собственных исполнителей:

- `actions-container` (`--target common`) — официальный .NET SDK 10 на Ubuntu 24.04, SDK 8, NBGV, Docker CLI/buildx, Helm и kubectl.
- `actions-container-wasm` (`--target wasm`) — общий образ с Python и отдельной установкой `wasm-tools` для SDK 8 и SDK 10.

В обычном образе нет Chrome, его дополнительных библиотек и `trx2junit`.
`rsync` и OpenSSH сохранены для существующих процессов доставки через SSH.

## Параметры сборки

Версии передаются через `docker buildx build --build-arg ИМЯ=ЗНАЧЕНИЕ`.

| Параметр | По умолчанию |
| --- | --- |
| `DOTNET_SDK_IMAGE` | `mcr.microsoft.com/dotnet/sdk:10.0-noble` |
| `DOTNET_8_SDK_VERSION` | `8.0.426` |
| `NBGV_VERSION` | `3.10.94` |
| `DOCKER_VERSION` | `29.5.0` |
| `BUILDX_VERSION` | `0.34.0` |
| `HELM_VERSION` | `3.21.0` |
| `KUBECTL_VERSION` | `1.37.1` |

SDK 10 выбирается по умолчанию. Для SDK 8 проект должен явно выбрать его через
`global.json`; наличие `net8.0` само по себе не переключает SDK.
Версию kubectl перед подключением кластера нужно согласовать с версией его API.
Сборка проверяется на `linux/amd64`; другие архитектуры пока не проверены.

## Локальная проверка без публикации

```bash
docker buildx build --platform linux/amd64 --target common --load -t actions-container:check .
docker run --rm --platform linux/amd64 -v "$PWD/scripts:/checks:ro" actions-container:check bash /checks/verify-common.sh
```

`verify-common.sh` выполняет команды инструментов, проверяет наличие SDK 8/10
и выбор SDK 10 по умолчанию. Доступ к реестрам, кластеру и собственному
исполнителю не проверяется.

Для сравнения размера загрузите прежний образ той же архитектуры:

```bash
docker pull --platform linux/amd64 ghcr.io/sitkoru/actions-container:v3.21.0
for image in ghcr.io/sitkoru/actions-container:v3.21.0 actions-container:check; do
    printf '%s ' "$image"
    docker history --human=false --format '{{.Size}}' "$image" | awk '{size += $1} END {printf "%.0f\n", size}'
done
```

Сравнивается сумма несжатых размеров слоёв в байтах. Это не размер загрузки и не
занятое дополнительно место на диске при общих слоях. `docker image inspect .Size`
в локальном хранилище вернул несопоставимые значения, поэтому для сравнения
используется `docker history --human=false`.

Локальная проверка 21 октября 2026, `linux/amd64`:

| Образ | Сумма размеров слоёв |
| --- | ---: |
| `v3.21.0`, digest `sha256:544870322aa1b7a4822d3fb4f58d16e78318fb8aeccc911efbee769ab3204db9` | 2 046 861 312 байт |
| Новый `common` | 1 988 374 528 байт |

Выигрыш — 58 486 784 байта (55,8 МиБ; 2,86%). Официальный SDK сам по себе не
гарантирует существенного уменьшения: вместе с SDK 8 добавляется NBGV (его
установка занимает около 175 МиБ). Выполнены команды всех инструментов, сборка
и запуск программы SDK 8.0.426 и SDK 10.0.402; обе сборки без ошибок и предупреждений.

## CI и публикация

CI собирает и проверяет оба образа без публикации. Автоматическое создание
релиза допускается только при push в `master`; ветки и PR выполняют проверки.
Существующий процесс публикации по релизу сохраняет обычный и WASM-образ в GHCR
и приватном реестре с прежней схемой тегов. В этой работе публикация не выполняется.

Еженедельный запуск — понедельник, 03:00 UTC (08:00 Asia/Yekaterinburg).
Он берёт актуальную `master`, обновляет базовые образы и установочные слои
(`pull` и `no-cache`), выполняет проверки и обновляет только `latest` обоих
вариантов в обоих реестрах. Версионные теги остаются результатом обычного релиза.
Сборки публикуются последовательно; прерывание уже выполняющейся публикации
новым запуском отключено. Отправляются именно проверенные локальные образы,
повторной сборки перед публикацией нет.
Перед выпуском образа без Chrome PDF-задание Sitko.Core должно перейти на Browserless.


## Проверка WASM

Текущий DigitClub выбирает SDK 8, поэтому установки workload только SDK 10
недостаточно. В WASM-стадии каждый SDK выбирается явно через временный
`global.json`; workload устанавливается из его собственных манифестов.

```bash
docker buildx build --platform linux/amd64 --target wasm --load -t actions-container-wasm:check .
docker run --rm --platform linux/amd64 -v "$PWD/scripts:/checks:ro" actions-container-wasm:check bash /checks/verify-wasm.sh
```

`verify-wasm.sh` отдельно SDK 8 и SDK 10 публикует стандартный шаблон
Blazor WebAssembly в Release. Проверяется trimming в журнале и настоящий
`dotnet.native.wasm` в каталоге пересборки среды выполнения и готовом результате.
AOT не включается. Сборка самого DigitClub этой проверкой не подтверждается.

Локально 21 октября 2026 на `linux/amd64` оба прогона завершились успешно:
SDK 8.0.426 и SDK 10.0.402, без предупреждений и ошибок; итог
`verify-wasm: OK (SDK 8 и SDK 10, trimming и runtime relinking)`.
Сумма несжатых размеров слоёв отдельного WASM-образа — 4 168 065 024 байта
(3,88 ГиБ). В обычный образ workloads не входят.
