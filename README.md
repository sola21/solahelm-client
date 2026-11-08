# SolaHelm Client

Клиент для Windows, Android и Linux, в котором есть **оба ядра — sing-box и mihomo**.
Клиент сам выбирает ядро по конфигурации. Рассчитан в первую очередь на подписки
[SolaHelm](https://github.com/sola21/solahelm), но принимает любые конфиги sing-box / Clash Meta.

> Статус: альфа, только Windows. Работает: подписки, подключение в режимах TUN / системный прокси / только
> порт, узлы, пинг, выбор узла, маршрутизация, соединения по процессам, журнал, трей, автозапуск, portable.
> Android и Linux — дальше.

> **Disclaimer.** Independent community project, not affiliated with sing-box, mihomo, Clash or Hysteria.
> The names of the cores are used only to say which core runs your config.

## Сборка и установка (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File tools\package-windows.ps1
```

В `dist\` появятся два архива: обычный (данные в `%APPDATA%\solahelm-client`) и **portable** —
рядом с `solahelm_client.exe` лежит `portable.txt`, и всё (настройки, подписки, состояние ядер) хранится
в папке `userdata` рядом с программой. Нужно: Go 1.25+, Flutter 3.x, Visual Studio Build Tools (C++),
включённый «Режим разработчика» Windows (для плагинов Flutter).

## Лицензия

GPL-3.0 — см. [LICENSE](LICENSE). Ядро собирается вместе с sing-box и mihomo, которые распространяются
под GPL-3.0, поэтому и весь проект под ней.

### Как интерфейс управляет ядром

Интерфейс запускает `solahelm-core.exe serve` (тот же бинарник, что `corectl`) и общается с ним по
loopback-HTTP с секретом (`core/daemon`): `/fetch`, `/start`, `/stop`, `/status`, `/shutdown`. Секрет
передаётся через файл, адрес — через ready-файл. Узлы, задержки, выбор узла, трафик и соединения интерфейс
берёт напрямую из Clash API запущенного ядра — одинаково для sing-box и mihomo.

TUN требует прав администратора: ядро отвечает `needs-elevation`, интерфейс предлагает перезапустить ядро
через UAC (интерфейс сам остаётся без прав). Ядро следит за процессом интерфейса (`-parent`) и, если тот
пропал, останавливается — TUN и системный прокси не остаются висеть. Системный прокси при включении
запоминает прежние настройки WinINet и восстанавливает их при остановке.

Без `solahelm-core` рядом (или с `--dart-define=DEMO=true`) приложение работает на демо-данных.

### Десктоп

- Закрытие окна сворачивает в трей (настраивается); выход — из меню значка в трее. В меню трея:
  подключение, режим (TUN / системный прокси / порт), маршрутизация (правила / глобально / напрямую),
  выбор узла в группах с задержкой, подписки.
- Автозапуск с Windows (ключ Run, запуск с `--minimized`), запуск свёрнутым, автоподключение
  (для TUN сразу запрос UAC).
- Один экземпляр: повторный запуск показывает уже открытое окно.
- Журнал — поток `/logs` из Clash API ядра; соединения — `/connections` с определением процесса
  (`find_process` / `find-process-mode: always`), группировка по процессам, закрытые соединения,
  детали и закрытие соединения.

## Как устроено

```
┌──────────────── Flutter UI (app/) ────────────────┐
│ подписки · узлы · пинг · трафик · соединения      │
└───────────────┬───────────────────────────────────┘
                │ Clash API (REST) — одинаковый у обоих ядер
┌───────────────┴──────── core/ (Go) ───────────────┐
│ detect: формат конфига → какое ядро                │
│ engine.Manager: одно активное ядро, переключение  │
│   ├─ sing-box 1.14.x (как библиотека)              │
│   └─ mihomo 1.19.x  (как библиотека)               │
└────────────────────────────────────────────────────┘
 Android: gomobile .aar + VpnService (TUN fd)
 Windows/Linux: привилегированная служба (TUN), UI — без прав
```

Оба ядра собираются **в один Go-бинарник** (проверено: ≈50 МБ, конфликтов зависимостей нет — у mihomo
свои форки quic-go/gvisor/sing под другими путями модулей). Единственная правка: `replace` protobuf из
`go.mod` mihomo не переносится — его форк не компилируется вместе с sing-box, обычный protobuf работает.

Интерфейсу не нужно знать, какое ядро запущено: sing-box получает `experimental.clash_api`, mihomo —
`external-controller`, и дальше все запросы (`/proxies`, `/version`, задержки, трафик) одинаковые.

### Выбор ядра

| Вход | Ядро |
|---|---|
| JSON с `outbounds` / `inbounds` / `route` … | sing-box |
| YAML/JSON с `proxies` / `proxy-groups` / `rules` / `mixed-port` … | mihomo |
| Ссылки (`hysteria2://`, `vless://` …), обычные или base64 | по поддержке протоколов, при равенстве — предпочтительное ядро (по умолчанию sing-box) |

Поддержка протоколов клиентом (`core/detect/detect.go`, таблица `support`):

- оба ядра: Hysteria2, Hysteria, VLESS, VMess, Trojan, TUIC, Shadowsocks, AnyTLS, WireGuard, SOCKS, SSH;
- только sing-box: Naive (нужна сборка с `with_naive_outbound` и cronet — пока не включено);
- только mihomo: ShadowsocksR, Mieru, MASQUE (совместимость с MASQUE-сервером панели не проверена).

## Структура

- `core/engine` — обёртки над ядрами и `Manager` (одно ядро за раз).
- `core/detect` — распознавание формата и выбор ядра.
- `core/cmd/corectl` — консольная утилита: `detect`, `run`, `version`.
- `app/` — Flutter-приложение (Windows, Android, Linux): `lib/screens` — экраны, `lib/state` — состояние
  и настройки (`ui.json` в `%APPDATA%\solahelm-client`), `lib/l10n` — строки RU/EN, `lib/theme.dart` — темы.
  Ширина ≥ 720 px — боковое меню, меньше — нижняя панель. Проверка: `flutter analyze`, `flutter test`.
- Для сборки с Flutter-плагинами на Windows нужен включённый «Режим разработчика» (символические ссылки);
  сейчас плагинов нет.

## Сборка и проверка

Нужно: Go 1.25+, Flutter 3.x, для Android — SDK, NDK r28, JDK 17, для Windows — VS Build Tools (C++).

```powershell
cd core
.\build.ps1 -Test          # тесты + bin\corectl.exe
.\bin\corectl.exe version
.\bin\corectl.exe detect https://panel.example.org/<prefix>/sub/<token>/clash
.\bin\corectl.exe run    https://panel.example.org/<prefix>/sub/<token>/singbox
```

`run` поднимает Clash API на `127.0.0.1:9090` (флаги `-controller`, `-secret`, `-core`, `-prefer`, `-workdir`).
Конфиги с TUN на Windows требуют запуска от администратора.

Тест `core/engine` в одном процессе запускает sing-box → mihomo → sing-box, проверяет трафик через
локальный прокси каждого ядра и ответ Clash API.

## Что проверено

- Все подписки SolaHelm (sing-box JSON, Clash YAML со встроенным шаблоном и обоими пресетами
  маршрутизации) распознаются и стартуют в своём ядре; все прокси видны через Clash API.
- Каркас Flutter собирается под Windows и Android.

- Настоящая подписка SolaHelm (3 сервера, 2026-11-08) на тестовой Windows-машине, режим «только порт»:
  `corectl test …/singbox` — sing-box, 12 из 12 прокси отвечают; `corectl test …/clash` — mihomo, 12 из 12;
  трафик через локальный порт выходит через VPN-сервер. Naive не проверен (нет в JSON панели, нет в mihomo).

- TUN на той же машине (`scripts/tun-test.ps1`, стек gvisor, слушатели на 127.0.0.1, автостоп):
  sing-box — весь трафик машины уходит в VPN, DNS и локальная сеть работают, после остановки маршруты
  возвращаются; mihomo — то же, но с DNS-настройками шаблона панели (DoH Cloudflare + `prefer-h3`)
  резолвер периодически отвечает за 5 с ошибкой, а `curl https://www.google.com` без `-4` зависает
  (с `-4` — 0,26 с). Нужно поправить DNS в шаблоне mihomo панели.

- Связка интерфейс ↔ ядро: `app/test/daemon_integration_test.dart` (нужны `SOLAHELM_CORE` и `SOLAHELM_SUB`) —
  загрузка подписки, запуск, узлы, пинг, выбор узла, трафик, остановка для обоих ядер.
  `core/scripts/daemon-test.ps1` (Windows, от администратора) — TUN через демон, системный прокси с
  восстановлением прежних настроек, остановка ядра при исчезновении интерфейса.

`corectl test` запускает конфиг в режиме «только порт» (без TUN, всё на 127.0.0.1, порт 17890, API 19090),
через Clash API меряет задержку каждого прокси, показывает выбор групп и внешний IP, затем останавливается.

## Известные особенности

- mihomo держит `cache.db` открытым до конца процесса (`sync.Once`), рабочая папка mihomo должна быть
  постоянной.
- Если порты из конфига заняты (например, уже запущен другой Clash-клиент на 7890), mihomo пишет ошибку
  и продолжает без этого порта. Клиент должен проверять порты сам.
- JSON-подписка sing-box из панели не содержит Naive, а ссылки — содержат.

## Дальше

1. Преобразование ссылок в конфиг (сейчас `run` для ссылок отказывается).
2. Мост Go ↔ Flutter: gomobile `.aar` для Android, служба на Go для Windows/Linux.
3. Интерфейс: подписки, список узлов, пинг, подключение, трафик.
4. Android: VpnService, плитка, раздельное туннелирование. Windows: wintun, системный прокси, трей.
5. Linux: сборка в WSL2/Linux, AppImage/deb.
