# agy-tier-fix

**English** · [Русский](README.ru.md)

A small mitmproxy addon that fixes **tier selection** in the Antigravity CLI
(`agy`): the client onboards onto the purchased **standard-tier** instead of
**free-tier**.

## Problem

`v1internal:loadCodeAssist` returns something like this for the account:

```json
{
  "allowedTiers":    [ { "id": "standard-tier", "isDefault": true, "...": "..." } ],
  "ineligibleTiers": [ { "tierId": "free-tier",
                         "reasonCode": "UNSUPPORTED_LOCATION" } ]
}
```

The server itself marks **standard-tier as allowed and default**, and free-tier
as ineligible. But the client, seeing free-tier in `ineligibleTiers`, bails out
with an error like `Eligibility check failed: ... not available in your
location` and never onboards onto standard-tier.

This is a client-side tier-selection bug: the tier the server grants is not
used. The addon fixes exactly that.

> For users who **actually have standard-tier** in `allowedTiers`. The server
> stays the source of truth — it validates onboarding and generation itself.

## What the addon does

`tier-fix.py`:

1. **`loadCodeAssist` (response)** — removes the `ineligibleTiers` block so the
   client doesn't bail and picks `standard-tier` from `allowedTiers`.
2. **`onboardUser` (request)** — sets `tierId=standard-tier` if the client sent
   a different one (belt and suspenders).

## Requirements

- [mitmproxy](https://mitmproxy.org/) (`mitmdump`) 11+
- `agy` in `PATH` (or set `AGY_BIN=/path/to/agy`)
- `bash`, `ss` (iproute2)

## Usage

```bash
git clone <this-repo> agy-tier-fix
cd agy-tier-fix
chmod +x agy-tier.sh

./agy-tier.sh                 # interactive
./agy-tier.sh -p "say ok"     # one-off prompt
```

The script automatically:

- generates the mitmproxy CA on first run (`~/.mitmproxy`);
- builds a CA bundle `system roots + mitmproxy CA` and hands it to `agy` via
  `SSL_CERT_FILE` so the Go client trusts mitm (the system trust store is **not**
  modified);
- starts `mitmdump` with the addon on `127.0.0.1:8085` (background, reused);
- runs `agy` through that proxy.

TLS is intercepted **only** for the API host (`--allow-hosts`), so anything else
`agy` (or a child process like `gh`/`git`) talks to passes through untouched with
real certificates.

Handy alias:

```bash
alias agys='/path/to/agy-tier-fix/agy-tier.sh'
```

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGY_BIN` | `agy` from PATH / `~/.local/bin/agy` | path to the agy binary |
| `AGY_MITM_PORT` | `8085` | local mitmproxy port |

## Egress / region

The addon only fixes tier selection and **does not touch egress** — the API
connection uses your normal system DNS and route. If generation fails with
`400 "User location is not supported for the API use."`, the model request is
leaving from a region where the API is unavailable. That is not about tiers and
not about this tool: it does not spoof location. The connection must genuinely
originate from a supported region by your own lawful means (VPN/network) for that
call to pass.

## Stop

```bash
kill "$(cat mitm-tier.pid)"
```

## Notes

- `agy` is a Go binary and natively honors `HTTP(S)_PROXY` / `SSL_CERT_FILE`, so
  everything is configured through environment variables, without modifying the
  system.
- proxychains does not work for agy: it hooks libc `connect()`, while the Go
  runtime calls `connect()` directly.

## Windows

### Automated Installation (PowerShell)

Run in PowerShell to install to a standalone folder (`$env:LOCALAPPDATA\agy-tier-fix`) and set up the `agys` alias:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

After reopening PowerShell:
```powershell
agys -p "say ok"
```

The script automatically manages `mitmdump`'s lifecycle, starting it before `agy` and stopping it upon completion.

To uninstall completely:
```powershell
powershell -File "$env:LOCALAPPDATA\agy-tier-fix\uninstall.ps1"
```

### Manual Execution

`agy` on Windows uses the system certificate store and ignores `SSL_CERT_FILE`,
so trust the mitmproxy CA once, then run manually:

```powershell
mitmdump                                   # run once, Ctrl+C — generates %USERPROFILE%\.mitmproxy\
certutil -addstore -user Root "$env:USERPROFILE\.mitmproxy\mitmproxy-ca-cert.cer"

# window 1
mitmdump -s tier-fix.py --listen-host 127.0.0.1 --listen-port 8085 --allow-hosts 'daily-cloudcode-pa\.googleapis\.com'
# window 2
$env:HTTP_PROXY="http://127.0.0.1:8085"; $env:HTTPS_PROXY="http://127.0.0.1:8085"
agy -p "say ok"
```
