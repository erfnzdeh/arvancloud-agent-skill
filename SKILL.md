---
name: arvancloud-api
description: Operate ArvanCloud (arvancloud.ir) APIs — CDN, DNS records, Cloud Server / IaaS, Object Storage, Edge Computing, Cloud Container (CaaS), VOD/Live/Video Ads — and issue Let's Encrypt wildcard TLS certificates via acme.sh's dns_arvan plugin. Use this whenever the user wants to manage anything on ArvanCloud — listing, creating, updating or deleting DNS records, adding or inspecting domains, spinning up or listing cloud servers, checking quota or usage, working with buckets, or getting and renewing certificates. Trigger even when ArvanCloud isn't named explicitly but the task involves hosts like napi.arvancloud.ir, ecc.{region}.arvancloudapis.ir, storage.arvanapis.ir, docs.arvancloud.ir, an apikey-style Authorization header, the acme.sh dns_arvan DNS plugin, or one of the user's ArvanCloud-hosted domains. Also use for figuring out where ArvanCloud's OpenAPI specs live and which base URL or auth a given product needs.
---

# ArvanCloud API

Practical, tested reference for driving ArvanCloud's APIs from the command line or an agent. ArvanCloud is an Iranian cloud provider; its products each have their own base URL, spec, and (for Object Storage) auth scheme. This skill gets those details right so you don't guess.

> Unofficial, community-maintained skill. Not affiliated with or endorsed by ArvanCloud. Base URLs, spec paths, and endpoint counts reflect what was current when this was written — verify against the live OpenAPI specs, which are the source of truth.

## Setup

This skill keeps three things separate: the **secret** (API key) lives in an environment variable, **per-user state** (default region, per-domain cert-deploy hooks, notes) lives in a config file outside the skill, and anything the API can tell you (like the list of domains) is **fetched live** rather than stored. The skill itself stays general — nothing account-specific belongs in it.

### 1. Credentials → environment variable (never a file in the skill)

Every product except Object Storage authenticates with a **machine-user API key**, sent as a literal `apikey ` prefix + a space + the UUID:

```
Authorization: apikey <your-uuid>
```

**`ARVAN_KEY` is just the default name — don't assume it's actually called that.** Resolve the real env var name in this order, every session:

1. If `~/.config/arvan/config.json` exists, read `apiKeyEnv` from it (see §2) — that's the confirmed name from a previous conversation. Check that the named var is actually set (`printenv "$(jq -r .apiKeyEnv ~/.config/arvan/config.json)"`).
2. If there's no config yet, or the named var is unset/empty, fall back to checking `$ARVAN_KEY` as a guess.
3. If that's also unset, **stop and ask the user** which environment variable holds their ArvanCloud API key (or have them export one now, e.g. in this shell or their profile). Don't invent, hardcode, or silently fall back to a wrong name — a missing key should be a question, not a guess.
4. Once you have a confirmed, working var name, **write it back** to `apiKeyEnv` in `~/.config/arvan/config.json` (creating the file from the template first if needed — see §2) so future conversations resolve it automatically without asking again:

   ```bash
   tmp=$(mktemp) && jq --arg v "$CONFIRMED_VAR_NAME" '.apiKeyEnv = $v' ~/.config/arvan/config.json > "$tmp" && mv "$tmp" ~/.config/arvan/config.json
   ```

```bash
export ARVAN_KEY="apikey XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"   # example only — the real var may be named differently
```

Then use `-H "Authorization: ${!CONFIRMED_VAR_NAME}"` (i.e. the value of whichever var name you resolved) in every request. A wrong, missing, or under-permissioned key returns `{"message": "Unauthenticated."}` — if you see that with a var that's set, don't assume the name is wrong; ask the user to check the key's value/permissions instead.

**Creating a key:** npanel → Settings → IAM → Machine users → Create machine user. The key is shown **once** as `apikey XXXX-…` (stored hashed afterward, unrecoverable). Assign IAM access rules per product the key should touch. To check resources across multiple ArvanCloud accounts you need a separate key per account — each key only sees its own account. Docs: https://docs.arvancloud.ir/fa/developer-tools/api/api-key. Revoke a leaked key at https://npanel.arvancloud.ir/profile/iam/machine-users.

### 2. Per-user state → `~/.config/arvan/config.json`

Account-specific, slow-changing settings live in a JSON file at `~/.config/arvan/config.json` (XDG config dir — persists on the user's machine under Claude Code). The skill ships a placeholder template at `assets/config.example.json`. On first use, if the config doesn't exist yet, create it from the template:

```bash
mkdir -p ~/.config/arvan
[ -f ~/.config/arvan/config.json ] || cp "${CLAUDE_SKILL_DIR}/assets/config.example.json" ~/.config/arvan/config.json
```

Read it whenever a task needs the user's defaults or deploy hooks (requires `jq`, or use Python):

```bash
jq -r '.defaultRegion' ~/.config/arvan/config.json          # e.g. ir-thr-c2
jq -r '.deployHooks["example.ir"]' ~/.config/arvan/config.json # cert-deploy target for a domain
```

Schema (see `assets/config.example.json` for a filled-out placeholder):
- `apiKeyEnv` — name of the env var holding the key. Defaults to `ARVAN_KEY` only as an initial guess; once the agent has confirmed the real name with the user (see §1), it overwrites this field so future conversations don't have to ask again.
- `acmeTokenEnv` — env var acme.sh's `dns_arvan` plugin reads (default `Arvan_Token`).
- `defaultRegion` — IaaS region to use when the user doesn't specify one.
- `deployHooks` — map of `domain → { sshHost, certDirs[], reloadCmd }`, used to wire `acme.sh --install-cert` after cert renewal (see `references/dns-and-tls.md`).
- `notes` — map of `domain → freeform note` for per-domain quirks worth remembering.

The **secret never goes in this file** — only the *name* of the env var that holds it. When you learn a new durable fact (a new deploy target, a domain quirk), update this config with the user's OK; don't edit the skill.

### 3. Everything queryable → fetch live, don't cache

The list of domains, servers, records, flavors, etc. is authoritative from the API and drifts over time, so always query it (`GET /domains`, `GET /servers`, …) rather than relying on a stored copy. A stale cached list is worse than no list — a domain can read `active` in the panel yet be unpublished on public DNS.

## Product map — base URLs and specs

Each product has a live base URL (for real calls) and an OpenAPI spec (for looking up endpoints). Fetch specs **directly** — the ReDoc docs pages at `arvancloud.ir/api/{product}/{version}` are just a viewer and often time out.

| Product | Live base URL | OpenAPI spec |
|---|---|---|
| CDN / DNS / Security 4.0 | `https://napi.arvancloud.ir/cdn/4.0` | `https://www.arvancloud.ir/api-docs/cdn-4.0.yml` |
| Cloud Server / IaaS **3.0.0** *(preferred)* | `https://ecc.{region}.arvancloudapis.ir/v3` | `https://www.arvancloud.ir/api-docs/iaas-3.0.0.yaml` |
| Cloud Server / IaaS 1.0 *(legacy)* | `https://napi.arvancloud.ir/ecc/v1` | `https://www.arvancloud.ir/api-docs/iaas-1.0.json` |
| Edge Computing 1.0 | `https://napi.arvancloud.ir/edge-computing/v1` | `https://www.arvancloud.ir/api-docs/ec-1.0.yaml` |
| Object Storage 1.0.0 | `http://storage.arvanapis.ir` (mgmt) / `s3.ir-thr-at1.arvanstorage.ir` (S3) | `https://www.arvancloud.ir/api-docs/storage-1.0.0.yaml` |
| Cloud Container / CaaS 1.25 | `https://napi.arvancloud.ir/caas/v2/zones/{zone}` | `https://www.arvancloud.ir/api-docs/paas-1.25.json` |
| Video Platform / VOD 2.0 | `https://napi.arvancloud.ir/vod/2.0` | `https://www.arvancloud.ir/api-docs/vod-2.0.json` |
| Live Streaming 2.0 | `https://napi.arvancloud.ir/live/2.0` | `https://www.arvancloud.ir/api-docs/live-2.0.json` |
| Video Ads 2.0 | `https://napi.arvancloud.ir/vads/2.0` | `https://www.arvancloud.ir/api-docs/vads-2.0.json` |
| AIaaS 1.0 | — | *(spec unavailable — returns a waiting page)* |

Spec extension matters: `cdn-4.0.yml`, `iaas-3.0.0.yaml`, `iaas-1.0.json`, etc. Download all available specs at once when you need to look endpoints up offline:

```bash
mkdir -p ~/Downloads/arvancloud-api-specs
for spec in cdn-4.0.yml iaas-1.0.json iaas-3.0.0.yaml ec-1.0.yaml \
            storage-1.0.0.yaml paas-1.25.json vod-2.0.json live-2.0.json vads-2.0.json; do
  curl -sL "https://www.arvancloud.ir/api-docs/$spec" -o "$HOME/Downloads/arvancloud-api-specs/$spec"
done
```

**Human-oriented guides** (curl samples, IAM setup, account/panel) live on the Docusaurus site `docs.arvancloud.ir` — use it alongside the OpenAPI specs. It sits behind Arvan CDN cookies, so a bare `curl -L` loops on 307. Seed cookies first:

```bash
COOKIES=/tmp/arvan-docs-cookies.txt
curl -s -A "Mozilla/5.0" -c "$COOKIES" \
  "https://docs.arvancloud.ir/fa/developer-tools/api/api-usage" -o /dev/null
curl -sL -A "Mozilla/5.0" -b "$COOKIES" --max-redirs 3 \
  "https://docs.arvancloud.ir/fa/developer-tools/api/api-usage"
```

### Endpoint counts per product (for scoping)

| Product | Paths | Areas |
|---|---|---|
| CDN 4.0 | 156 | Acceleration, Firewall/WAF, DDoS, DNS Management, Domain, Caching, Page Rule, Rate Limiting, SSL/TLS, Load Balancing, Reports, … |
| IaaS 3.0.0 | 39 | Availability Zones, Servers, Flavors, Images, Networks, Firewalls, Volumes |
| IaaS 1.0 (legacy) | 113 | FloatingIPs, Images, Networks, Plans, Quota, Servers, Snapshots, Volumes, … |
| Edge Computing | 16 | Deployments, Edge Compute, Namespace, Plans, Routes, Templates |
| Object Storage | 25 | Buckets, Clusters, Stats, Users, Replications, … |
| CaaS (PaaS) | 134 | Kubernetes API (core, apps, batch, networking, rbac, …) |
| VOD | 31 | Videos, Channels, Analytics, Subtitles, Watermarks, … |
| Live | 15 | Streams, Analytics, Watermarks, Reports |
| Video Ads | 16 | Campaigns, Ads, Categories, Channels, Reports |

## Auth by product

| Products | Auth |
|---|---|
| CDN, IaaS, VOD, Live, Video Ads, Edge, CaaS | `Authorization: apikey <uuid>` (IaaS 3.0 also accepts `Authorization: Bearer {token}`) |
| Object Storage — S3 API | AWS SigV-style `Authorization: AWS ${S3KEY}:${signature}` with a **separate** Access key + Secret key (not the machine-user apikey). Host `s3.ir-thr-at1.arvanstorage.ir`. |
| Object Storage — management API | `http://storage.arvanapis.ir` — check the OpenAPI spec for its auth scheme |

## Quick starts (most common tasks)

```bash
# CDN — list all domains on the account
curl -s -H "Authorization: $ARVAN_KEY" "https://napi.arvancloud.ir/cdn/4.0/domains?per_page=100"

# IaaS 3.0 — list servers in a region (region goes in the HOSTNAME)
REGION=ir-thr-c2
curl -s -H "Authorization: $ARVAN_KEY" "https://ecc.${REGION}.arvancloudapis.ir/v3/servers"

# VOD — list channels
curl -s -H "Authorization: $ARVAN_KEY" "https://napi.arvancloud.ir/vod/2.0/channels"
```

## Where to go next

- **DNS records (list/create/update/delete) and TLS/Let's Encrypt wildcard certs via acme.sh** → read `references/dns-and-tls.md`. This is the most operationally detailed area (typed `value` objects, `_acme-challenge`, `dns_arvan`, cert deploy hooks).
- **Cloud Server / IaaS** (create servers, 3.0 vs 1.0 differences, required body fields) → read `references/iaas.md`.
- **Account balance / wallet / quota** → there is **no wallet or billing API** in any published spec; balance is panel-only (npanel → dashboard → Wallet tab / کیف پول). The closest API endpoints (usage stats, quota limits) are listed in `references/iaas.md`.

## Gotchas that bite everyone

- The word `apikey` **and** the trailing space are both required in the auth header. `Authorization: apikey <uuid>`, not just `<uuid>`.
- A domain can show `status: active` in the panel yet **not actually be published** by Arvan's authoritative nameservers. Always confirm real resolution (`dig SOA <domain> @8.8.8.8`) before attempting DNS-01 cert issuance.
- Iran's DNS filtering returns forged IPs `10.10.34.34/.35/.36` — **not** empty responses. An empty SOA/NS/A means a delegation/publishing problem, not censorship.
- Fetch OpenAPI specs from `/api-docs/…`; don't scrape the ReDoc HTML pages (they time out).
- Don't assume the API key lives in `$ARVAN_KEY`. Check `apiKeyEnv` in the config first, ask the user if it's still unresolved, and persist the confirmed name back to the config — see "Credentials" above.
