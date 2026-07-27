# agy-tier-fix

[English](README.md) · **Русский**

Небольшой mitmproxy-аддон, который чинит **выбор тарифа** в Antigravity CLI
(`agy`): клиент онбордится на купленный **standard-tier** вместо **free-tier**.

## Проблема

Запрос `v1internal:loadCodeAssist` возвращает по аккаунту примерно такое:

```json
{
  "allowedTiers":    [ { "id": "standard-tier", "isDefault": true, "...": "..." } ],
  "ineligibleTiers": [ { "tierId": "free-tier",
                         "reasonCode": "UNSUPPORTED_LOCATION" } ]
}
```

То есть сервер сам помечает **standard-tier как разрешённый и дефолтный**, а
free-tier — как недоступный. Но клиент, увидев free-tier в `ineligibleTiers`,
обрывается с ошибкой вида `Eligibility check failed: ... not available in your
location` и не доходит до онбординга на standard-tier.

Это ошибка выбора тарифа на стороне клиента: тариф, который сервер выдаёт, не
используется. Аддон её и правит.

> Утилита для тех, у кого **standard-tier реально есть** в `allowedTiers`. Сервер
> остаётся источником истины: онбординг и генерацию он проверяет сам.

## Что делает аддон

`tier-fix.py`:

1. **`loadCodeAssist` (ответ)** — удаляет блок `ineligibleTiers`, чтобы клиент
   не обрывался и брал `standard-tier` из `allowedTiers`.
2. **`onboardUser` (запрос)** — на всякий случай ставит `tierId=standard-tier`,
   если клиент прислал другой.

## Требования

- [mitmproxy](https://mitmproxy.org/) (`mitmdump`) 11+
- `agy` в `PATH` (или укажи `AGY_BIN=/путь/к/agy`)
- `bash`, `ss` (iproute2)

## Использование

```bash
git clone <this-repo> agy-tier-fix
cd agy-tier-fix
chmod +x agy-tier.sh

./agy-tier.sh                 # интерактивно
./agy-tier.sh -p "say ok"     # разовый промпт
```

Скрипт сам:

- при первом запуске генерирует mitmproxy CA (`~/.mitmproxy`);
- собирает CA-бандл `системные корни + mitmproxy CA` и отдаёт его `agy` через
  `SSL_CERT_FILE` — чтобы Go-клиент доверял mitm (системное хранилище **не**
  меняется);
- поднимает `mitmdump` с аддоном на `127.0.0.1:8085` (фоново, переиспользуется);
- запускает `agy` через этот прокси.

TLS перехватывается **только** у API-хоста (`--allow-hosts`), поэтому всё
остальное, куда ходит `agy` (или дочерний `gh`/`git`), проходит насквозь с
настоящими сертификатами.

Удобный алиас:

```bash
alias agys='/path/to/agy-tier-fix/agy-tier.sh'
```

### Переменные

| Переменная | По умолчанию | Назначение |
|-----------|--------------|-----------|
| `AGY_BIN` | `agy` из PATH / `~/.local/bin/agy` | путь к бинарю agy |
| `AGY_MITM_PORT` | `8085` | порт локального mitmproxy |

## Egress / регион

Аддон правит только выбор тарифа и **не трогает egress** — соединение к API идёт
обычным системным резолвом и маршрутом. Если генерация упирается в
`400 "User location is not supported for the API use."`, значит запрос к модели
уходит из региона, где API недоступен. Это уже не про тариф и не про эту утилиту:
она локацию не подделывает. Соединение должно реально исходить из поддерживаемого
региона твоим законным способом (VPN/сеть) — тогда вызов проходит.

## Остановить

```bash
kill "$(cat mitm-tier.pid)"
```

## Примечания

- `agy` — Go-бинарь и нативно уважает `HTTP(S)_PROXY` / `SSL_CERT_FILE`; поэтому
  всё настраивается переменными окружения, без правки системы.
- proxychains для agy не работает: он хукает libc `connect()`, а Go зовёт
  `connect()` напрямую.

## Windows

`agy` под Windows берёт корни из системного хранилища и игнорирует
`SSL_CERT_FILE`, поэтому доверие к mitm-CA добавляется один раз, дальше — вручную:

```powershell
mitmdump                                   # запустить раз, Ctrl+C — создаст %USERPROFILE%\.mitmproxy\
certutil -addstore -user Root "$env:USERPROFILE\.mitmproxy\mitmproxy-ca-cert.cer"

# окно 1
mitmdump -s tier-fix.py --listen-host 127.0.0.1 --listen-port 8085 --allow-hosts 'daily-cloudcode-pa\.googleapis\.com'
# окно 2
$env:HTTP_PROXY="http://127.0.0.1:8085"; $env:HTTPS_PROXY="http://127.0.0.1:8085"
agy -p "say ok"
```
