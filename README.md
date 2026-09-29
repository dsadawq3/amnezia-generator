<div align="center">

# ⚡ Amnezia Generator

### Генератор конфигов Cloudflare WARP для **AmneziaWG 1.5 / 2 / 3.1** и MASQUE для Clash

`bash` · ноль зависимостей вручную · работает на Replit / Codespaces / Killercoda / своём VPS

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![bash](https://img.shields.io/badge/shell-bash-4.2%2B-blue.svg)](https://www.gnu.org/software/bash/)
[![versions](https://img.shields.io/badge/AmneziaWG-1.5%20%7C%202%20%7C%203.1-orange.svg)](https://github.com/amnezia-vpn/amneziawg-go)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**[Русский](#)** · [English](#english)

> 💡 Форкнул оригинальный [ImMALWARE/bash-warp-generator](https://github.com/ImMALWARE/bash-warp-generator)?
> Команды выше уже указывают на `dsadawq3/amnezia-generator`. Если ты сделал
> форк под своим аккаунтом — замени `dsadawq3` на свой логин во всех ссылках
> `raw.githubusercontent.com/...`, в бейдже Replit и в ссылке на Codespaces.

</div>

---

## Что нового по сравнению с оригиналом

Оригинальный [`ImMALWARE/bash-warp-generator`](https://github.com/ImMALWARE/bash-warp-generator)
умеет ровно **одну** версию — AmneziaWG **1.5**. Выбора версии нет вообще.

Этот форк добавляет:

| Фича | Оригинал | Здесь |
|---|:---:|:---:|
| AmneziaWG **1.5** | ✅ | ✅ |
| AmneziaWG **2** (S3/S4, диапазоны H1–H4) | ❌ | ✅ |
| AmneziaWG **3.1** (HeaderProtectionKey, тайминги, padding, cookies) | ❌ | ✅ |
| Чистый WireGuard без AWG-обфускации | ❌ | ✅ |
| Выбор версии: интерактивное меню + CLI-флаг | ❌ | ✅ |
| Валидация конфига перед выводом | ❌ | ✅ |
| Проверка, что версия определится правильно | ❌ | ✅ |
| Проверка wire-совместимости с WARP | ❌ | ✅ |
| `--self-test` (офлайн-прогон всех версий) | ❌ | ✅ |
| `--dry-run` (сборка без обращения к сети) | ❌ | ✅ |
| Работа без `jq` (авто-фолбэк на `sed`) | ❌ | ✅ |
| Генерация MASQUE-конфига для Clash | ✅ | ✅ |

---

## Быстрый старт

### Вариант 1 — Killercoda (без регистрации в GitHub)

1. Открой <https://killercoda.com/playgrounds/scenario/ubuntu>
2. Войди через Google
3. Когда откроется терминал, вставь (<kbd>Shift</kbd> + <kbd>Insert</kbd>):

```bash
bash <(wget --inet4-only -qO- https://raw.githubusercontent.com/dsadawq3/amnezia-generator/main/warp_generator.sh)
```

4. Скрипт спросит версию протокола — выбери `1.5`, `2`, `3.1` или `wg`
5. Скопируй конфиг, импортируй в [AmneziaWG](https://wiki.malw.link/network/vpns/amneziawg) или [AmneziaVPN](https://wiki.malw.link/network/vpns/amneziavpn)

### Вариант 2 — Replit

[![Run on Repl.it](https://repl.it/badge/github/replit/upm)](https://replit.com/new/github/dsadawq3/amnezia-generator)

1. Нажми **▶️ Project**
2. В консоли введи `1` — WARP для AmneziaWG, или `3` — MASQUE для Clash
3. Конфиг сохранится в `warp-awg3.1.conf` (имя зависит от выбранной версии)
4. **File Tree** → ПКМ по файлу → **Download**

### Вариант 3 — GitHub Codespaces

1. Открой <https://github.com/dsadawq3/amnezia-generator/codespaces>
2. **Create codespace on main**
3. В терминале:

```bash
bash warp_generator.sh
```

4. Файл конфига скачивается из панели файлов слева

### Вариант 4 — свой сервер

```bash
curl -fsSL https://raw.githubusercontent.com/dsadawq3/amnezia-generator/main/warp_generator.sh -o warp_generator.sh
bash warp_generator.sh --awg-version 3.1
```

> **Не запускай локально в РФ.** РКН режет `api.cloudflareclient.com`, из-за чего
> генератор не сможет зарегистрировать устройство. Бери любой из бесплатных
> сервисов выше.

---

## Версии AmneziaWG — что вообще меняется

`amneziawg-tools` разбирает `.conf` через цепочку `key_match()` и на **любой**
незнакомый ключ делает `goto error` → `Line unrecognized`. Конфиг, собранный под
3.1 и открытый в AmneziaWG 1.5, не «проигнорирует лишнее» — он упадёт целиком.

| Ключ | 1.5 | 2 | 3.1 |
|---|:---:|:---:|:---:|
| `Jc` `Jmin` `Jmax` | ✅ | ✅ | ✅ |
| `S1` `S2` | ✅ | ✅ | ✅ |
| `S3` `S4` | — | ✅ | ✅ |
| `H1`–`H4` (одиночное значение) | ✅ | ✅ | ✅ |
| `H1`–`H4` (диапазон `a-b`) | — | ✅ | ✅ |
| `I1`–`I5` (спеки тегов `<b 0x…> <r N> <rc N> <rd N> <t>`) | ✅ | ✅ | ✅ |
| `<d>` `<ds>` `<dz>` (новые теги) | — | — | ✅ |
| `HeaderProtectionKey` | — | — | ✅ |
| `ContentPaddingAddition` | — | — | ✅ |
| `RekeyAfterTime` `RekeyTimeout` `RejectAfterTime` `KeepaliveTimeout` `MaxHandshakeAttempts` | — | — | ✅ |
| `RandomTrailers` `DisableCookies` | — | — | ✅ |
| `AdvancedSecurity` (в `[Peer]`) | — | — | ✅ |

### Как AmneziaVPN определяет версию

Логика скопирована из
`amnezia-client/client/core/models/protocols/awgProtocolConfig.cpp` → `awgVersionOf()`:

```
3.1  ←  есть HeaderProtectionKey | ContentPaddingAddition | RekeyAfterTime |
        RekeyTimeout | RejectAfterTime | KeepaliveTimeout | MaxHandshakeAttempts
        (или RandomTrailers/DisableCookies не равны "off")
2    ←  есть S3 | S4  (или любой H1–H4 содержит "-", т.е. это диапазон)
1.5  ←  есть I1–I5, и при этом нет ничего из 2.x / 3.x
wg   ←  AWG-ключей нет вообще
```

Генератор собирает конфиг под выбранную версию, а потом **прогоняет через эту же
логику** и упадёт с ошибкой, если определится не та. Поэтому «молча сломанный»
конфиг получить нельзя.

---

## Почему для WARP параметры обфускации нейтральные

Cloudflare WARP — это **обычный WireGuard-сервер**. Он ничего не знает про
AmneziaWG. Любая настоящая обфускация ломает формат пакета, и туннель просто не
поднимется.

Поэтому в режиме `--mode=warp` (по умолчанию) on-wire параметры оставлены
нейтральными:

```
S1 = S2 = S3 = S4 = 0          # никакого padding
H1 = 1  H2 = 2  H3 = 3  H4 = 4 # нативные типы сообщений WireGuard
HeaderProtectionKey            # отсутствует
ContentPaddingAddition = 0     # ничего не добавляет
RandomTrailers = off
DisableCookies = off
```

Версию при этом помечают **клиентские** ключи, которые на провод не влияют, но
которые видит AmneziaVPN: `Jc`/`Jmin`/`Jmax`, `I1`–`I5` и тайминги 3.1.
Пакет `I1` уходит на сервер **до** хендшейка и не несёт данных — для DPI это
выглядит как самый обычный QUIC Initial от Chrome.

Если тебе нужен честно обфусцированный конфиг (для **своего** AWG-сервера) —
есть режим `--mode=awg`: случайные `S1..S4 ≥ 12`, диапазоны `H1..H4`,
`HeaderProtectionKey`, ненулевой padding, cookies. Против WARP он не заработает,
об этом генератор предупредит.

---

## CLI

```
bash warp_generator.sh [ОПЦИИ] [ПРИВАТНЫЙ_КЛЮЧ] [ПУБЛИЧНЫЙ_КЛЮЧ]
```

| Опция | Описание |
|---|---|
| `-V, --awg-version VER` | версия протокола: `1.5` \| `2` \| `3.1` \| `wg` |
| `--mode MODE` | `warp` (по умолчанию) или `awg` |
| `-p, --preset NAME` | `warp-legacy` \| `balanced` \| `light` \| `stealth` |
| `-o, --out FILE` | файл конфига |
| `-n, --name NAME` | имя туннеля / `description` в `vpn://` (≤ 15 символов) |
| `-e, --endpoint H:P` | endpoint WARP (по умолчанию `162.159.192.1:500`) |
| `--dns "A, B, C"` | DNS-серверы |
| `--mtu N` | MTU (по умолчанию `1280`) |
| `--no-ipv6` | не включать IPv6 (чинит macOS) |
| `--jc N` `--jmin N` `--jmax N` | переопределить мусорные пакеты |
| `--i1 SPEC` | переопределить `I1` |
| `--hpk KEY` | задать `HeaderProtectionKey` (base64 32 байта) |
| `--no-link` | не печатать `vpn://` ссылку |
| `--allow-wire-warn` | не считать ошибкой несовместимость с WARP |
| `--dry-run` | собрать и проверить конфиг, не ходить в сеть |
| `--self-test` | прогнать все версии офлайн и выйти |
| `--no-deps` | не ставить пакеты |
| `-h, --help` | справка |

### Примеры

```bash
# AmneziaWG 3.1, дефолтный пресет
bash warp_generator.sh --awg-version 3.1

# AmneziaWG 2, полегче мусорных пакетов
bash warp_generator.sh -V 2 -p balanced

# Проверить, ничего не генерируя
bash warp_generator.sh --dry-run -V 1.5

# Полная обфускация для своего AWG-сервера
bash warp_generator.sh --mode awg -V 3.1 -o my-awg.conf

# Свой I1
bash warp_generator.sh -V 3.1 --i1 '<r 40><rc 30><rd 10><t>'

# Переиспользовать существующую пару ключей
bash warp_generator.sh -V 3.1 "$(cat wg_private.key)" "$(cat wg_public.key)"
```

### Пресеты

| Пресет | `Jc` | `Jmin` | `Jmax` | Комментарий |
|---|---:|---:|---:|---|
| `warp-legacy` *(по умолчанию)* | 120 | 23 | 911 | как в оригинальном проекте |
| `balanced` | 7 | 40 | 70 | рекомендуемый AWG диапазон `Jc` — 4–12 |
| `light` | 3 | 10 | 30 | минимум, дефолт самого Amnezia |
| `stealth` | 12 | 64 | 128 | много мусора, аккуратнее с MTU |

> `Jmax` должен быть **меньше системного MTU**, иначе пакеты фрагментируются —
> это само по себе палево для цензора. Генератор предупредит.

---

## Что делает валидатор

Перед выводом каждый конфиг проходит проверку:

- структура: наличие `[Interface]`, `[Peer]`, всех обязательных ключей
- формат ключей: `PrivateKey` / `PublicKey` — ровно 32 байта в base64
- `Address`: никаких пустых элементов (`172.16.0.2, , 2606:…` — классический баг)
- **регистр ключей** — `amnezia-client` ищет `Jc`/`Jmin`/`HeaderProtectionKey`
  регистрозависимо, опечатка в регистре = «не найдено»
- белый список ключей по версии (имитация `goto error` в `amneziawg-tools`)
- диапазоны значений: `uint16`, `Jmin ≤ Jmax`, `a-b` с `b ≥ a`
- синтаксис спеков `I1`–`I5`: теги, чётность hex, запрет `<d>/<ds>/<dz>` вне 3.1
- правило 3.1: `HeaderProtectionKey` требует `S1..S4 ≥ 12` (он же nonce)
- правило 3.1: `RandomTrailers` / `DisableCookies` — только `on`/`off`
- wire-совместимость с WARP
- **сверка определённой версии с запрошенной**

Прогнать всё офлайн:

```bash
bash warp_generator.sh --self-test
```

```
───────── негативные тесты ─────────
[ OK ] 3.1-ключ в конфиге 1.5 отвергнут
[ OK ] двойная запятая в Address отвергнута
[ OK ] диапазон H1 в конфиге 1.5 отвергнут
[ OK ] битый тег I1 отвергнут
[ OK ] S1 < 12 вместе с HeaderProtectionKey отвергнуто

[ OK ] SELF-TEST ПРОЙДЕН: все версии генерируются и валидны
```

---

## MASQUE для Clash

Второй генератор в репозитории не тронут — он отдаёт `warp-masque-clash.yaml`
для Mihomo / Clash Verge Rev / FlClash / Clash Mi.

```bash
bash masque_generator.sh
```

Подробности подключения — в [wiki.malw.link](https://wiki.malw.link/network/vpns/warp).

---

## Частые ошибки

### «Две запятые подряд», `,`

Конфиг собран некорректно. Валидатор теперь ловит это до вывода, но если
осталась старая ссылка — удали конфиг и сгенерируй заново.

### «Неверный ключ для секции \[Interface\]: s1»

Ты импортируешь конфиг в обычный **WireGuard**, а не в **AmneziaWG**/**AmneziaVPN**.

### Название туннеля недействительно: `WARP (1)`

В имени файла не должно быть пробелов и скобок. В мобильном AmneziaWG имя
конфига ограничено 15 символами.

### `Failed to set IPv4: error: Destination address required` (macOS)

Удали IPv6-адрес из файла конфига или сгенерируй с `--no-ipv6`.

### Не работают соединения к локальной сети

В интерфейсе приложения сними галочку «Блокировать нетуннелированный трафик».

### `Unable to create Wintun interface` (AmneziaWG на Windows)

Удали из реестра `HKEY_CLASSES_ROOT\CLSID\{3d09c1ca-2bcc-40b7-b9bb-3f3ec143a87b}`
и переустанови AmneziaWG, либо удали драйвер:

```bat
dism /online /get-drivers /format:table > drivers.txt
notepad drivers.txt
pnputil.exe /d oemN.inf
```

Либо просто используй [AmneziaVPN](https://wiki.malw.link/network/vpns/amneziavpn) —
он полностью поддерживает AmneziaWG.

### Не подключается вообще

1. Проверь, что тонешь не в `amneziawg` 1.5 — если в нём, генерируй `--awg-version 1.5`
   (или вовсе без `--awg-version`, по умолчанию 1.5)
2. Проверь `--dry-run` — конфиг должен пройти валидацию без ошибок
3. Попробуй другой пресет: `-p light`
4. Проверь, не блокируется ли `162.159.192.1:500/udp`

---

## Как это устроено

```
warp_generator.sh
├── Section 1  утилиты (base64, генерация ключей, парсинг INI/JSON)
├── Section 2  профили обфускации под каждую версию
├── Section 3  валидатор (структура, версия, wire-compat)
├── Section 4  разбор аргументов
├── Section 5  офлайн self-test
├── Section 6  рендер конфига и сборка vpn:// (JSON вручную, jq не нужен)
├── Section 7  установка зависимостей
├── Section 8  регистрация в Cloudflare WARP API
└── Section 9  вывод
```

Зависимости: `bash`, `curl`, `base64`, `sed`, `awk`, `grep`.
`jq`, `wg`/`awg` и `apt` — опциональны, на каждый есть фолбэк.

---

## Кредиты

- Оригинальный проект и гайд: **[ImMALWARE/bash-warp-generator](https://github.com/ImMALWARE/bash-warp-generator)**
  и [wiki.malw.link](https://wiki.malw.link/network/vpns/warp) — автор
  [@ImMALWARE](https://t.me/immalware_chat)
- Спецификация протокола: [amnezia-vpn/amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go)
  и [amneziawg-tools](https://github.com/amnezia-vpn/amneziawg-tools)
- Логика определения версии: [amnezia-vpn/amnezia-client](https://github.com/amnezia-vpn/amnezia-client)

Форк распространяется на тех же условиях, что и оригинал — **MIT**
(см. [LICENSE](LICENSE)). Оригинальный проект принадлежит его автору.

---

<div align="center">

**Что-то не получается?**
[Чат автора оригинала](https://t.me/immalware_chat) · [Wiki](https://wiki.malw.link/network/vpns/warp)

<sub>Сделано с любовью к анонимности и без сливов конфигов</sub>

</div>

---

## English

**Amnezia Generator** — a `bash` generator for Cloudflare WARP configs targeting
**AmneziaWG 1.5, 2 and 3.1**, plus a MASQUE generator for Clash/Mihomo.

**What's new vs. the original:** the original project only ever produces
AmneziaWG **1.5**. This fork adds version selection (interactive menu or `-V` flag),
a full config validator (key whitelist per version, `I1`–`I5` tag syntax, `uint16`
ranges, the AWG 3.1 rule that `HeaderProtectionKey` requires `S1..S4 ≥ 12`),
a WARP wire-compatibility check, an offline `--self-test`, and `--dry-run`.

**Why the obfuscation is neutral for WARP:** Cloudflare WARP is a plain
WireGuard server and knows nothing about AmneziaWG. Any real obfuscation changes
the packet format and the tunnel simply won't come up. So `--mode=warp` (default)
keeps `S1..S4 = 0`, `H1..H4 = 1/2/3/4`, no `HeaderProtectionKey`, and
`ContentPaddingAddition = 0`. The version is still marked correctly using
client-side-only keys (`Jc`/`Jmin`/`Jmax`, `I1..I5`, and the 3.1 timers), which
AmneziaVPN's `awgVersionOf()` uses to tell 1.5 / 2 / 3.1 apart.

Use `--mode awg` for a fully obfuscated config — but only against your **own**
AWG server, never against WARP.

```bash
bash warp_generator.sh --awg-version 3.1
bash warp_generator.sh -V 2 -p balanced
bash warp_generator.sh --self-test
```

Credit for the original generator, the MASQUE script and the troubleshooting
guide goes to [ImMALWARE/bash-warp-generator](https://github.com/ImMALWARE/bash-warp-generator)
(MIT). Protocol spec: [amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go).
