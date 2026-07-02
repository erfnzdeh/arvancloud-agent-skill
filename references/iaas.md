# Cloud Server / IaaS

**Prefer 3.0.0 over 1.0.** 3.0.0 is a cleaner OpenAPI 3 spec with regional subdomains,
flat paths, documented filter/sort/pagination, and structured error responses. Use 1.0
only for endpoints 3.0 lacks (dedicated servers, traffic packages, floating IPs, PTR,
tags, older snapshot flows).

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

Same machine-user key as CDN: `Authorization: apikey <uuid>`. 3.0 also accepts
`Authorization: Bearer {token}`. Errors return
`{"message": "...", "data": ..., "errors": [...]}`.

### Quick start

```bash
REGION=ir-thr-c2
BASE="https://ecc.${REGION}.arvancloudapis.ir/v3"

# Availability zones in this region
curl -s -H "Authorization: $ARVAN_KEY" "$BASE/availability-zones"

# List servers (supports filter/sort/pagination — see spec Introduction tag)
curl -s -H "Authorization: $ARVAN_KEY" "$BASE/servers"

# List flavors (plans)
curl -s -H "Authorization: $ARVAN_KEY" "$BASE/flavors"

# List images
curl -s -H "Authorization: $ARVAN_KEY" "$BASE/images"

# Create a server — POST /servers
curl -s -X POST -H "Authorization: $ARVAN_KEY" -H "Content-Type: application/json" \
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
| Extra in 1.0 only | — | Dedicated servers, traffic packages, floating IPs, PTR, tags, … |

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
