#!/bin/bash
# =============================================================================
#  bash-warp-generator — генератор конфигов Cloudflare WARP для AmneziaWG
#  Поддерживаемые версии протокола AmneziaWG: 1.5, 2, 3.1 (и чистый WireGuard)
#
#  Версия скрипта: 2.0.0
#  Лицензия: MIT (как в исходном проекте)
# =============================================================================
#
#  ── ПОЧЕМУ ВЕРСИИ ВАЖНЫ ──────────────────────────────────────────────────────
#  amneziawg-tools парсит .conf через match_key() и на ЛЮБОЙ незнакомый ключ
#  делает `goto error` ("Line unrecognized"). Значит конфиг под 3.1, скормленный
#  в AmneziaWG 1.5, не просто проигнорирует лишнее — он упадёт целиком.
#  Обратно: конфиг 1.5, открытый в 3.1, поднимется как plain WireGuard.
#
#  AmneziaVPN определяет версию по наличию ключей (client/core/models/protocols/
#  awgProtocolConfig.cpp, функция awgVersionOf):
#     3.1  <- HeaderProtectionKey | ContentPaddingAddition | RekeyAfterTime |
#              RekeyTimeout | RejectAfterTime | KeepaliveTimeout |
#              MaxHandshakeAttempts  (или RandomTrailers/DisableCookies != off)
#     2    <- S3 | S4  (или любой из H1..H4 содержит "-", т.е. это диапазон)
#     1.5  <- I1..I5 присутствуют, и нет ничего из 2.x/3.x
#
#  ── ПОЧЕМУ ДЛЯ WARP ПАРАМЕТРЫ НЕЙТРАЛЬНЫЕ ────────────────────────────────────
#  Cloudflare WARP — это обычный WireGuard-сервер, он не знает про AmneziaWG.
#  Любое реальное обфусцирование (S1..S4 != 0, H1..H4 != 1..4, HeaderProtectionKey,
#  ContentPaddingAddition > 0, RandomTrailers = on) ломает формат пакета, и
#  туннель до WARP перестанет подниматься. Поэтому в режиме --mode=warp мы
#  держим on-wire параметры нейтральными, а версию помечаем только клиентскими
#  ключами, которые на провод не влияют: Jc/Jmin/Jmax, I1..I5 и тайминги 3.1.
#  Режим --mode=awg генерирует честно обфусцированный конфиг — но он рабочий
#  только против своего AWG-сервера, не против WARP.
# =============================================================================

set -u

SCRIPT_VERSION="2.0.0"
AWG_API="https://api.cloudflareclient.com/v0i1909051800"

# ─── Дефолты ─────────────────────────────────────────────────────────────────
DEF_HOST="162.159.192.1"
DEF_PORT="500"
DEF_MTU="1280"
DEF_NAME="Cloudflare WARP"
DEF_PRESET="warp-legacy"
DEF_DNS="1.1.1.1, 2606:4700:4700::1111, 1.0.0.1, 2606:4700:4700::1001"
DEF_ENDPOINT="${DEF_HOST}:${DEF_PORT}"
DEF_DOWNLOAD_BASE="https://immalware.vercel.app/download"
WIKI_URL="https://wiki.malw.link/network/vpns/warp"
CHAT_URL="https://t.me/immalware_chat"

# ─── Специальные пакеты I1 ───────────────────────────────────────────────────
# <b 0xHEX> — статичные байты. Этот I1 — реальный QUIC Initial (Chrome/Google),
# 1252 байта, именно поэтому он не выглядит мусором для DPI.
I1_QUIC='<b 0xc2000000011419fa4bb3599f336777de79f81ca9a8d80d91eeec000044c635cef024a885dcb66d1420a91a8c427e87d6cf8e08b563932f449412cddf77d3e2594ea1c7a183c238a89e9adb7ffa57c133e55c59bec101634db90afb83f75b19fe703179e26a31902324c73f82d9354e1ed8da39af610afcb27e6590a44341a0828e5a3d2f0e0f7b0945d7bf3402feea0ee6332e19bdf48ffc387a97227aa97b205a485d282cd66d1c384bafd63dc42f822c4df2109db5b5646c458236ddcc01ae1c493482128bc0830c9e1233f0027a0d262f92b49d9d8abd9a9e0341f6e1214761043c021d7aa8c464b9d865f5fbe234e49626e00712031703a3e23ef82975f014ee1e1dc428521dc23ce7c6c13663b19906240b3efe403cf30559d798871557e4e60e86c29ea4504ed4d9bb8b549d0e8acd6c334c39bb8fb42ede68fb2aadf00cfc8bcc12df03602bbd4fe701d64a39f7ced112951a83b1dbbe6cd696dd3f15985c1b9fef72fa8d0319708b633cc4681910843ce753fac596ed9945d8b839aeff8d3bf0449197bd0bb22ab8efd5d63eb4a95db8d3ffc796ed5bcf2f4a136a8a36c7a0c65270d511aebac733e61d414050088a1c3d868fb52bc7e57d3d9fd132d78b740a6ecdc6c24936e92c28672dbe00928d89b891865f885aeb4c4996d50c2bbbb7a99ab5de02ac89b3308e57bcecf13f2da0333d1420e18b66b4c23d625d836b538fc0c221d6bd7f566a31fa292b85be96041d8e0bfe655d5dc1afed23eb8f2b3446561bbee7644325cc98d31cea38b865bdcc507e48c6ebdc7553be7bd6ab963d5a14615c4b81da7081c127c791224853e2d19bafdc0d9f3f3a6de898d14abb0e2bc849917e0a599ed4a541268ad0e60ea4d147dc33d17fa82f22aa505ccb53803a31d10a7ca2fea0b290a52ee92c7bf4aab7cea4e3c07b1989364eed87a3c6ba65188cd349d37ce4eefde9ec43bab4b4dc79e03469c2ad6b902e28e0bbbbf696781ad4edf424ffb35ce0236d373629008f142d04b5e08a124237e03e3149f4cdde92d7fae581a1ac332e26b2c9c1a6bdec5b3a9c7a2a870f7a0c25fc6ce245e029b686e346c6d862ad8df6d9b62474fbc31dbb914711f78074d4441f4e6e9edca3c52315a5c0653856e23f681558d669f4a4e6915bcf42b56ce36cb7dd3983b0b1d6fdf0f8efddb68e7ca0ae9dd4570fe6978fbb524109f6ec957ca61f1767ef74eb803b0f16abd0087cf2d01bc1db1c01d97ac81b3196c934586963fe7cf2d310e0739621e8bd00dc23fded18576d8c8f285d7bb5f43b547af3c76235de8b6f757f817683b2151600b11721219212bf27558edd439e73fce951f61d582320e5f4d6c315c71129b719277fc144bbe8ded25ab6d29b6e189c9bd9b16538faf60cc2aab3c3bb81fc2213657f2dd0ceb9b3b871e1423d8d3e8cc008721ef03b28e0ee7bb66b8f2a2ac01ef88df1f21ed49bf1ce435df31ac34485936172567488812429c269b49ee9e3d99652b51a7a614b7c460bf0d2d64d8349ded7345bedab1ea0a766a8470b1242f38d09f7855a32db39516c2bd4bcc538c52fa3a90c8714d4b006a15d9c7a7d04919a1cab48da7cce0d5de1f9e5f8936cffe469132991c6eb84c5191d1bcf69f70c58d9a7b66846440a9f0eef25ee6ab62715b50ca7bef0bc3013d4b62e1639b5028bdf757454356e9326a4c76dabfb497d451a3a1d2dbd46ec283d255799f72dfe878ae25892e25a2542d3ca9018394d8ca35b53ccd94947a8>'

# Дефолт Amnezia (client/core/utils/constants/protocolConstants.h)
I1_AMNEZIA='<r 2><b 0x858000010001000000000669636c6f756403636f6d0000010001c00c000100010000105a00044d583737>'

# ─── Пресеты мусорных пакетов (Jc / Jmin / Jmax) ─────────────────────────────
PRESET_WARP_LEGACY="120 23 911"
PRESET_BALANCED="7 40 70"
PRESET_LIGHT="3 10 30"
PRESET_STEALTH="12 64 128"

# ─── Состояние (значения по умолчанию) ───────────────────────────────────────
AWG_VERSION=""            # 1.5 | 2 | 3.1 | wg
AWG_VERSION_SET=0
MODE="warp"               # warp | awg
PRESET="$DEF_PRESET"
OUT_FILE=""
CONF_NAME="$DEF_NAME"
ENDPOINT="$DEF_ENDPOINT"
MTU="$DEF_MTU"
DNS="$DEF_DNS"
WANT_IPV6=1
EMIT_LINK=1
DRY_RUN=0
SELF_TEST=0
NO_DEPS=0
PRIV_KEY_ARG=""
PUB_KEY_ARG=""
HAVE_PRIV=0
HAVE_PUB=0
JC=""; JMIN=""; JMAX=""
I1_OVERRIDE=""
HPK_OVERRIDE=""
ALLOW_WIRE_WARN=0
RC=0

# =============================================================================
#  SECTION 1. Утилиты
# =============================================================================

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
    C_BLU=$'\033[36m'; C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_BLD=""; C_RST=""
fi

log_info()  { printf '%s[INFO]%s %s\n'  "$C_BLU" "$C_RST" "$*"; }
log_ok()    { printf '%s[ OK ]%s %s\n'  "$C_GRN" "$C_RST" "$*"; }
log_warn()  { printf '%s[WARN]%s %s\n'  "$C_YEL" "$C_RST" "$*" >&2; }
log_err()   { printf '%s[FAIL]%s %s\n'  "$C_RED" "$C_RST" "$*" >&2; }
log_step()  { printf '\n%s==>%s %s%s%s\n' "$C_BLD" "$C_RST" "$C_BLD" "$*" "$C_RST"; }
die()       { log_err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# base64 без переводов строк — работает и на GNU, и на BSD/macOS
b64() { base64 | tr -d '\n'; }

# Случайное число в [lo, hi]
rng_int() {
    local lo="$1" hi="$2" span
    span=$(( hi - lo + 1 ))
    [ "$span" -le 0 ] && { printf '%s' "$lo"; return; }
    printf '%s' "$(( lo + (RANDOM % span) ))"
}

# N случайных байт в hex-виде (N — количество байт, не символов)
rand_hex() {
    local bytes="${1:-32}" n
    n=$(( bytes * 2 ))
    if have od; then
        od -An -tx1 -N "$bytes" /dev/urandom 2>/dev/null | tr -d ' \n' | cut -c1-"$n"
    else
        head -c "$bytes" /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' | cut -c1-"$n"
    fi
}

# 32-байтный ключ в base64 (формат awg genkey)
gen_b64_key() {
    local hex
    hex="$(rand_hex 32)"
    [ -n "$hex" ] || return 1
    printf '%s' "$hex" | sed 's/../\\x&/g' | xargs -0 printf 2>/dev/null | b64
}

# Приватный ключ WG: awg genkey, если есть; иначе curve25519 из urandom
gen_private_key() {
    local hex
    if have awg; then
        awg genkey 2>/dev/null | tr -d '\n' && return 0
    fi
    if have wg; then
        wg genkey 2>/dev/null | tr -d '\n' && return 0
    fi
    hex="$(rand_hex 32)"
    [ -n "$hex" ] || return 1
    # x25519: любое 32-байтовое значение валидно как приватный ключ
    printf '%s' "$hex" | sed 's/../\\x&/g' | xargs -0 printf 2>/dev/null | b64
}

is_b64_key() {
    # 44 символа base64 = 32 байта, алфавит [A-Za-z0-9+/=]
    printf '%s' "$1" | grep -Eq '^[A-Za-z0-9+/]{43}=$'
}

# Достать значение ключа из INI-подобного текста (регистр ЧУВСТВИТЕЛЕН,
# ровно как в amnezia-client: importController.cpp ищет configMap.value("Jc"))
conf_get() {
    printf '%s\n' "$1" | awk -v k="$2" '
        /^[[:space:]]*#/ { next }
        {
            p = index($0, "=")
            if (p <= 0) next
            key = substr($0, 1, p - 1)
            gsub(/^[ \t]+|[ \t]+$/, "", key)
            if (key == k) {
                v = substr($0, p + 1)
                gsub(/^[ \t]+|[ \t]+$/, "", v)
                print v
                exit
            }
        }'
}

conf_has() {
    [ -n "$(conf_get "$1" "$2")" ]
}

# Экранирование строки для JSON (совместимо с bash 3.2)
json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r/\\r/g' | \
        awk 'BEGIN{ORS=""} {if (NR>1) printf "\\n"; printf "%s", $0}'
}

# Достать поле из JSON-ответа Cloudflare (jq, если есть; иначе — sed)
json_get() {
    if have jq; then
        printf '%s' "$1" | jq -r "$2 // empty" 2>/dev/null
        return
    fi
    printf '%s' "$1" | tr '{}[],' '\n\n\n\n\n' | \
        grep -m1 -E "^[[:space:]]*\"$(printf '%s' "$3" | sed 's/\./\\./g')\"[[:space:]]*:" | \
        sed -e 's/^[^:]*:[[:space:]]*//' -e 's/^"//' -e 's/"[[:space:]]*$//'
}

# =============================================================================
#  SECTION 2. Профили обфускации
# =============================================================================

# Печатает пары "Key = Value" для [Interface] согласно версии и режиму.
# $1 = версия (1.5|2|3.1|wg), $2 = режим (warp|awg)
emit_awg_params() {
    local ver="$1" mode="$2"
    local jc="$JC" jmin="$JMIN" jmax="$JMAX"
    local s1 s2 s3 s4 h1 h2 h3 h4
    local hpk="" cpa="" rat="" dco=""
    local rk_at rk_to rj_at ka_to mha
    local i1

    # ── Нейтральные значения для WARP ──────────────────────────────────────
    if [ "$mode" = "warp" ]; then
        s1=0; s2=0; s3=0; s4=0
        h1=1; h2=2; h3=3; h4=4
    else
        s1="$(rng_int 15 80)";  s2="$(rng_int 15 80)"
        s3="$(rng_int 15 60)";  s4="$(rng_int 15 80)"
        h1="$(rng_int 1000 2000)-$(rng_int 2001 3000)"
        h2="$(rng_int 1000 2000)-$(rng_int 2001 3000)"
        h3="$(rng_int 1000 2000)-$(rng_int 2001 3000)"
        h4="$(rng_int 1000 2000)-$(rng_int 2001 3000)"
    fi

    # ── Тайминги 3.1 (client-side, на провод не влияют) ────────────────────
    rk_at="$(rng_int 90 130)-$(rng_int 131 150)"
    rk_to="$(rng_int 3 5)-$(rng_int 6 8)"
    rj_at="$(rng_int 140 160)-$(rng_int 161 190)"
    ka_to="$(rng_int 5 10)-$(rng_int 11 16)"
    mha="$(rng_int 12 16)-$(rng_int 17 22)"

    # ── I-пакеты ───────────────────────────────────────────────────────────
    if [ -n "$I1_OVERRIDE" ]; then
        i1="$I1_OVERRIDE"
    elif [ "$mode" = "warp" ]; then
        i1="$I1_QUIC"
    else
        i1="<r $(rng_int 20 60)><rc $(rng_int 10 40)><rd $(rng_int 5 20)><t>"
    fi

    case "$ver" in
        wg)
            # Чистый WireGuard: AWG-ключей нет вообще
            return 0
            ;;
        1.5)
            # S3/S4 и диапазоны H — фичи 2.x, их быть не должно
            ;;
        2)
            # 3.x-ключей нет
            ;;
        3.1)
            if [ "$mode" = "awg" ]; then
                hpk="$HPK_OVERRIDE"
                cpa="$(rng_int 5 20)-$(rng_int 21 60)"
                rat="on"
                dco="on"
            else
                # WARP: HeaderProtectionKey/RandomTrailers/DisableCookies=on
                # ломают формат пакета. ContentPaddingAddition = 0 ничего не
                # добавляет, но по нему клиент честно определяет версию 3.1.
                cpa="0"
                rat="off"
                dco="off"
            fi
            ;;
    esac

    printf 'Jc = %s\n'      "$jc"
    printf 'Jmin = %s\n'    "$jmin"
    printf 'Jmax = %s\n'    "$jmax"
    printf 'S1 = %s\n'      "$s1"
    printf 'S2 = %s\n'      "$s2"
    [ "$ver" = "1.5" ] || printf 'S3 = %s\n' "$s3"
    [ "$ver" = "1.5" ] || printf 'S4 = %s\n' "$s4"
    printf 'H1 = %s\n'      "$h1"
    printf 'H2 = %s\n'      "$h2"
    printf 'H3 = %s\n'      "$h3"
    printf 'H4 = %s\n'      "$h4"
    printf 'I1 = %s\n'      "$i1"

    if [ "$ver" = "3.1" ]; then
        [ -n "$hpk" ] && printf 'HeaderProtectionKey = %s\n' "$hpk"
        printf 'ContentPaddingAddition = %s\n' "$cpa"
        printf 'RekeyAfterTime = %s\n'       "$rk_at"
        printf 'RekeyTimeout = %s\n'         "$rk_to"
        printf 'RejectAfterTime = %s\n'      "$rj_at"
        printf 'KeepaliveTimeout = %s\n'     "$ka_to"
        printf 'MaxHandshakeAttempts = %s\n' "$mha"
        printf 'RandomTrailers = %s\n'       "$rat"
        printf 'DisableCookies = %s\n'       "$dco"
    fi
}

# Разворачивает пресет в JC/JMIN/JMAX
apply_preset() {
    case "$1" in
        warp-legacy|legacy)  JC=120; JMIN=23; JMAX=911 ;;
        balanced)            JC=7;   JMIN=40; JMAX=70  ;;
        light)               JC=3;   JMIN=10; JMAX=30  ;;
        stealth)             JC=12;  JMIN=64; JMAX=128 ;;
        *) return 1 ;;
    esac
    return 0
}

# =============================================================================
#  SECTION 3. Валидация
# =============================================================================

# Точная копия логики awgVersionOf() из amnezia-client.
detect_awg_version() {
    local conf="$1"
    local s3 s4 h1 h2 h3 h4 i1 i2 i3 i4 i5
    local hpk cpa rk_at rk_to rj_at ka_to mha rt dc

    s3="$(conf_get "$conf" S3)"; s4="$(conf_get "$conf" S4)"
    h1="$(conf_get "$conf" H1)"; h2="$(conf_get "$conf" H2)"
    h3="$(conf_get "$conf" H3)"; h4="$(conf_get "$conf" H4)"
    i1="$(conf_get "$conf" I1)"; i2="$(conf_get "$conf" I2)"; i3="$(conf_get "$conf" I3)"
    i4="$(conf_get "$conf" I4)"; i5="$(conf_get "$conf" I5)"
    hpk="$(conf_get "$conf" HeaderProtectionKey)"
    cpa="$(conf_get "$conf" ContentPaddingAddition)"
    rk_at="$(conf_get "$conf" RekeyAfterTime)"; rk_to="$(conf_get "$conf" RekeyTimeout)"
    rj_at="$(conf_get "$conf" RejectAfterTime)"; ka_to="$(conf_get "$conf" KeepaliveTimeout)"
    mha="$(conf_get "$conf" MaxHandshakeAttempts)"
    rt="$(conf_get "$conf" RandomTrailers)";   dc="$(conf_get "$conf" DisableCookies)"

    # 3.1
    if [ -n "$hpk" ] || [ -n "$cpa" ] || [ -n "$rk_at" ] || [ -n "$rk_to" ] || \
       [ -n "$rj_at" ] || [ -n "$ka_to" ] || [ -n "$mha" ]; then
        printf '3.1'; return
    fi
    # isToggleEnabled(): непустое и != "off"
    if [ -n "$rt" ] && [ "$(printf '%s' "$rt" | tr 'A-Z' 'a-z')" != "off" ]; then printf '3.1'; return; fi
    if [ -n "$dc" ] && [ "$(printf '%s' "$dc" | tr 'A-Z' 'a-z')" != "off" ]; then printf '3.1'; return; fi

    # 2
    if [ -n "$s3" ] || [ -n "$s4" ]; then printf '2'; return; fi
    case "$h1$h2$h3$h4" in *-*) printf '2'; return ;; esac

    # 1.5
    if [ -n "$i1" ] || [ -n "$i2" ] || [ -n "$i3" ] || [ -n "$i4" ] || [ -n "$i5" ]; then
        printf '1.5'; return
    fi

    printf 'wg'
}

# Белый список ключей [Interface] для каждой версии.
# Всё, чего здесь нет, приведёт к "Line unrecognized" в amneziawg-tools.
key_allowed() {
    local ver="$1" key="$2"
    case "$key" in
        PrivateKey|Address|DNS|MTU) return 0 ;;
    esac
    case "$ver" in
        wg) return 1 ;;
        1.5)
            case "$key" in
                Jc|Jmin|Jmax|S1|S2|H1|H2|H3|H4|I1|I2|I3|I4|I5) return 0 ;;
            esac
            ;;
        2)
            case "$key" in
                Jc|Jmin|Jmax|S1|S2|S3|S4|H1|H2|H3|H4|I1|I2|I3|I4|I5) return 0 ;;
            esac
            ;;
        3.1)
            case "$key" in
                Jc|Jmin|Jmax|S1|S2|S3|S4|H1|H2|H3|H4|I1|I2|I3|I4|I5) return 0 ;;
                HeaderProtectionKey|ContentPaddingAddition|RekeyAfterTime|RekeyTimeout) return 0 ;;
                RejectAfterTime|KeepaliveTimeout|MaxHandshakeAttempts|RandomTrailers|DisableCookies) return 0 ;;
            esac
            ;;
    esac
    return 1
}

# Диапазон "a" или "a-b" (a <= b), оба значения — uint16
valid_range() {
    printf '%s' "$1" | grep -Eq '^[0-9]+(-[0-9]+)?$' || return 1
    local lo hi
    lo="${1%%-*}"
    if [ "$lo" = "$1" ]; then hi="$lo"; else hi="${1##*-}"; fi
    [ "$lo" -le 65535 ] && [ "$hi" -le 65535 ] && [ "$hi" -ge "$lo" ]
}

# Валидация спецификации I-пакета: <b 0xHEX> <r N> <rc N> <rd N> <t> ...
# Возвращает 0 если ок, иначе печатает причину в stderr.
validate_i_spec() {
    local spec="$1" ver="$2" label="$3"
    local rest="$spec" tag name arg err=""

    [ -n "$spec" ] || return 0

    while [ -n "$rest" ]; do
        case "$rest" in
            *"<"*) ;;
            *) err="лишний мусор после последнего тега"; break ;;
        esac
        rest="${rest#*<}"
        if [ "${rest#*>}" = "$rest" ]; then
            err="незакрытый тег в '${spec}'"
            break
        fi
        name="${rest%%>*}"
        arg=""
        case "$name" in
            *" "*) arg="${name#* }"; name="${name%% *}"; arg="$(printf '%s' "$arg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" ;;
        esac
        rest="${rest#*>}"

        if [ -z "$name" ]; then
            err="пустой тег '<>'"
            break
        fi

        case "$name" in
            b)
                case "$arg" in
                    0x*)
                        local hex="${arg#0x}"
                        if [ -z "$hex" ]; then err="<b> без данных"; break; fi
                        if [ $(( ${#hex} % 2 )) -ne 0 ]; then
                            err="<b 0x...> — нечётное число hex-символов (${#hex})"; break
                        fi
                        if ! printf '%s' "$hex" | grep -Eq '^[0-9a-fA-F]+$'; then
                            err="<b 0x...> содержит не-hex символы"; break
                        fi
                        ;;
                    *) err="<b> требует аргумент вида 0x<hex>"; break ;;
                esac
                ;;
            r|rc|rd)
                if ! printf '%s' "$arg" | grep -Eq '^[0-9]+$'; then
                    err="<${name}> требует неотрицательный размер, получено '${arg}'"; break
                fi
                if [ -z "$arg" ]; then err="<${name}> требует размер"; break; fi
                ;;
            t)
                [ -n "$arg" ] && { err="<t> не принимает аргументов"; break; }
                ;;
            d|ds)
                if [ "$ver" != "3.1" ]; then
                    err="<${name}> поддерживается только в AmneziaWG 3.1"; break
                fi
                if [ -z "$arg" ]; then err="<${name}> требует аргумент"; break; fi
                ;;
            dz)
                if [ "$ver" != "3.1" ]; then
                    err="<dz> поддерживается только в AmneziaWG 3.1"; break
                fi
                if ! valid_range "$arg"; then
                    err="<dz> требует размер или диапазон, получено '${arg}'"; break
                fi
                ;;
            *)
                err="неизвестный тег <${name}>"; break
                ;;
        esac
    done

    if [ -n "$err" ]; then
        log_err "$label: $err"
        return 1
    fi
    return 0
}

# Полная проверка конфига. $1 = conf, $2 = ожидаемая версия ("" = не проверять)
validate_conf() {
    local conf="$1" want="$2"
    local errs=0 det ver
    local pk addr addr_ns ep pub pk_u pd
    local jc jmin jmax s1 s2 s3 s4 h1 h2 h3 h4
    local hpk cpa rt dc
    local k line

    log_step "Валидация конфига"

    # ── Структура ──────────────────────────────────────────────────────────
    if ! printf '%s\n' "$conf" | grep -q '^\[Interface\]'; then
        log_err "нет секции [Interface]"; errs=$(( errs + 1 ))
    fi
    if ! printf '%s\n' "$conf" | grep -q '^\[Peer\]'; then
        log_err "нет секции [Peer]"; errs=$(( errs + 1 ))
    fi

    pk="$(conf_get "$conf" PrivateKey)"
    addr="$(conf_get "$conf" Address)"
    pub="$(conf_get "$conf" PublicKey)"
    ep="$(conf_get "$conf" Endpoint)"

    if [ -z "$pk" ]; then
        log_err "PrivateKey пуст"; errs=$(( errs + 1 ))
    elif ! is_b64_key "$pk"; then
        log_err "PrivateKey не похож на 32-байтовый base64 (ожидалось 44 символа)"; errs=$(( errs + 1 ))
    fi
    if [ -z "$addr" ]; then
        log_err "Address пуст"; errs=$(( errs + 1 ))
    else
        addr_ns="$(printf '%s' "$addr" | tr -d '[:space:]')"
        case "$addr_ns" in
            *,,*|,*|*,)
                log_err "Address содержит пустой элемент (лишняя/двойная запятая): '${addr}'"
                errs=$(( errs + 1 )) ;;
        esac
        case "$addr" in
            *[!0-9a-fA-F:.,/[:space:]]*)
                log_err "Address содержит недопустимые символы: '${addr}'"; errs=$(( errs + 1 )) ;;
        esac
    fi
    if [ -z "$pub" ]; then
        log_err "Peer/PublicKey пуст"; errs=$(( errs + 1 ))
    elif ! is_b64_key "$pub"; then
        log_err "Peer/PublicKey не похож на 32-байтовый base64"; errs=$(( errs + 1 ))
    fi
    if [ -z "$ep" ]; then
        log_err "Peer/Endpoint пуст"; errs=$(( errs + 1 ))
    else
        case "$ep" in
            *:*) ;;
            *) log_err "Endpoint '${ep}' без порта"; errs=$(( errs + 1 )) ;;
        esac
    fi
    if [ -z "$(conf_get "$conf" AllowedIPs)" ]; then
        log_err "Peer/AllowedIPs пуст"; errs=$(( errs + 1 ))
    fi

    # ── Регистр ключей и белый список по версии ───────────────────────────
    det="$(detect_awg_version "$conf")"
    ver="${det:-wg}"

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in
            '['*']') continue ;;
        esac
        k="${line%%=*}"
        k="$(printf '%s' "$k" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$k" ] && continue
        if [ "$k" = "PublicKey" ] || [ "$k" = "Endpoint" ] || [ "$k" = "AllowedIPs" ] || \
           [ "$k" = "PresharedKey" ] || [ "$k" = "PersistentKeepalive" ] || \
           [ "$k" = "PreSharedKey" ]; then
            continue
        fi
        if ! key_allowed "$ver" "$k"; then
            log_err "ключ '${k}' недопустим для AmneziaWG ${det:-wg} (amneziawg-tools: 'Line unrecognized')"
            errs=$(( errs + 1 ))
        fi
    done <<EOF
$conf
EOF

    # ── Значения ───────────────────────────────────────────────────────────
    jc="$(conf_get "$conf" Jc)";   jmin="$(conf_get "$conf" Jmin)"; jmax="$(conf_get "$conf" Jmax)"
    s1="$(conf_get "$conf" S1)";   s2="$(conf_get "$conf" S2)"
    s3="$(conf_get "$conf" S3)";   s4="$(conf_get "$conf" S4)"
    h1="$(conf_get "$conf" H1)";   h2="$(conf_get "$conf" H2)"
    h3="$(conf_get "$conf" H3)";   h4="$(conf_get "$conf" H4)"

    for pair in "Jc:$jc" "Jmin:$jmin" "Jmax:$jmax" "S1:$s1" "S2:$s2" "S3:$s3" "S4:$s4"; do
        k="${pair%%:*}"; v="${pair#*:}"
        [ -n "$v" ] || continue
        if ! printf '%s' "$v" | grep -Eq '^[0-9]+$'; then
            log_err "${k}='${v}' — ожидалось целое число 0..65535"; errs=$(( errs + 1 ))
        elif [ "$v" -gt 65535 ]; then
            log_err "${k}='${v}' больше 65535 (uint16)"; errs=$(( errs + 1 ))
        fi
    done

    if [ -n "$jmin" ] && [ -n "$jmax" ] && [ "$jmin" -gt "$jmax" ] 2>/dev/null; then
        log_err "Jmin(${jmin}) > Jmax(${jmax})"; errs=$(( errs + 1 ))
    fi
    if [ -n "$jmax" ] && [ -n "$MTU" ] && [ "$jmax" -ge "$MTU" ] 2>/dev/null; then
        log_warn "Jmax(${jmax}) >= MTU(${MTU}) — мусорные пакеты будут фрагментироваться, это палево"
    fi

    for pair in "H1:$h1" "H2:$h2" "H3:$h3" "H4:$h4"; do
        k="${pair%%:*}"; v="${pair#*:}"
        [ -n "$v" ] || continue
        if ! valid_range "$v"; then
            if [ "$ver" = "1.5" ] || [ "$ver" = "wg" ]; then
                log_err "${k}='${v}' — в AmneziaWG 1.5 H1..H4 это одиночное uint32, диапазоны появились в 2.0"
            else
                log_err "${k}='${v}' — ожидалось 'N' или 'N-M'"
            fi
            errs=$(( errs + 1 ))
        fi
    done

    for n in 1 2 3 4 5; do
        validate_i_spec "$(conf_get "$conf" "I${n}")" "$ver" "I${n}" || errs=$(( errs + 1 ))
    done

    # ── Правила 3.1 ────────────────────────────────────────────────────────
    if [ "$ver" = "3.1" ]; then
        hpk="$(conf_get "$conf" HeaderProtectionKey)"
        cpa="$(conf_get "$conf" ContentPaddingAddition)"
        rt="$(conf_get "$conf" RandomTrailers)"
        dc="$(conf_get "$conf" DisableCookies)"

        if [ -n "$hpk" ]; then
            if ! is_b64_key "$hpk"; then
                log_err "HeaderProtectionKey должен быть 32-байтовым base64 (awg genkey)"; errs=$(( errs + 1 ))
            else
                for pair in "S1:$s1" "S2:$s2" "S3:$s3" "S4:$s4"; do
                    k="${pair%%:*}"; v="${pair#*:}"
                    [ -n "$v" ] || continue
                    if [ "$v" -lt 12 ] 2>/dev/null; then
                        log_err "HeaderProtectionKey требует ${k} >= 12, стоит ${v} (nonce = S1-S4)"
                        errs=$(( errs + 1 ))
                    fi
                done
            fi
        fi
        for pair in "ContentPaddingAddition:$cpa" "RekeyAfterTime:$(conf_get "$conf" RekeyAfterTime)" \
                    "RekeyTimeout:$(conf_get "$conf" RekeyTimeout)" "RejectAfterTime:$(conf_get "$conf" RejectAfterTime)" \
                    "KeepaliveTimeout:$(conf_get "$conf" KeepaliveTimeout)" \
                    "MaxHandshakeAttempts:$(conf_get "$conf" MaxHandshakeAttempts)"; do
            k="${pair%%:*}"; v="${pair#*:}"
            [ -n "$v" ] || continue
            if ! valid_range "$v"; then
                log_err "${k}='${v}' — ожидалось 'N' или 'N-M'"; errs=$(( errs + 1 ))
            fi
        done
        for pair in "RandomTrailers:$rt" "DisableCookies:$dc"; do
            k="${pair%%:*}"; v="${pair#*:}"
            [ -n "$v" ] || continue
            case "$(printf '%s' "$v" | tr 'A-Z' 'a-z')" in
                on|off|1|0|true|false) ;;
                *) log_err "${k}='${v}' — ожидалось on/off"; errs=$(( errs + 1 )) ;;
            esac
        done
    fi

    # ── Совместимость с WARP (сервер не понимает AWG) ──────────────────────
    if [ "$MODE" = "warp" ]; then
        for pair in "S1:$s1" "S2:$s2" "S3:$s3" "S4:$s4"; do
            k="${pair%%:*}"; v="${pair#*:}"
            [ -n "$v" ] || continue
            if [ "$v" != "0" ]; then
                [ "$ALLOW_WIRE_WARN" = "1" ] || { log_err "${k}=${v}: WARP — обычный WireGuard, padding сломает туннель"; errs=$(( errs + 1 )); }
            fi
        done
        local idx=1
        for v in "$h1" "$h2" "$h3" "$h4"; do
            [ -n "$v" ] || continue
            if [ "$v" != "$idx" ]; then
                [ "$ALLOW_WIRE_WARN" = "1" ] || { log_err "H${idx}=${v}: WARP требует нативный тип сообщения ${idx}"; errs=$(( errs + 1 )); }
            fi
            idx=$(( idx + 1 ))
        done
        if [ -n "$(conf_get "$conf" HeaderProtectionKey)" ]; then
            [ "$ALLOW_WIRE_WARN" = "1" ] || { log_err "HeaderProtectionKey ломает формат пакета для WARP"; errs=$(( errs + 1 )); }
        fi
        cpa="$(conf_get "$conf" ContentPaddingAddition)"
        if [ -n "$cpa" ] && [ "$cpa" != "0" ] && [ "$cpa" != "0-0" ]; then
            [ "$ALLOW_WIRE_WARN" = "1" ] || { log_err "ContentPaddingAddition=${cpa} добавит padding в транспорт — WARP не поймёт"; errs=$(( errs + 1 )); }
        fi
        for pair in "RandomTrailers:$(conf_get "$conf" RandomTrailers)" "DisableCookies:$(conf_get "$conf" DisableCookies)"; do
            k="${pair%%:*}"; v="${pair#*:}"
            [ -n "$v" ] || continue
            case "$(printf '%s' "$v" | tr 'A-Z' 'a-z')" in
                off|0|false) ;;
                *) [ "$ALLOW_WIRE_WARN" = "1" ] || { log_err "${k}=${v} меняет wire-формат — WARP не поддерживает"; errs=$(( errs + 1 )); } ;;
            esac
        done
    fi

    # ── Сверка с запросом ──────────────────────────────────────────────────
    if [ -n "$want" ]; then
        if [ "$det" = "$want" ]; then
            log_ok "версия определена как AmneziaWG ${det} (совпадает с запросом)"
        else
            log_err "запрошена версия '${want}', но ключи в конфиге определяются как '${det:-wg}'"
            errs=$(( errs + 1 ))
        fi
    fi

    if [ "$errs" -gt 0 ]; then
        log_err "валидация не пройдена: проблем — ${errs}"
        return 1
    fi
    log_ok "конфиг валиден (версия: ${det:-WireGuard, без AWG-обфускации})"
    return 0
}

# =============================================================================
#  SECTION 4. Разбор аргументов
# =============================================================================

usage() {
    cat <<'USAGE'
bash-warp-generator — конфиги Cloudflare WARP для AmneziaWG 1.5 / 2 / 3.1

ИСПОЛЬЗОВАНИЕ
  bash warp_generator.sh [ОПЦИИ] [ПРИВАТНЫЙ_КЛЮЧ] [ПУБЛИЧНЫЙ_КЛЮЧ]

ОПЦИИ
  -V, --awg-version VER   версия протокола: 1.5 | 2 | 3.1 | wg (обычный WireGuard)
      --mode MODE         warp (по умолчанию, on-wire нейтрально)
                          awg  (полная обфускация; только для СВОЕГО AWG-сервера)
  -p, --preset NAME       warp-legacy (120/23/911) | balanced | light | stealth
  -o, --out FILE          файл конфига (по умолчанию warp-<версия>.conf)
  -n, --name NAME         имя туннеля / description в vpn:// (≤15 символов)
  -e, --endpoint H:P      endpoint WARP (по умолчанию 162.159.192.1:500)
      --dns "A, B, C"     DNS-серверы
      --mtu N             MTU (по умолчанию 1280)
      --no-ipv6           не включать IPv6-адрес из WARP (чинит macOS)
      --jc N              переопределить Jc
      --jmin N            переопределить Jmin
      --jmax N            переопределить Jmax
      --i1 SPEC           переопределить I1 (спека тегов, напр. "<b 0xdeadbeef>")
      --hpk KEY           задать HeaderProtectionKey (base64 32 байта)
      --no-link           не печатать vpn:// ссылку
      --allow-wire-warn   не считать ошибкой несовместимость с WARP
      --dry-run           собрать и проверить конфиг, не ходить в сеть
      --self-test         прогнать все версии офлайн и выйти
      --no-deps           не ставить пакеты
  -h, --help              эта справка

ПРИМЕРЫ
  bash warp_generator.sh --awg-version 3.1
  bash warp_generator.sh -V 2 -p balanced
  bash warp_generator.sh -V 1.5 --dry-run
  bash warp_generator.sh --mode awg -V 3.1 -o my-awg.conf
USAGE
}

normalize_version() {
    case "$(printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]')" in
        1.5|15|v1.5|awg1.5) printf '1.5' ;;
        2|v2|awg2|2.0)       printf '2' ;;
        3|3.0)               printf '3.1' ;;
        3.1|31|v3.1|awg3.1)  printf '3.1' ;;
        wg|wireguard|none|off|plain) printf 'wg' ;;
        *) return 1 ;;
    esac
}

interactive_menu() {
    local ans
    printf '\n%s╔══════════════════════════════════════════════╗%s\n' "$C_BLD" "$C_RST"
    printf '%s║  Версия протокола AmneziaWG                   ║%s\n' "$C_BLD" "$C_RST"
    printf '%s╚══════════════════════════════════════════════╝%s\n' "$C_BLD" "$C_RST"
    printf '  1) 1.5   — S1/S2 + H1..H4 + I1..I5  (совместимо со всем)\n'
    printf '  2) 2     — + S3/S4, H1..H4 могут быть диапазонами\n'
    printf '  3) 3.1   — + HeaderProtectionKey, тайминги, padding, cookies\n'
    printf '  4) wg    — обычный WireGuard без обфускации AWG\n'
    printf '\n'
    while :; do
        printf 'Версия [1.5]: '
        read -r ans || ans=""
        [ -z "$ans" ] && ans="1.5"
        if normalize_version "$ans" >/dev/null 2>&1; then
            AWG_VERSION="$(normalize_version "$ans")"
            AWG_VERSION_SET=1
            return 0
        fi
        log_warn "не понял '${ans}'. Введите 1.5, 2, 3.1, wg или Enter для 1.5"
    done
}

# Опции, принимающие значение
need_value() {
    [ "$2" -ge 2 ] || die "опция ${1} требует значение"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -V|--awg-version|--target-version)
            need_value "$1" "$#"; AWG_VERSION="$(normalize_version "$2")" || die "неизвестная версия: '$2' (доступно: 1.5, 2, 3.1, wg)"
            AWG_VERSION_SET=1; shift 2 ;;
        --awg-version=*|--target-version=*)
            AWG_VERSION="$(normalize_version "${1#*=}")" || die "неизвестная версия: '${1#*=}'"
            AWG_VERSION_SET=1; shift ;;
        --mode)
            need_value "$1" "$#"; MODE="$2"
            case "$MODE" in warp|awg) ;; *) die "--mode: допустимо warp|awg" ;; esac
            shift 2 ;;
        --mode=*) MODE="${1#*=}"; case "$MODE" in warp|awg) ;; *) die "--mode: допустимо warp|awg" ;; esac; shift ;;
        -p|--preset)
            need_value "$1" "$#"; PRESET="$2"; shift 2 ;;
        --preset=*) PRESET="${1#*=}"; shift ;;
        -o|--out)
            need_value "$1" "$#"; OUT_FILE="$2"; shift 2 ;;
        --out=*) OUT_FILE="${1#*=}"; shift ;;
        -n|--name)
            need_value "$1" "$#"; CONF_NAME="$2"; shift 2 ;;
        --name=*) CONF_NAME="${1#*=}"; shift ;;
        -e|--endpoint)
            need_value "$1" "$#"; ENDPOINT="$2"; shift 2 ;;
        --endpoint=*) ENDPOINT="${1#*=}"; shift ;;
        --dns)
            need_value "$1" "$#"; DNS="$2"; shift 2 ;;
        --dns=*) DNS="${1#*=}"; shift ;;
        --mtu)
            need_value "$1" "$#"; MTU="$2"; shift 2 ;;
        --mtu=*) MTU="${1#*=}"; shift ;;
        --jc)        need_value "$1" "$#"; JC="$2";   shift 2 ;;
        --jc=*)      JC="${1#*=}";   shift ;;
        --jmin)      need_value "$1" "$#"; JMIN="$2"; shift 2 ;;
        --jmin=*)    JMIN="${1#*=}"; shift ;;
        --jmax)      need_value "$1" "$#"; JMAX="$2"; shift 2 ;;
        --jmax=*)    JMAX="${1#*=}"; shift ;;
        --i1)        need_value "$1" "$#"; I1_OVERRIDE="$2"; shift 2 ;;
        --i1=*)      I1_OVERRIDE="${1#*=}"; shift ;;
        --hpk)       need_value "$1" "$#"; HPK_OVERRIDE="$2"; shift 2 ;;
        --hpk=*)     HPK_OVERRIDE="${1#*=}"; shift ;;
        --no-ipv6)   WANT_IPV6=0; shift ;;
        --ipv6)      WANT_IPV6=1; shift ;;
        --no-link)   EMIT_LINK=0; shift ;;
        --allow-wire-warn) ALLOW_WIRE_WARN=1; shift ;;
        --dry-run)   DRY_RUN=1; shift ;;
        --self-test) SELF_TEST=1; shift ;;
        --no-deps)   NO_DEPS=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        --version)   printf 'bash-warp-generator %s\n' "$SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*) die "неизвестная опция: $1 (см. --help)" ;;
        *)
            if   [ "$HAVE_PRIV" -eq 0 ]; then PRIV_KEY_ARG="$1"; HAVE_PRIV=1
            elif [ "$HAVE_PUB"  -eq 0 ]; then PUB_KEY_ARG="$1";  HAVE_PUB=1
            else die "лишний позиционный аргумент: $1"
            fi
            shift ;;
    esac
done

# После `--` всё оставшееся — ключи
while [ $# -gt 0 ]; do
    if   [ "$HAVE_PRIV" -eq 0 ]; then PRIV_KEY_ARG="$1"; HAVE_PRIV=1
    elif [ "$HAVE_PUB"  -eq 0 ]; then PUB_KEY_ARG="$1";  HAVE_PUB=1
    else die "лишний позиционный аргумент: $1"
    fi
    shift
done

# =============================================================================
#  SECTION 5. Режим самопроверки (полностью офлайн)
# =============================================================================

run_self_test() {
    local fails=0 v conf saved_mode saved_ver saved_preset

    saved_mode="$MODE"; saved_ver="$AWG_VERSION"; saved_preset="$PRESET"

    printf '\n%s╔══════════════════════════════════════════════╗%s\n' "$C_BLD" "$C_RST"
    printf '%s║  SELF-TEST: генерация + валидация всех версий  ║%s\n' "$C_BLD" "$C_RST"
    printf '%s╚══════════════════════════════════════════════╝%s\n' "$C_BLD" "$C_RST"

    if ! apply_preset "$DEF_PRESET"; then
        log_err "встроенный пресет '${DEF_PRESET}' не найден"; exit 1
    fi

    MODE="warp"
    local saved_ck="$PRIV_KEY_ARG" saved_sk="$PUB_KEY_ARG" saved_have="$HAVE_PRIV"
    # детерминированные тестовые ключи (32 байта в base64)
    PRIV_KEY_ARG="yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk="
    PUB_KEY_ARG="hHmD7B3vF0mQp1cR8sT2uV5wX6yZ0aB3cD4eF5gH6I8="
    HAVE_PRIV=1; HAVE_PUB=1
    local test_v4="172.16.0.2" test_v6="2606:4700:110:8a1b:c0de:1234:5678:9abc"

    for v in 1.5 2 3.1 wg; do
        AWG_VERSION="$v"
        if [ "$v" = "wg" ]; then MODE="warp"; fi
        printf '\n%s───────── AmneziaWG %s ─────────%s\n' "$C_BLD" "$v" "$C_RST"
        conf="$(render_conf "$PRIV_KEY_ARG" "$PUB_KEY_ARG" "$test_v4" "$test_v6")" || {
            log_err "рендер не удался"; fails=$(( fails + 1 )); continue; }
        printf '%s\n' "$conf" | sed 's/^/    /' | cut -c1-118
        validate_conf "$conf" "$v" || fails=$(( fails + 1 ))
    done

    # Негативные тесты: мусор должен отвергаться
    printf '\n%s───────── негативные тесты ─────────%s\n' "$C_BLD" "$C_RST"

    AWG_VERSION="1.5"; MODE="warp"
    conf="$(render_conf "$PRIV_KEY_ARG" "$PUB_KEY_ARG" "$test_v4" "$test_v6")"
    bad="$(printf '%s\n' "$conf" | sed 's/^Jc = .*/Jc = 120\nHeaderProtectionKey = yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=/')"
    if validate_conf "$bad" "" >/dev/null 2>&1; then
        log_err "НЕГАТИВНЫЙ ТЕСТ ПРОВАЛЕН: 3.1-ключ в конфиге 1.5 не отловлен"; fails=$(( fails + 1 ))
    else
        log_ok "3.1-ключ в конфиге 1.5 отвергнут"
    fi

    bad="$(printf '%s\n' "$conf" | sed 's|^Address = .*|Address = 172.16.0.2, , 2606:4700::1|')"
    if validate_conf "$bad" "" >/dev/null 2>&1; then
        log_err "НЕГАТИВНЫЙ ТЕСТ ПРОВАЛЕН: двойная запятая не отловлена"; fails=$(( fails + 1 ))
    else
        log_ok "двойная запятая в Address отвергнута"
    fi

    bad="$(printf '%s\n' "$conf" | sed 's/^H1 = .*/H1 = 1000-2000/')"
    if validate_conf "$bad" "" >/dev/null 2>&1; then
        log_err "НЕГАТИВНЫЙ ТЕСТ ПРОВАЛЕН: диапазон в H1 для 1.5 не отловлен"; fails=$(( fails + 1 ))
    else
        log_ok "диапазон H1 в конфиге 1.5 отвергнут"
    fi

    bad="$(printf '%s\n' "$conf" | sed 's|^I1 = .*|I1 = <b 0xdeadbeef/>|')"
    if validate_conf "$bad" "" >/dev/null 2>&1; then
        log_err "НЕГАТИВНЫЙ ТЕСТ ПРОВАЛЕН: кривой тег <b 0xdeadbeef/> не отловлен"; fails=$(( fails + 1 ))
    else
        log_ok "битый тег I1 отвергнут"
    fi

    AWG_VERSION="3.1"; MODE="awg"
    HPK_OVERRIDE="$(gen_b64_key)"
    conf="$(render_conf "$PRIV_KEY_ARG" "$PUB_KEY_ARG" "$test_v4" "$test_v6")"
    bad="$(printf '%s\n' "$conf" | sed 's/^S1 = .*/S1 = 4/')"
    if validate_conf "$bad" "" >/dev/null 2>&1; then
        log_err "НЕГАТИВНЫЙ ТЕСТ ПРОВАЛЕН: S1 < 12 с HeaderProtectionKey не отловлен"; fails=$(( fails + 1 ))
    else
        log_ok "S1 < 12 вместе с HeaderProtectionKey отвергнуто"
    fi

    # Совместимость версий: конфиг 1.5 не должен ломаться в 2/3.1 и наоборот
    AWG_VERSION="1.5"; MODE="warp"
    conf="$(render_conf "$PRIV_KEY_ARG" "$PUB_KEY_ARG" "$test_v4" "$test_v6")"
    v="$(detect_awg_version "$conf")"
    [ "$v" = "1.5" ] || { log_err "detect_awg_version вернул '${v}' вместо 1.5"; fails=$(( fails + 1 )); }
    AWG_VERSION="3.1"
    conf="$(render_conf "$PRIV_KEY_ARG" "$PUB_KEY_ARG" "$test_v4" "$test_v6")"
    v="$(detect_awg_version "$conf")"
    [ "$v" = "3.1" ] || { log_err "detect_awg_version вернул '${v}' вместо 3.1"; fails=$(( fails + 1 )); }

    PRIV_KEY_ARG="$saved_ck"; PUB_KEY_ARG="$saved_sk"; HAVE_PRIV="$saved_have"
    MODE="$saved_mode"; AWG_VERSION="$saved_ver"; PRESET="$saved_preset"

    printf '\n'
    if [ "$fails" -eq 0 ]; then
        log_ok "SELF-TEST ПРОЙДЕН: все версии генерируются и валидны"
        return 0
    fi
    log_err "SELF-TEST ПРОВАЛЕН: провалов — ${fails}"
    return 1
}

# =============================================================================
#  SECTION 6. Рендер конфига
# =============================================================================

render_conf() {
    local priv="$1" pub="$2" v4="$3" v6="$4"
    local params addr

    params="$(emit_awg_params "$AWG_VERSION" "$MODE")" || return 1

    addr="$v4"
    if [ "$WANT_IPV6" -eq 1 ] && [ -n "$v6" ] && [ "$v6" != "null" ]; then
        addr="${v4}, ${v6}"
    fi

    {
        printf '[Interface]\n'
        printf 'PrivateKey = %s\n' "$priv"
        if [ -n "$params" ]; then
            printf '%s\n' "$params"
        fi
        printf 'MTU = %s\n' "$MTU"
        printf 'Address = %s\n' "$addr"
        printf 'DNS = %s\n' "$DNS"
        printf '\n[Peer]\n'
        printf 'PublicKey = %s\n' "$pub"
        printf 'AllowedIPs = 0.0.0.0/0, ::/0\n'
        printf 'Endpoint = %s\n' "$ENDPOINT"
    }
}

# Собирает vpn://-ссылку (JSON собирается вручную, jq не обязателен)
build_vpn_link() {
    local conf="$1" priv="$2" pub="$3" v4="$4" v6="$5"
    local det client_ip fields="" esc

    det="$(detect_awg_version "$conf")"

    client_ip="$v4"
    [ "$WANT_IPV6" -eq 1 ] && [ -n "$v6" ] && [ "$v6" != "null" ] && client_ip="${v4}, ${v6}"

    # Копируем только те AWG-ключи, которые реально есть в конфиге
    local k v fields8="" fields10="" pv8="" pv10=""
    for k in Jc Jmin Jmax S1 S2 S3 S4 H1 H2 H3 H4 I1 I2 I3 I4 I5 \
             HeaderProtectionKey ContentPaddingAddition RekeyAfterTime RekeyTimeout \
             RejectAfterTime KeepaliveTimeout MaxHandshakeAttempts RandomTrailers DisableCookies; do
        v="$(conf_get "$conf" "$k")"
        [ -n "$v" ] || continue
        fields8="${fields8}        \"${k}\": \"$(json_escape "$v")\",\n"
        fields10="${fields10}          \"${k}\": \"$(json_escape "$v")\",\n"
    done
    if [ "$det" != "wg" ]; then
        pv8="        \"protocol_version\": \"${det}\",\n"
        pv10="          \"protocol_version\": \"${det}\",\n"
    fi

    esc="$(json_escape "$conf")"

    {
        printf '{\n'
        printf '  "containers": [\n'
        printf '    {\n'
        printf '      "container": "amnezia-awg",\n'
        printf '      "awg": {\n'
        printf '        "isThirdPartyConfig": true,\n'
        printf '%b' "$fields8"
        printf '        "allowed_ips": ["0.0.0.0/0", "::/0"],\n'
        printf '        "client_ip": "%s",\n' "$(json_escape "$client_ip")"
        printf '        "client_priv_key": "%s",\n' "$(json_escape "$priv")"
        printf '        "config": "%s",\n' "$esc"
        printf '        "hostName": "%s",\n' "${ENDPOINT%%:*}"
        printf '        "mtu": %s,\n' "$MTU"
        printf '        "port": %s,\n' "${ENDPOINT##*:}"
        printf '%b' "$pv8"
        printf '        "server_pub_key": "%s",\n' "$(json_escape "$pub")"
        printf '        "last_config": {\n'
        printf '%b' "$fields10"
        printf '          "allowed_ips": ["0.0.0.0/0", "::/0"],\n'
        printf '          "client_ip": "%s",\n' "$(json_escape "$client_ip")"
        printf '          "client_priv_key": "%s",\n' "$(json_escape "$priv")"
        printf '          "config": "%s",\n' "$esc"
        printf '          "hostName": "%s",\n' "${ENDPOINT%%:*}"
        printf '          "mtu": %s,\n' "$MTU"
        printf '          "port": %s,\n' "${ENDPOINT##*:}"
        printf '%b' "$pv10"
        printf '          "server_pub_key": "%s"\n' "$(json_escape "$pub")"
        printf '        }\n'
        printf '      }\n'
        printf '    }\n'
        printf '  ],\n'
        printf '  "defaultContainer": "amnezia-awg",\n'
        printf '  "description": "%s",\n' "$(json_escape "$CONF_NAME")"
        printf '  "hostName": "%s"\n' "${ENDPOINT%%:*}"
        printf '}'
    } | tr -d '\n' | b64 | sed 's/^/vpn:\/\//'
}

# =============================================================================
#  SECTION 7. Зависимости
# =============================================================================

install_deps() {
    if [ "$NO_DEPS" = "1" ]; then
        log_warn "--no-deps: пропускаю установку пакетов"
        return 0
    fi
    if [ -d "/home/runner" ] || [ -n "${REPL_ID:-}" ]; then
        log_info "Replit/Killercoda — установка системных пакетов не нужна"
        return 0
    fi
    if [ ! -f /etc/debian_version ] && [ ! -f /etc/lsb-release ]; then
        log_warn "не Debian/Ubuntu — пропускаю установку пакетов"
        return 0
    fi

    mkdir -p "$HOME/.cloudshell" && : > "$HOME/.cloudshell/no-apt-get-warning"
    apt-get update -y >/dev/null 2>&1
    if ! apt-get install -y sudo >/dev/null 2>&1; then
        log_warn "не удалось поставить sudo, пробую без него"
    fi

    out="$(sudo -n apt-get update -y --fix-missing 2>&1 || apt-get update -y --fix-missing 2>&1)" || {
        if printf '%s' "$out" | grep -qiE 'dl\.yarnpkg\.com|NO_PUBKEY 62D54FD4003F6525|is not signed'; then
            log_warn "репозиторий yarn ломает apt update — удаляю и повторяю"
            sudo -n rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null
            sudo -n apt-get update -y --fix-missing >/dev/null 2>&1 || apt-get update -y --fix-missing >/dev/null 2>&1
        fi
    }
    sudo -n apt-get install -y wireguard-tools jq wget qrencode --fix-missing >/dev/null 2>&1 || \
        apt-get install -y wireguard-tools jq wget qrencode --fix-missing >/dev/null 2>&1
    return 0
}

# =============================================================================
#  SECTION 8. Регистрация в Cloudflare
# =============================================================================

cf_ins() { curl -s -H 'User-Agent: okhttp/3.12.1' -H 'Content-Type: application/json' -X "$1" "${AWG_API}/$2" "${@:3}"; }
cf_sec() { cf_ins "$1" "$2" -H "Authorization: Bearer $3" "${@:4}"; }

register_warp() {
    local priv="$1" pub="$2" response id token

    log_step "Регистрация в Cloudflare WARP"

    if ! have curl; then
        die "curl не найден. Поставь curl или запусти скрипт в окружении с ним."
    fi
    have jq || log_warn "jq не найден — парсинг ответа через sed (может быть хрупко)"

    response="$(cf_ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%TZ)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")"
    if [ -z "$response" ]; then
        log_err "Cloudflare не ответил. Проверь сеть/прокси (в РФ api.cloudflareclient.com бывает заблокирован)."
        return 1
    fi

    id="$(json_get "$response" '.result.id' 'id')"
    token="$(json_get "$response" '.result.token' 'token')"

    if [ -z "$id" ] || [ "$id" = "null" ] || [ -z "$token" ] || [ "$token" = "null" ]; then
        log_err "регистрация не удалась. Ответ Cloudflare:"
        printf '%s\n' "$response" | head -c 2000
        printf '\n'
        return 1
    fi

    response="$(cf_sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')"
    CF_PEER_PUB="$(json_get "$response" '.result.config.peers[0].public_key' 'public_key')"
    CF_V4="$(json_get "$response" '.result.config.interface.addresses.v4' 'v4')"
    CF_V6="$(json_get "$response" '.result.config.interface.addresses.v6' 'v6')"

    if [ -z "$CF_PEER_PUB" ] || [ "$CF_PEER_PUB" = "null" ]; then
        log_err "не получил public_key пира от WARP. Ответ:"
        printf '%s\n' "$response" | head -c 2000
        printf '\n'
        return 1
    fi
    if [ -z "$CF_V4" ] || [ "$CF_V4" = "null" ]; then
        log_err "не получил IPv4-адрес от WARP"
        return 1
    fi

    log_ok "регистрация успешна, адрес ${CF_V4}${CF_V6:+, ${CF_V6}}"
    return 0
}

# =============================================================================
#  SECTION 9. Main
# =============================================================================

main() {
    local priv pub v4 v6 conf link outname tty

    if [ "$SELF_TEST" -eq 1 ]; then
        run_self_test
        exit $?
    fi

    # Версия
    if [ "$AWG_VERSION_SET" -eq 0 ]; then
        if [ -t 0 ]; then
            interactive_menu
        else
            AWG_VERSION="1.5"
        fi
    fi

    # Пресет: сначала подставляем целиком, потом перекрываем явными --jc/--jmin/--jmax
    if ! apply_preset "$PRESET"; then
        die "неизвестный пресет '${PRESET}' (доступно: warp-legacy, balanced, light, stealth)"
    fi
    if [ -n "$JC" ]; then
        if ! printf '%s' "$JC" | grep -Eq '^[0-9]+$'; then die "--jc: нужно целое число, получено '${JC}'"; fi
    fi
    if [ -n "$JMIN" ]; then
        if ! printf '%s' "$JMIN" | grep -Eq '^[0-9]+$'; then die "--jmin: нужно целое число, получено '${JMIN}'"; fi
    fi
    if [ -n "$JMAX" ]; then
        if ! printf '%s' "$JMAX" | grep -Eq '^[0-9]+$'; then die "--jmax: нужно целое число, получено '${JMAX}'"; fi
    fi

    # HeaderProtectionKey для режима awg/3.1
    if [ "$AWG_VERSION" = "3.1" ] && [ "$MODE" = "awg" ] && [ -z "$HPK_OVERRIDE" ]; then
        HPK_OVERRIDE="$(gen_b64_key)"
        [ -n "$HPK_OVERRIDE" ] || die "не удалось сгенерировать HeaderProtectionKey"
        log_info "HeaderProtectionKey сгенерирован (переопредели через --hpk, если нужен свой)"
    fi

    # Проверка входных параметров
    case "$MTU" in ''|*[!0-9]*) die "--mtu: нужно целое число, получено '${MTU}'" ;; esac
    case "$ENDPOINT" in *:*) ;; *) die "--endpoint: нужен формат host:port, получено '${ENDPOINT}'" ;; esac
    case "${ENDPOINT##*:}" in ''|*[!0-9]*) die "--endpoint: порт должен быть числом" ;; esac
    if [ "$MODE" = "awg" ] && [ "$AWG_VERSION" = "1.5" ]; then
        log_warn "--mode=awg с версией 1.5: S3/S4 и диапазоны H будут отброшены как фичи 2.x"
    fi

    if [ -n "$I1_OVERRIDE" ]; then
        if ! validate_i_spec "$I1_OVERRIDE" "$AWG_VERSION" "--i1"; then
            die "некорректная спецификация I1"
        fi
    fi

    # ── Ключи ─────────────────────────────────────────────────────────────
    priv="$PRIV_KEY_ARG"
    if [ "$HAVE_PRIV" -eq 0 ] || [ -z "$priv" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            priv="yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk="
            log_warn "--dry-run: использован тестовый приватный ключ"
        else
            install_deps
            priv="$(gen_private_key)" || die "не удалось сгенерировать приватный ключ (нужен awg/wg или /dev/urandom)"
        fi
    fi
    if ! is_b64_key "$priv"; then
        log_warn "приватный ключ '$priv' не похож на 32-байтовый base64 (44 символа)"
    fi

    pub="$PUB_KEY_ARG"
    if [ "$HAVE_PUB" -eq 0 ] || [ -z "$pub" ]; then
        if [ -n "$priv" ] && have wg; then
            pub="$(printf '%s' "$priv" | wg pubkey 2>/dev/null | tr -d '\n')"
        fi
        if [ -z "$pub" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                pub="hHmD7B3vF0mQp1cR8sT2uV5wX6yZ0aB3cD4eF5gH6I8="
            else
                die "не удалось получить публичный ключ: нет wg/awg и не передан аргументом"
            fi
        fi
    fi

    # ── Данные WARP ───────────────────────────────────────────────────────
    if [ "$DRY_RUN" -eq 1 ]; then
        v4="172.16.0.2"; v6="2606:4700:110:8a1b:c0de:1234:5678:9abc"
        log_warn "--dry-run: использован тестовый адрес WARP, сеть не трогается"
    else
        CF_PEER_PUB=""; CF_V4=""; CF_V6=""
        install_deps
        register_warp "$priv" "$pub" || exit 1
        v4="$CF_V4"; v6="$CF_V6"; pub="$CF_PEER_PUB"
    fi

    # ── Сборка и проверка ─────────────────────────────────────────────────
    conf="$(render_conf "$priv" "$pub" "$v4" "$v6")" || die "не удалось собрать конфиг"
    if ! validate_conf "$conf" "$AWG_VERSION"; then
        die "конфиг не прошёл валидацию — сохраняю как есть в ${OUT_FILE:-warp.conf} для разбора"
    fi

    det="$(detect_awg_version "$conf")"
    outname="$OUT_FILE"
    if [ -z "$outname" ]; then
        if [ "$det" = "wg" ]; then outname="warp-wireguard.conf"
        else outname="warp-awg${det}.conf"; fi
    fi

    printf '%s\n' "$conf" > "$outname" || die "не удалось записать $outname"
    log_ok "конфиг записан: $outname"

    # Имя туннеля в мобильном AmneziaWG не длиннее 15 символов
    if [ "${#CONF_NAME}" -gt 15 ]; then
        log_warn "имя '${CONF_NAME}' длиннее 15 символов — в мобильном AmneziaWG его придётся переименовать"
    fi

    # ── Вывод ─────────────────────────────────────────────────────────────
    tty=0; [ -t 1 ] && tty=1
    printf '\n'
    if [ "$tty" -eq 1 ]; then
        printf '%s########## НАЧАЛО КОНФИГА (%s) ##########%s\n' "$C_BLD" "${det:-WireGuard}" "$C_RST"
    fi
    printf '%s\n' "$conf"
    if [ "$tty" -eq 1 ]; then
        printf '%s########## КОНЕЦ КОНФИГА ##########%s\n\n' "$C_BLD" "$C_RST"
    fi

    if [ "$EMIT_LINK" -eq 1 ]; then
        link="$(build_vpn_link "$conf" "$priv" "$pub" "$v4" "$v6")"
        if [ "$tty" -eq 1 ]; then
            printf '%s########## СТРОКА ДЛЯ AMNEZIAVPN ##########%s\n' "$C_BLD" "$C_RST"
        fi
        printf '%s\n' "$link"
        if [ "$tty" -eq 1 ]; then
            printf '%s########## КОНЕЦ СТРОКИ ДЛЯ AMNEZIAVPN ##########%s\n\n' "$C_BLD" "$C_RST"
        fi
    fi

    conf_b64="$(printf '%s' "$conf" | b64)"
    printf '\n'
    printf 'Скачать конфиг файлом: %s?filename=WARP%%2D%s.conf&content=%s\n' \
        "$DEF_DOWNLOAD_BASE" "${det:-wireguard}" "$conf_b64"
    printf 'Импортируйте конфиг в AmneziaWG или AmneziaVPN.\n'

    if [ "$det" != "wg" ]; then
        printf 'Версия протокола в конфиге: AmneziaWG %s\n' "$det"
    else
        printf 'Версия протокола: обычный WireGuard (AWG-ключей нет).\n'
    fi
    if [ "$AWG_VERSION" = "3.1" ] && [ "$MODE" = "warp" ]; then
        printf '  on-wire параметры оставлены нейтральными (WARP не понимает AWG),\n'
        printf '  версия 3.1 помечена клиентскими ключами: тайминги + ContentPaddingAddition = 0.\n'
    fi
    if [ "$MODE" = "awg" ]; then
        printf '  ВНИМАНИЕ: --mode=awg даёт честно обфусцированный конфиг.\n'
        printf '  Против WARP он НЕ поднимется (сервер не понимает AWG). Используй со своим AWG-сервером.\n'
    fi
    printf '\n'
    printf 'Подробный гайд: %s\n' "$WIKI_URL"
    printf 'Вопросы: %s\n' "$CHAT_URL"

    if [ "${CODESPACES:-}" = "true" ]; then
        log_info "GitHub Codespaces: конфиг сохранён в ${outname}, скачай его в панели файлов слева."
    fi
    if [ -d "/home/runner" ] || [ -n "${REPL_ID:-}" ]; then
        log_info "Replit: конфиг сохранён в ${outname}, скачай через File Tree → ПКМ → Download."
    fi

    # Легаси-имя, чтобы старые инструкции продолжали работать
    if [ "$outname" != "warp.conf" ] && [ -n "${REPL_ID:-}" -o "${CODESPACES:-}" = "true" ]; then
        cp -f "$outname" warp.conf 2>/dev/null && log_info "дополнительно скопирован как warp.conf"
    fi

    return $RC
}

main "$@"
