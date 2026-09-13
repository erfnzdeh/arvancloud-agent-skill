# CDN / DNS (4.0) + TLS certificates

Base URL: `https://napi.arvancloud.ir/cdn/4.0`. DNS management lives under the CDN 4.0 API.
Auth: `Authorization: Apikey <uuid>` (see SKILL.md for resolving and normalizing the key).
Spec: `https://www.arvancloud.ir/api-docs/cdn-4.0.yml` (version 4.181.3 when checked, 156 paths).

> The ReDoc page at `https://www.arvancloud.ir/api/cdn/4.0` often times out. Fetch the
> spec file or hit the live API directly.

Rows marked **live** were confirmed with read-only calls on 2026-09-13. Everything else is
taken from the spec. Mutations were not live-tested.

## Envelope and pagination

List endpoints return `{"data": [...], "links": {...}, "meta": {"current_page", "last_page", "per_page", "total", ...}}` (**live**).
Page with `?per_page=100&page=N` until `page == meta.last_page`. `GET /domains` also accepts
`search`, `plans`, `statuses`, `sort_by`, `order`.

## Quick start

```bash
S="${CLAUDE_SKILL_DIR}/scripts/arvan-api.sh"

"$S" "/cdn/4.0/domains?per_page=100" | jq -r '.data[] | "\(.domain) \(.status) plan=\(.plan_level)"'
"$S" /cdn/4.0/domains/example.ir | jq '.data | {status, ns_keys, current_ns, dns_cloud}'
"$S" "/cdn/4.0/domains/example.ir/dns-records?per_page=100" | jq -c '.data[] | {id, type, name, value, ttl, cloud}'
```

Plain curl works the same way: `curl -s -H "Authorization: Apikey $TOKEN" "https://napi.arvancloud.ir/cdn/4.0/domains?per_page=100"`.

## Domain endpoints

| Method | Path | Notes |
|---|---|---|
| GET | `/domains` | list (**live**) |
| GET | `/domains/{domain}` | status, `ns_keys`, `current_ns`, `plan_level`, `type` (**live**) |
| POST | `/domains/dns-service` | add a domain. Body `{"domain": "example.ir", "domain_type": "full", "plan_level": 1}`. `domain_type: partial` is a CNAME setup for subdomains (Growth plan or higher). `plan_level`: 0 Traffic, 1 Basic, 2 Growth, 3 Professional, 4 Enterprise. `import_dns_records` defaults to **true**: Arvan then auto-creates A records for `@` and `www` and may add a `*` record. Send `false` if the user did not ask for that. |
| GET | `/domains/{domain}/ns-keys/check` | re-check nameserver delegation (replaces the deprecated `PUT /domains/{domain}/dns-service/check-ns`) |
| PUT, DELETE | `/domains/{domain}/ns-keys` | custom nameserver keys |
| DELETE | `/domains/{domain}?id=<domain-uuid>` | remove a domain. The spec requires the domain's `id` (from `GET /domains/{domain}`) as a query parameter. Destructive, confirm first. |
| GET | `/plans`, `/domains/{domain}/plans` | plan options and `needed_balance` (both **live**) |

## DNS record endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/domains/{domain}/dns-records` | list records (**live**) |
| POST | `/domains/{domain}/dns-records` | create record |
| GET | `/domains/{domain}/dns-records/{id}` | one record |
| PUT | `/domains/{domain}/dns-records/{id}` | update record |
| DELETE | `/domains/{domain}/dns-records/{id}` | delete record |
| PUT | `/domains/{domain}/dns-records/{id}/cloud` | body `{"cloud": true}` toggles CDN proxy |
| POST | `/domains/{domain}/dns-records/import` | multipart field `f_zone_file` (BIND zone file) |
| GET | `/domains/{domain}/dns-records/export` | **live**: returns `405` with `required_plan: 3` on the Basic plan (Professional needed) |
| GET | `/domains/{domain}/dns-records/dnssec` | `{"enabled": false, "ds": null}` (**live**) |
| PUT | `/domains/{domain}/dns-records/dnssec/actions` | body `{"enable": true, "rotate": false}` |

There is no `/domains/{domain}/ns-records` or `/domains/{domain}/dnssec` route (**live** 404 / not in spec).

## Record fields

- `id`: UUID, read-only.
- `name`: **subdomain label only, not the FQDN.** `@` for the apex; e.g. `www`, `_acme-challenge`, `_acme-challenge.meet`.
- `type`: the spec enumerates lowercase (`a`, `aaaa`, `ns`, `txt`, `cname`, `aname`, `mx`, `srv`, `spf`, `dkim`, `ptr`, `tlsa`, `caa`) and responses are lowercase (**live**). Send lowercase.
- `value`: a typed object or array; shape depends on `type` (below).
- `ttl`: one of `120, 180, 300, 600, 900, 1800, 3600, 7200, 18000, 43200, 86400, 172800, 432000`.
- `cloud`: bool, whether traffic is proxied through the Arvan CDN (`false` = DNS only).
- Optional: `upstream_https` (`default|auto|http|https`), `ip_filter_mode` (`{count: single|multi, order: none|weighted|rr, geo_filter: none|location|country}`).
- Read-only: `is_protected` (protected records cannot be modified or deleted by the user).

### `value` shapes by type (from the spec schemas)

```jsonc
// a / aaaa: ARRAY of objects. ip required; port, weight, country optional.   (live)
{ "type": "a",     "name": "www", "value": [ { "ip": "1.2.3.4" } ], "ttl": 3600 }
// cname: OBJECT. host and host_header ("source" | "dest") required.            (live shape)
{ "type": "cname", "name": "blog", "value": { "host": "target.example.com", "host_header": "source" }, "ttl": 3600 }
// aname: OBJECT with LOCATION, not host. location and host_header required.   (live shape)
{ "type": "aname", "name": "@", "value": { "location": "target.example.com", "host_header": "source" }, "ttl": 3600 }
// ns: OBJECT                                                                    (live shape)
{ "type": "ns",    "name": "delegated", "value": { "host": "ns1.example.com" }, "ttl": 3600 }
// txt / spf / dkim: OBJECT with text                                            (txt live)
{ "type": "txt",   "name": "_acme-challenge", "value": { "text": "token..." }, "ttl": 120 }
// mx: OBJECT (not an array). host and priority required.
{ "type": "mx",    "name": "@", "value": { "host": "mail.example.com", "priority": 10 }, "ttl": 3600 }
// srv: OBJECT with TARGET (not host). target and port required.
{ "type": "srv",   "name": "_sip._tcp", "value": { "target": "sip.example.com", "port": 5060, "priority": 10, "weight": 5 }, "ttl": 3600 }
// caa: OBJECT. tag is issue | issuewild | iodef.
{ "type": "caa",   "name": "@", "value": { "tag": "issue", "value": "letsencrypt.org" }, "ttl": 3600 }
// tlsa: OBJECT with usage, selector, matching_type, certificate (all required)
// ptr:  OBJECT with domain
```

When updating, start from the record returned by `GET` and change only what you need.

## Examples

```bash
S="${CLAUDE_SKILL_DIR}/scripts/arvan-api.sh"
D=example.ir

# 1. Show the exact request and get the user's OK first.
"$S" --dry-run -d '{"type":"txt","name":"_acme-challenge","value":{"text":"TOKEN_HERE"},"ttl":120}' "/cdn/4.0/domains/$D/dns-records"

# 2. After an explicit yes:
"$S" --allow-write -d '{"type":"txt","name":"_acme-challenge","value":{"text":"TOKEN_HERE"},"ttl":120}' "/cdn/4.0/domains/$D/dns-records"
"$S" --allow-write -d '{"type":"a","name":"www","value":[{"ip":"1.2.3.4"}],"ttl":3600}' "/cdn/4.0/domains/$D/dns-records"
"$S" --allow-write -X PUT -d '{"cloud":true}' "/cdn/4.0/domains/$D/dns-records/<record-id>/cloud"
"$S" --allow-write -X DELETE "/cdn/4.0/domains/$D/dns-records/<confirmed-record-id>"

# Dry-run list of stale apex _acme-challenge TXT records (keeps subdomain ones); delete ids one by one after confirmation.
"$S" "/cdn/4.0/domains/$D/dns-records?per_page=100" \
| jq -r '.data[] | select(.type=="txt" and .name=="_acme-challenge") | "\(.id) \(.value.text)"'
```

## Other per-domain settings (reads verified live)

| Area | Read | Write |
|---|---|---|
| Caching | `GET /domains/{domain}/caching` (**live**) | `PATCH /domains/{domain}/caching` |
| Cache purge | none | `POST /domains/{domain}/caching/purge` with `{"purge":"all"}` or `{"purge":"individual","purge_urls":["https://..."]}` (max 50 URLs). `"purge":"tags"` with `purge_tags` also exists but is deprecated. The spec also keeps a legacy `DELETE /domains/{domain}/caching?purge=all`. There is **no** `DELETE /caching/purge`. |
| SSL/TLS | `GET /domains/{domain}/ssl` (**live**), `/ssl/certificates`, `/ssl/orders` | `PATCH /ssl`, `POST /ssl/certificates`, `POST /ssl/issue` |
| Firewall | `GET /domains/{domain}/firewall/settings` (**live**), `/firewall/rules` | `PATCH /firewall/settings`, rules CRUD |
| Rate limit | `GET /domains/{domain}/rate-limit/settings` (**live**), `/rate-limit/rules` | `PATCH /rate-limit/settings`, rules CRUD |
| DDoS | `GET /domains/{domain}/ddos/settings`, `/ddos/rules` | `PATCH /ddos/settings`, rules CRUD |
| Page rules | `GET /domains/{domain}/page-rules` (**live**) | CRUD, `DELETE /page-rules/{id}/purge` |
| Load balancers | `GET /domains/{domain}/load-balancers`, pools, origins | CRUD |
| Health checks | `GET /domains/{domain}/health-checks`, `/reports/summary` | CRUD |
| Acceleration | `GET /domains/{domain}/acceleration` | `PATCH` |
| Reports | `GET /domains/{domain}/reports/traffics`, `/reports/attacks`, `/reports/error-logs`, `/reports/dns-requests` | none |
| Account-wide | `GET /apps` (**live**), `GET /metric-exporters` (**live**), `GET /account/firewall-rules` | per spec |

## TLS certificates: Let's Encrypt wildcard via DNS-01

`acme.sh` ships a built-in ArvanCloud DNS plugin, `dns_arvan`, which uses the same DNS API
(`https://napi.arvancloud.ir/cdn/4.0/domains`), creates the `_acme-challenge` TXT record with
`ttl: 120`, and deletes it afterwards.

It sends `Authorization: $Arvan_Token` **verbatim** (checked in `dnsapi/dns_arvan.sh`), so the
token must already include the `Apikey ` prefix:

```bash
export Arvan_Token="Apikey XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"   # same machine-user key
```

### Issue a root + wildcard cert

```bash
VAR_NAME="${CONFIRMED_VAR_NAME:-ARVAN_KEY}"
RAW_KEY="${!VAR_NAME}"
TOKEN="${RAW_KEY#apikey }"; TOKEN="${TOKEN#Apikey }"
export Arvan_Token="Apikey $TOKEN"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt        # one-time
~/.acme.sh/acme.sh --issue --dns dns_arvan \
  -d example.ir -d '*.example.ir' --server letsencrypt
```

acme.sh saves `Arvan_Token` into its account config for renewals. Certs land (default) under
`~/.acme.sh/<domain>_ecc/`: `fullchain.cer`, `<domain>.key`, `ca.cer`, `<domain>.cer`.

### Auto-renew + deploy (hooks come from config, not this file)

`acme.sh` installs a daily cron that renews near expiry. Deployment to remote servers is wired
per domain with `--install-cert --reloadcmd`, which runs after each renewal.

**Where the per-domain deploy target lives:** `~/.config/arvan/config.json` under
`deployHooks[<domain>]`, shaped `{ sshHost, certDirs[], reloadCmd }`. The skill ships no
hardcoded domains. Build the `--reloadcmd` from that entry:

```bash
DOMAIN=example.ir
CFG=~/.config/arvan/config.json
HOST=$(jq -r ".deployHooks[\"$DOMAIN\"].sshHost"   "$CFG")
RELOAD=$(jq -r ".deployHooks[\"$DOMAIN\"].reloadCmd" "$CFG")
DIRS=$(jq -r ".deployHooks[\"$DOMAIN\"].certDirs[]" "$CFG")   # array: deploy into each, then reload

RELOADCMD="for d in $DIRS; do scp ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key $HOST:\"\$d\"; done && ssh $HOST '$RELOAD'"
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc --reloadcmd "$RELOADCMD"
```

This sketch assumes `certDirs` contain no spaces and `reloadCmd` contains no single quotes; quote accordingly otherwise. Adjust the copy/reload shape to the entry (some hosts reload nginx via `systemctl`, others via
`docker exec ... nginx -s reload`). When the user sets up a new domain, add its hook to the
config (with their OK) rather than editing this skill.

## Verification before DNS-01

- **List domains live** (`GET /domains`); don't rely on a remembered list.
- `GET /domains/{domain}` shows `ns_keys` (what Arvan expects) and `current_ns` (what it sees).
  A domain can be `status: active` and still not be published by Arvan's authoritative
  nameservers. Confirm real resolution first: `dig SOA <domain> @8.8.8.8`.
- DNS-01 validation depends on Let's Encrypt (outside Iran) resolving the TXT record; local
  Iranian network DNS quirks don't affect it.
- Iran's DNS filtering returns forged IPs `10.10.34.34/.35/.36`, not empty responses. An empty
  SOA/NS means a delegation/publishing problem, not censorship.
