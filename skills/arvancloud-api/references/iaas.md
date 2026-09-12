# Cloud Server / IaaS

**Prefer 3.0.0 over 1.0 for basic VM inventory and creation.** 3.0.0 is a cleaner OpenAPI 3 spec with regional subdomains,
flat paths, documented filter/sort/pagination, and structured error responses. Use legacy 1.0
for endpoints 3.0 lacks or where existing tooling still wraps 1.0: dedicated servers,
traffic packages, floating IPs, PTR, tags, SSH keys, server actions, older snapshot flows,
some network/security-group flows, and block volume flows.

> Note: the curl examples on `docs.arvancloud.ir` still use **1.0** (`napi.arvancloud.ir/ecc/v1`).
> Prefer the 3.0 URLs below.

Specs:
- 3.0.0: `https://www.arvancloud.ir/api-docs/iaas-3.0.0.yaml`
- 1.0 (legacy): `https://www.arvancloud.ir/api-docs/iaas-1.0.json`

## IaaS 3.0.0

### Base URL — region goes in the HOSTNAME, not the path

```
https://ecc.{region}.arvancloudapis.ir/v3
```

Known `{region}` values: `ir-thr-c2`, `ir-thr-ba1`, `nl-ams-su1`, … — discover the full
list via `GET /availability-zones` or the panel. When the user doesn't name a region, fall
back to `defaultRegion` from `~/.config/arvan/config.json`
(`jq -r '.defaultRegion' ~/.config/arvan/config.json`).

### Auth

Same machine-user key as CDN: `Authorization: Apikey <uuid>`. 3.0 also accepts
`Authorization: Bearer {token}`. Errors return
`{"message": "...", "data": ..., "errors": [...]}`.

### Quick start

```bash
VAR_NAME="${CONFIRMED_VAR_NAME:-ARVAN_KEY}"
RAW_KEY="${!VAR_NAME}"
TOKEN="${RAW_KEY#apikey }"; TOKEN="${TOKEN#Apikey }"
AUTH_HEADER="Apikey $TOKEN"
REGION=ir-thr-c2
BASE="https://ecc.${REGION}.arvancloudapis.ir/v3"

# Availability zones in this region
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/availability-zones"

# List servers (supports filter/sort/pagination — see spec Introduction tag)
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/servers"

# List flavors (plans)
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/flavors"

# List images
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/images"

# Create a server — POST /servers
curl -s -X POST -H "Authorization: $AUTH_HEADER" -H "Content-Type: application/json" \
  "$BASE/servers" -d '{
    "name": "abrak",
    "availabilityZone": "ir-west1-a",
    "flavorId": "g2-2-2-0",
    "imageId": "<uuid-from-/images>",
    "rootVolumeSizeGigaBytes": 25,
    "networkIds": ["<uuid-from-/networks>"],
    "sshKeyName": "testkey",
    "enableIpv4": true
  }'
```

Required body fields for create: `name`, `availabilityZone`, `flavorId`, `imageId`,
`rootVolumeSizeGigaBytes`.

## 3.0.0 vs 1.0 at a glance

| | 3.0.0 | 1.0 |
|---|---|---|
| Base | `ecc.{region}.arvancloudapis.ir/v3` | `napi.arvancloud.ir/ecc/v1/regions/{region}/…` |
| List servers | `GET /servers` | `GET /regions/:region/servers` |
| Create server | `POST /servers` | `POST /regions/:region/servers` |
| Spec | OpenAPI 3, filtering/pagination documented | Swagger 2, 113 paths, many legacy features |
| Extra in 1.0 only | — | Dedicated servers, traffic packages, floating IPs, PTR, tags, SSH keys, server actions, block volumes, older network/security flows, … |

## IaaS 1.0 legacy surface used by arvancloud-mcp

`arvancloud-mcp` wraps many Cloud Server tools against `https://napi.arvancloud.ir/ecc/v1`.
Keep 1.0 available for operational tasks outside the 3.0 surface, but verify exact paths
against `https://www.arvancloud.ir/api-docs/iaas-1.0.json`.

```bash
VAR_NAME="${CONFIRMED_VAR_NAME:-ARVAN_KEY}"
RAW_KEY="${!VAR_NAME}"
TOKEN="${RAW_KEY#apikey }"; TOKEN="${TOKEN#Apikey }"
AUTH_HEADER="Apikey $TOKEN"
REGION=ir-thr-c2
BASE="https://napi.arvancloud.ir/ecc/v1"

# Regions and account/project details
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/regions"
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/details"

# Legacy VM inventory and creation helpers
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/regions/$REGION/servers"
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/regions/$REGION/servers/options"
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/regions/$REGION/images"
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/regions/$REGION/sizes"
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/regions/$REGION/ssh-keys"
curl -s -H "Authorization: $AUTH_HEADER" "$BASE/regions/$REGION/quota"
```

Useful 1.0 endpoint families:

| Area | Read endpoints | Mutation/action endpoints |
|---|---|---|
| Servers | `GET /regions/:region/servers`, `/servers/:id`, `/servers/options` | `POST /servers`, `DELETE /servers/:id`, `POST /servers/:id/power-on`, `power-off`, `reboot`, `hard-reboot`, `rename`, `rebuild`, `resize`, `reset-root-password`, `add-public-ip`, `change-public-ip`, `add-security-group`, `remove-security-group` |
| Images/plans | `GET /images`, `/images/:id`, `/images/marketplaces`, `/sizes`, `/sizes/:id` | image import and disk-size actions in the spec |
| Network | `GET /networks`, `/subnets`, `/ports`, `/securities`, `/float-ips` | attach/detach networks, manage security rules, create/delete floating IPs |
| Volumes | `GET /volumes`, `/volumes/:id`, `/volumes/options`, `/volumes/limits` | create/update/delete volumes, attach/detach, snapshot |
| SSH keys/tags/PTR | `GET /ssh-keys`, `/tags`, `/ptr/` | create/delete SSH keys and tags, attach/detach tags, create/delete PTR |

Comparison notes:

- The MCP catalog lists `GET /ecc/v1/regions/{region}/quotas`, but the published
  IaaS 1.0 spec uses singular `GET /regions/:region/quota`.
- Read-only smoke checks with the configured key returned ArvanCloud's account-state
  `403 Account requires info completion` for `/ecc/v1` routes rather than `404`.
  Treat that as an account state/permission blocker, not proof that the route is invalid.
- Before legacy server actions or deletes, show the exact method/path/body and ask for
  confirmation.

## Usage / quota / balance — what actually exists

There is **no wallet or billing API** in any published OpenAPI spec. Wallet balance is
panel-only (npanel → dashboard → **Wallet tab** / کیف پول). The nearest API endpoints
report usage or limits, not balance:

| Product | Endpoint | What it is |
|---|---|---|
| IaaS 1.0 | `GET /regions/:region/quota` | Resource limits (servers, volumes, …) |
| Object Storage | `GET /v1/stats/storage`, `/v1/stats/traffic` | Usage statistics |
| Edge Computing | `GET /reports/requests` | Request report |
| CDN 4.0 | `GET /plans` | CDN plan info per domain |

Quota limits (not balance) are also managed in-panel at Settings → Quota management.
Docs: https://docs.arvancloud.ir/fa/accounts/iam/quota and
https://docs.arvancloud.ir/fa/accounts/dashboard.
