# CDN / DNS (4.0) + TLS certificates

Base URL: `https://napi.arvancloud.ir/cdn/4.0` — DNS management lives under the CDN 4.0 API.
Auth: `Authorization: Apikey <uuid>`. Resolve the real env var from `~/.config/arvan/config.json`, then normalize bare UUID, `apikey ...`, or `Apikey ...` values to a canonical header.

> The ReDoc page at `https://www.arvancloud.ir/api/cdn/4.0` often times out. Fetch the
> spec from `https://www.arvancloud.ir/api-docs/cdn-4.0.yml` or hit the live API directly.

Response envelope for list endpoints: `{ "data": [...], "meta": { "total": N, ... } }`.

## Quick start

```bash
VAR_NAME="${CONFIRMED_VAR_NAME:-ARVAN_KEY}"
RAW_KEY="${!VAR_NAME}"
TOKEN="${RAW_KEY#apikey }"; TOKEN="${TOKEN#Apikey }"
AUTH_HEADER="Apikey $TOKEN"
BASE="https://napi.arvancloud.ir/cdn/4.0"

# List all domains on the account
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/domains?per_page=100"

# Get one domain's details (NS, status, dns_cloud, plan, ...)
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/domains/<domain>"

# List DNS records for a domain
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/domains/<domain>/dns-records?per_page=100"
```

## DNS record endpoints

| Method | Path | Purpose |
|---|---|---|
| GET    | `/domains/{domain}/dns-records`        | list records |
| POST   | `/domains/{domain}/dns-records`        | create record |
| PUT    | `/domains/{domain}/dns-records/{id}`   | update record |
| DELETE | `/domains/{domain}/dns-records/{id}`   | delete record |
| PUT    | `/domains/{domain}/dns-records/{id}/cloud` | toggle CDN proxy/cloud for one record |
| POST   | `/domains/{domain}/dns-records/import` | import a BIND-style zone file as multipart `f_zone_file` |
| GET    | `/domains/{domain}/dns-records/export` | export zone records |
| GET    | `/domains/{domain}/dns-records/dnssec` | get DNSSEC status and DS records |
| PUT    | `/domains/{domain}/dns-records/dnssec/actions` | enable/disable DNSSEC |

## Record fields

- `id` — UUID
- `name` — **subdomain label only, NOT the FQDN.** Use `@` for the apex; e.g. `www`, `_acme-challenge`, `_acme-challenge.meet`.
- `type` — lowercase in responses: `a`, `aaaa`, `cname`, `aname`, `txt`, `spf`, `mx`, `ns`, `srv`, `caa`, `tlsa`, `dkim`, …
- `value` — a **typed object**, shape depends on `type` (see below)
- `ttl` — seconds (e.g. `120`, `3600`)
- `cloud` — bool; whether traffic is proxied through Arvan CDN (`false` = DNS-only)

### `value` shapes by type

```jsonc
// A / AAAA — array of IP objects
{ "type": "a",     "name": "www",             "value": [ { "ip": "1.2.3.4" } ],                  "ttl": 3600 }
// CNAME / ANAME
{ "type": "cname", "name": "blog",            "value": { "host": "target.example.com" },         "ttl": 3600 }
// TXT
{ "type": "txt",   "name": "_acme-challenge", "value": { "text": "token..." },                   "ttl": 120  }
// SPF
{ "type": "spf",   "name": "@",               "value": { "text": "v=spf1 include:example.com ~all" }, "ttl": 3600 }
// MX — API examples vary between a single object and arrays; preserve the shape returned by GET for updates.
{ "type": "mx",    "name": "@",               "value": [ { "host": "mail.example.com", "priority": 10 } ], "ttl": 3600 }
// NS
{ "type": "ns",    "name": "delegated",       "value": { "host": "ns1.example.com" },            "ttl": 3600 }
// SRV
{ "type": "srv",   "name": "_sip._tcp",       "value": [ { "host": "sip.example.com", "port": 5060, "priority": 10, "weight": 5 } ], "ttl": 3600 }
```

POST accepts the typed `value` object. On read-back, `type` comes back lowercase and `value` mirrors the same nested shape.

## Examples

```bash
VAR_NAME="${CONFIRMED_VAR_NAME:-ARVAN_KEY}"
RAW_KEY="${!VAR_NAME}"
TOKEN="${RAW_KEY#apikey }"; TOKEN="${TOKEN#Apikey }"
AUTH_HEADER="Apikey $TOKEN"
BASE="https://napi.arvancloud.ir/cdn/4.0"

# Create a TXT record (e.g. an ACME DNS-01 challenge)
curl -s -X POST -H "Authorization: $AUTH_HEADER" -H "Content-Type: application/json" \
  -d '{"type":"TXT","name":"_acme-challenge","value":{"text":"TOKEN_HERE"},"ttl":120}' \
  "$BASE/domains/<domain>/dns-records"

# Create an A record
curl -s -X POST -H "Authorization: $AUTH_HEADER" -H "Content-Type: application/json" \
  -d '{"type":"A","name":"www","value":[{"ip":"1.2.3.4"}],"ttl":3600}' \
  "$BASE/domains/<domain>/dns-records"

# Toggle CDN proxy/cloud for one record
curl -s -X PUT -H "Authorization: $AUTH_HEADER" -H "Content-Type: application/json" \
  -d '{"cloud":true}' \
  "$BASE/domains/<domain>/dns-records/<record-id>/cloud"

# Delete a record by id
curl -s -X DELETE -H "Authorization: $AUTH_HEADER" \
  "$BASE/domains/<domain>/dns-records/<record-id>"

# Dry-run stale apex _acme-challenge TXT records (keeps subdomain ones)
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/domains/<domain>/dns-records?per_page=100" \
| python3 -c "import sys,json;[print(r['id'], r.get('value')) for r in json.load(sys.stdin)['data'] if r.get('name')=='_acme-challenge' and r.get('type')=='txt']"

# After the user confirms the ids, delete one id at a time.
curl -s -X DELETE -H "Authorization: $AUTH_HEADER" \
  "$BASE/domains/<domain>/dns-records/<confirmed-record-id>"
```

## TLS certificates — Let's Encrypt wildcard via DNS-01

`acme.sh` ships a built-in ArvanCloud DNS plugin, `dns_arvan`, which talks to the same
DNS API above and auto-creates/cleans up the `_acme-challenge` TXT records.

It reads the token from env var `Arvan_Token`, which **must include the `Apikey ` prefix**:

```bash
export Arvan_Token="Apikey XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"   # same machine-user key
```

### Issue a root + wildcard cert

```bash
VAR_NAME="${CONFIRMED_VAR_NAME:-ARVAN_KEY}"
RAW_KEY="${!VAR_NAME}"
TOKEN="${RAW_KEY#apikey }"; TOKEN="${TOKEN#Apikey }"
AUTH_HEADER="Apikey $TOKEN"
export Arvan_Token="$AUTH_HEADER"                               # if AUTH_HEADER is already normalized
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt        # one-time
~/.acme.sh/acme.sh --issue --dns dns_arvan \
  -d example.ir -d '*.example.ir' --server letsencrypt
```

Certs are saved (default) under `~/.acme.sh/<domain>_ecc/`: `fullchain.cer`,
`<domain>.key`, `ca.cer`, `<domain>.cer`.

### Auto-renew + deploy (hooks come from config, not this file)

`acme.sh` installs a daily cron (`30 13 * * *`) that renews near expiry. Deployment to
remote servers is wired per-domain with `--install-cert --reloadcmd`, which runs after
each renewal.

**Where the per-domain deploy target lives:** read it from `~/.config/arvan/config.json`
under `deployHooks[<domain>]`, which has the shape `{ sshHost, certDirs[], reloadCmd }`.
The skill ships no hardcoded domains — the user's config is the source of truth. Build the
`--reloadcmd` from that entry. For a hook that scp's the freshly-renewed cert to a remote
host and reloads a service there:

```bash
DOMAIN=example.ir
CFG=~/.config/arvan/config.json
HOST=$(jq -r ".deployHooks[\"$DOMAIN\"].sshHost"   "$CFG")
RELOAD=$(jq -r ".deployHooks[\"$DOMAIN\"].reloadCmd" "$CFG")
# certDirs is an array — deploy into each, then reload
DIRS=$(jq -r ".deployHooks[\"$DOMAIN\"].certDirs[]" "$CFG")

RELOADCMD="for d in $DIRS; do scp ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key $HOST:\"\$d\"; done && ssh $HOST '$RELOAD'"
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc --reloadcmd "$RELOADCMD"
```

Adjust the exact copy/reload shape to match the entry (some hosts reload nginx via
`systemctl`, others via `docker exec … nginx -s reload`). When the user sets up a new
domain, add its hook to the config (with their OK) rather than editing this skill.

## Verification before DNS-01

- **List domains live** (`GET /domains`) to see what's actually on the account — don't
  rely on a remembered list; it drifts.
- A domain can be `status: active` in the panel and still not be published by Arvan's
  authoritative nameservers. Confirm real resolution first: `dig SOA <domain> @8.8.8.8`.
  (A real example of this failure mode is worth recording in the config's `notes`.)
- DNS-01 validation depends on the public internet (Let's Encrypt servers, outside Iran)
  resolving the TXT record — local Iranian network DNS quirks don't affect it.
- Iran's DNS filtering returns forged IPs `10.10.34.34/.35/.36`, not empty responses. An
  empty SOA/NS means a delegation/publishing problem, not censorship.
- The `arvancloud-mcp` project lists DNSSEC as `/domains/{domain}/dnssec`, but the
  live CDN spec puts it under `/domains/{domain}/dns-records/dnssec`.
- Cache settings are under `/domains/{domain}/caching`; cache purge is a separate
  `DELETE /domains/{domain}/caching/purge` endpoint.
