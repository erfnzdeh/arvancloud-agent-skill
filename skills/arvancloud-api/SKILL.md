---
name: arvancloud-api
description: Operate ArvanCloud (arvancloud.ir) through its REST APIs, including CDN and DNS records, domains, cache purge, WAF and rate limits, Cloud Server (IaaS v3, v1 and the undocumented v2 backups), Object Storage, Edge Computing, Cloud Container, VOD, Live and Video Ads, plus Let's Encrypt DNS-01 certificates via acme.sh dns_arvan. Use when the user wants to list, create, change or delete anything on ArvanCloud, take an account inventory, find out which account a key belongs to, check quota or usage, or debug an ArvanCloud API error. Also trigger on hosts like napi.arvancloud.ir, ecc.{region}.arvanapis.ir, storage.arvanapis.ir, dejban.arvancloud.ir, an "Apikey" Authorization header, the dns_arvan plugin, or one of the user's ArvanCloud-hosted domains.
---

# ArvanCloud API

Tested reference for driving ArvanCloud's REST APIs from the command line or an agent. Each
product has its own base URL and spec, Cloud Server has three API generations, and Object Storage
has a second auth scheme. This skill gets those details right so you don't guess.

> Unofficial, community-maintained skill. Not affiliated with or endorsed by ArvanCloud. Hosts,
> paths and response shapes were checked against the published OpenAPI specs and read-only live
> calls on 2026-09-13. The live specs and API remain the source of truth.

## Setup

Keep three things separate: the **secret** (API key) lives in an environment variable,
**per-user state** (default region, cert-deploy hooks, notes) lives in a config file outside the
skill, and anything the API can tell you (domains, servers, regions) is **fetched live**.

### 1. Credentials: environment variable, never a file in the skill

Every product except the Object Storage S3 API authenticates with a **machine-user API key**:

```
Authorization: Apikey <uuid>
```

**`ARVAN_KEY` is only the default name. Don't assume that's what it's called.** Resolve the real env var every session:

1. If `~/.config/arvan/config.json` exists, read `apiKeyEnv` from it and check that the named
   var is set (`printenv "$(jq -r .apiKeyEnv ~/.config/arvan/config.json)" >/dev/null`).
2. Otherwise, or if that var is empty, try `$ARVAN_KEY`.
3. If that is also unset, **stop and ask the user** which variable holds the key (or have them
   export one). A missing key is a question, not a guess.
4. Once confirmed, write the name back so future sessions don't ask:

   ```bash
   tmp=$(mktemp) && jq --arg v "$CONFIRMED_VAR_NAME" '.apiKeyEnv = $v' ~/.config/arvan/config.json > "$tmp" && mv "$tmp" ~/.config/arvan/config.json
   ```

The var may hold a bare UUID or a copied `apikey ...` / `Apikey ...` value. The bundled scripts
normalize it; for raw curl do the same:

```bash
RAW_KEY="${!CONFIRMED_VAR_NAME}"
TOKEN="${RAW_KEY#apikey }"; TOKEN="${TOKEN#Apikey }"
curl -s -H "Authorization: Apikey $TOKEN" "https://napi.arvancloud.ir/cdn/4.0/domains?per_page=100"
```

**One key sees one account.** Users often hold keys for several accounts. Before any write, run
`GET https://dejban.arvancloud.ir/v1/me` and name the account (`data.account.name`) in the
confirmation. Treat a `401` as a bad or revoked key and ask the user to check it. A `403` is covered in the errors table below.

**Creating a key:** panel, Settings, IAM, Machine users, Create machine user. The key is shown
**once**. Assign IAM access rules per product. Docs:
https://docs.arvancloud.ir/fa/developer-tools/api/api-key and
https://docs.arvancloud.ir/en/accounts/iam/machine-user. Revoke leaked keys in the same panel page
(`panel.arvancloud.ir`; the old `npanel.arvancloud.ir` host redirects there).

### 2. Per-user state: `~/.config/arvan/config.json`

On first use, create it from the placeholder template:

```bash
mkdir -p ~/.config/arvan
[ -f ~/.config/arvan/config.json ] || cp "${CLAUDE_SKILL_DIR}/assets/config.example.json" ~/.config/arvan/config.json
```

Schema (see `assets/config.example.json`):
- `apiKeyEnv`: name of the env var holding the key (confirmed with the user, see above).
- `acmeTokenEnv`: env var acme.sh's `dns_arvan` reads (default `Arvan_Token`).
- `defaultRegion`: v3 region host to use when unspecified (`ir-central1`, `ir-northwest1`, `eu-west1`).
- `defaultAz`: AZ code for v1/v2 paths and v3 create bodies (e.g. `ir-thr-fr1`).
- `timeoutSeconds`, `maxRetries`, `backoffFactor`: used by `scripts/arvan-api.sh`. It retries only
  `429`, and for GET also `5xx` and transient network errors (never DNS or TLS failures).
- `s3AccessKeyEnv`, `s3SecretKeyEnv`, `s3Region`, `s3Endpoint`: Object Storage S3 settings. S3 uses
  separate credentials, not the machine-user key.
- `deployHooks`: `domain -> { sshHost, certDirs[], reloadCmd }` for `acme.sh --install-cert`.
- `notes`: `domain -> freeform note` for per-domain quirks.

The **secret never goes in this file**, only the names of env vars. Update the config with the
user's OK when you learn a durable fact; don't edit the skill.

### 3. Everything queryable: fetch live, don't cache

Domains, servers, records, regions and flavors drift. Query them. A stale list is worse than none.

## Bundled scripts (bash, curl, jq)

`scripts/arvan-api.sh` is a thin wrapper that resolves and normalizes the key, passes it to curl
through a private temp file (never argv or output), retries safely, and prints `HTTP <code>` plus
a hint for known errors on stderr with the body on stdout.

```bash
S="${CLAUDE_SKILL_DIR}/scripts/arvan-api.sh"
"$S" auth:/v1/me | jq '.data.account'                         # which account is this key?
"$S" "/cdn/4.0/domains?per_page=100"                          # any napi.arvancloud.ir path
"$S" v3:ir-central1/servers                                   # https://ecc.ir-central1.arvanapis.ir/v3/servers
"$S" storage:/v1/reports/storage                              # https://storage.arvanapis.ir/v1/...
"$S" --dry-run -X POST -d '{"purge":"all"}' /cdn/4.0/domains/example.ir/caching/purge
"$S" --allow-write -X POST -d '{"purge":"all"}' /cdn/4.0/domains/example.ir/caching/purge   # only after an explicit yes
```

Exit codes: `0` success (2xx), `1` HTTP or network error (redirects are reported, never followed), `2` usage, `3` key env var unset,
`4` write refused (any method other than GET/HEAD needs `--allow-write`). The key is only ever sent over
https to `*.arvancloud.ir` and `*.arvanapis.ir`; `--dry-run -d @file` prints the file's contents. Set `ARVAN_KEY_ENV=OTHER_VAR` to use a
different account's key for one call.

`scripts/arvan-inventory.sh` prints a read-only snapshot of one account: identity, servers in
every region, backups, CDN domains (all pages), Object Storage usage and buckets, Edge Computing
and VOD counts. Use it when the user asks "what do I have on ArvanCloud?".

## Product map (verified 2026-09-13)

| Product | Live base URL | OpenAPI spec (`https://www.arvancloud.ir/api-docs/...`) | Live check |
|---|---|---|---|
| CDN / DNS / Security 4.0 | `https://napi.arvancloud.ir/cdn/4.0` | `cdn-4.0.yml` | 200 |
| Cloud Server **v3** (preferred) | `https://ecc.{region}.arvanapis.ir/v3` | `iaas-3.0.0.yaml` | 200 |
| Cloud Server v1 (legacy, widest) | `https://napi.arvancloud.ir/ecc/v1` | `iaas-1.0.json` | 200 |
| Cloud Server v2 (backups, volume list) | `https://napi.arvancloud.ir/ecc/v2` | none (official CLI source) | 200 |
| Account identity | `https://dejban.arvancloud.ir/v1/me` | none (official CLI source) | 200 |
| Object Storage management | `https://storage.arvanapis.ir/v1` (plain `http` redirects) | `storage-1.0.0.yaml` | 200 |
| Object Storage S3 | `https://s3.ir-thr-at1.arvanstorage.ir`, `https://s3.ir-tbz-sh1.arvanstorage.ir`, `https://hot.ir-central1.arvanstorage.ir` | described in `storage-1.0.0.yaml` | not tested (S3 keys) |
| Edge Computing | `https://napi.arvancloud.ir/edge-computing/v1` | `ec-1.0.yaml` | 200 |
| Cloud Container (CaaS) | `https://napi.arvancloud.ir/caas/v2/zones/{ir-thr-ba1 or ir-tbz-sh1}` | `paas-1.25.json` | 428 without a namespace |
| VOD 2.0 | `https://napi.arvancloud.ir/vod/2.0` | `vod-2.0.json` | 200 |
| Live Streaming 2.0 | `https://napi.arvancloud.ir/live/2.0` | `live-2.0.json` | 404 until a Live domain exists |
| Video Ads 2.0 | `https://napi.arvancloud.ir/vads/2.0` | `vads-2.0.json` | 200 (`/channels`) |
| AIaaS | none | `aiaas-1.0.yaml` returns an HTML page, not a spec | none |

Fetch specs directly; the ReDoc pages at `arvancloud.ir/api/{product}/{version}` often time out:

```bash
mkdir -p ~/Downloads/arvancloud-api-specs
for spec in cdn-4.0.yml iaas-3.0.0.yaml iaas-1.0.json ec-1.0.yaml storage-1.0.0.yaml \
            paas-1.25.json vod-2.0.json live-2.0.json vads-2.0.json; do
  curl -sL "https://www.arvancloud.ir/api-docs/$spec" -o "$HOME/Downloads/arvancloud-api-specs/$spec"
done
```

Size for scoping (paths / operations): CDN 156/238, IaaS v3 39/45, IaaS v1 114/136, Edge 18/25,
Object Storage 34/58, CaaS 134/299, VOD 30/54, Live 29/36, Video Ads 15/29.

**Human guides** live on `docs.arvancloud.ir`, which sits behind Arvan CDN cookies (a bare
`curl -L` loops on 307). Seed cookies first:

```bash
COOKIES="$(mktemp)"
curl -s -A "Mozilla/5.0" -c "$COOKIES" "https://docs.arvancloud.ir/fa/developer-tools/api/api-usage" -o /dev/null
curl -sL -A "Mozilla/5.0" -b "$COOKIES" --max-redirs 5 "https://docs.arvancloud.ir/fa/developer-tools/api/api-usage"
```

## Regions and availability zones (live)

| v3 region host | AZ codes (v1/v2 paths, v3 `availabilityZone`) |
|---|---|
| `ir-central1` | `ir-thr-ba1` (Bamdad), `ir-thr-fr1` (Foroogh), `ir-thr-si1` (Simin), Tehran |
| `ir-northwest1` | `ir-tbz-sh1` (Shahriar), Tabriz |
| `eu-west1` | `eu-west1-a` (Goethe), Germany |
| `ir-southwest1` | `ir-southwest1-a` (Qeysar), Ahwaz. v3 host fails TLS; use v1/v2 |

v3 hosts take the **region**; v1/v2 paths take the **AZ code**. Each v3 host only lists its own
region's resources. Re-check with `GET /v3/availability-zones` or `GET /ecc/v1/regions`.

## Auth by product

| Products | Auth |
|---|---|
| CDN, IaaS v1/v2/v3, Object Storage management, Edge, CaaS, VOD, Live, Video Ads, dejban | `Authorization: Apikey <uuid>`. The prefix is case-insensitive (the v3 docs write `apikey`). The v3 and CDN specs also accept `Bearer <jwt>` panel tokens. |
| Object Storage S3 API | AWS-style signatures with a **separate** access key and secret key from the panel, not the machine-user key. |
| Edge `GET /templates` | no auth needed (**live**) |

## Errors you will see (live)

| Status | Body | Meaning |
|---|---|---|
| 401 | `{"message":"Unauthenticated."}` (CDN, VOD), empty (IaaS v1), `{"code":3 or 4,"message":"invalid credentials"}` (IaaS v2), `{"message":"Unauthorized"}` (Edge), `Unauthorized` text (Live) | key missing, wrong or revoked |
| 403 | `{"message":"Account requires info completion"}` | account profile/KYC incomplete. Blocks IaaS; CDN, Storage and Edge still work. Route is valid. |
| 403 | `{"message":"Upgrade plan"}` | feature needs a higher plan (e.g. Object Storage replications and access points) |
| 403 | anything else | check the machine user's IAM access rules for that product |
| 409 | `{"message":"bucket deletion is already in progress"}` | Object Storage bucket is being deleted |
| 404 | `{"message":"Domain not found."}` on Live | create the Live product domain first (`/live/2.0/domain`) |
| 404 | HTML error page or `{"message":"Not Found"}` | wrong path (e.g. v3 `/security-groups`, v1 `/details`) |
| 405 | `{"required_plan":3, ...}` | CDN feature gated by plan (e.g. DNS export needs Professional) |
| 420 | none | IaaS quota reached |
| 428 | `{"message":"no namespace is found"}` | Cloud Container has no namespace in that zone |
| curl 60 | certificate mismatch on `ecc.*.arvanapis.ir` | v3 host built from an AZ code or unknown region |

## Where to go next

- **DNS records, domains, cache purge, CDN settings, Let's Encrypt via acme.sh** -> `references/dns-and-tls.md`.
- **Cloud Server** (v3 vs v1 vs v2, regions, create body, backups, quota, usage) -> `references/iaas.md`.
- **Object Storage** (management API, S3 endpoints, usage reports) -> `references/object-storage.md`.
- **Edge Computing, Live, VOD, Cloud Container, Video Ads** -> `references/products.md`.
- **Corrections to `arvancloud-mcp` and to earlier versions of this skill** -> `references/mcp-cross-check.md`.
- **Wallet balance**: no published spec has a wallet or balance endpoint; it is panel-only. The
  closest API data (quota, CDN plan `needed_balance`, storage usage) is listed in `references/iaas.md`.

## Safety guardrails

Before destructive or billable operations, show the target **account** (from `/v1/me`), the HTTP
method, URL and body (`arvan-api.sh --dry-run`), and ask for confirmation unless the user already
approved that exact action in this turn. This covers DNS create/update/delete, domain add/delete,
cache purge, CDN/WAF/rate-limit changes, server create/delete/actions, volume/network/floating-IP
changes, backups, Object Storage writes/deletes, certificate install hooks, SSH commands and
recurring jobs. `arvan-api.sh` enforces this by refusing non-GET methods without `--allow-write`.

For read-only requests use GET freely, keep output scoped, and never print keys.

## Gotchas that bite everyone

- The v3 host is `ecc.{region}.arvanapis.ir` with a **region** (`ir-central1`). AZ codes as
  hostnames fail TLS, `arvancloudapis.ir` does not resolve, and `*.arvanapis.ir` has wildcard DNS
  so resolving proves nothing.
- v3 lists are per region. An empty `/servers` on one host does not mean the account has no servers.
- v3 `GET /security-groups` is in the spec but 404s; use `/firewalls`. v3 has no SSH key, snapshot,
  backup or quota paths; use v1 or v2.
- IaaS v1 quota is singular `/regions/{az}/quota`; there is no `/ecc/v1/details`, no `GET .../subnets`
  list and no `GET .../ptr`.
- DNS `value` shapes differ by type: `a`/`aaaa` are arrays, `aname` uses `location`, `srv` uses
  `target`, and `mx` is a single object. Send lowercase `type`.
- Cache purge is `POST /domains/{domain}/caching/purge` with `{"purge":"all"}`, not `DELETE .../purge`.
- A domain can be `status: active` yet not published by Arvan's nameservers. Compare `ns_keys` with
  `current_ns` and run `dig SOA <domain> @8.8.8.8` before DNS-01.
- Iran's DNS filtering returns forged IPs `10.10.34.34/.35/.36`, not empty responses. An empty
  SOA/NS means a delegation problem, not censorship.
- Object Storage management is `https://storage.arvanapis.ir/v1/...`; usage is `/v1/reports/storage`
  (there is no `/v1/stats/...`).
- `403 Account requires info completion` is an account state, not a wrong route or a bad key.
- Don't assume the key lives in `$ARVAN_KEY`; resolve `apiKeyEnv` first.
