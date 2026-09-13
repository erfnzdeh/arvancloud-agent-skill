# Cloud Server / IaaS

ArvanCloud exposes three generations of the Cloud Server API. All take the same machine-user
key (`Authorization: Apikey <uuid>`).

| Surface | Base URL | Spec | Use it for |
|---|---|---|---|
| **v3** (preferred) | `https://ecc.{region}.arvanapis.ir/v3` | `iaas-3.0.0.yaml` (39 paths) | server inventory, create, power/resize actions, networks, firewalls, volumes, images, flavors |
| **v1** (legacy, widest) | `https://napi.arvancloud.ir/ecc/v1` | `iaas-1.0.json` (114 paths) | what v3 lacks: SSH keys, snapshots, floating IPs, PTR, tags, quota, marketplace images, VNC, dedicated servers, traffic packages, server groups |
| **v2** (undocumented) | `https://napi.arvancloud.ir/ecc/v2` | none; used by the official ArvanCloud CLI (`git.arvancloud.ir/arvancloud/cli`) | volume listing, the backup service, firewall attach/detach, direct image upload |

**live** = confirmed with read-only calls on 2026-09-13. Mutations were not live-tested
(they are billable or destructive); their paths come from the spec or the official CLI source.

## Regions and availability zones (live)

| v3 host region | AZ code | Zone | City | v3 host works |
|---|---|---|---|---|
| `ir-central1` | `ir-thr-ba1` | Bamdad | Tehran | yes |
| `ir-central1` | `ir-thr-fr1` | Foroogh | Tehran | yes |
| `ir-central1` | `ir-thr-si1` | Simin | Tehran | yes |
| `ir-northwest1` | `ir-tbz-sh1` | Shahriar | Tabriz | yes |
| `eu-west1` | `eu-west1-a` | Goethe | Karlsruhe, Germany | yes |
| `ir-southwest1` | `ir-southwest1-a` | Qeysar | Ahwaz | **no** (TLS error); v1 and v2 paths work |

- **v3 puts the region in the hostname**: `ecc.ir-central1.arvanapis.ir`. Each host only
  returns resources in its own region (**live**: a server in `eu-west1-a` shows up on
  `ecc.eu-west1` and nowhere else), so inventory means looping over every region.
- **v1 and v2 put the AZ code in the path**: `/ecc/v1/regions/ir-thr-fr1/servers`.
- v3 `availabilityZone` fields and create bodies use the AZ code.
- Discover live instead of trusting this table: `GET /v3/availability-zones` on any regional
  host returns every AZ with `region`, `code` and `state` (`UP|PROHIBITED|READ_ONLY|DOWN`);
  `GET /ecc/v1/regions` (not in the spec, but **live**) returns `code`, `dc`, `city`, `create`, `default`.
- Hostnames that do **not** work: `ecc.{az-code}.arvanapis.ir` (curl error 60, certificate does not
  match) and anything under `arvancloudapis.ir` (does not resolve). `*.arvanapis.ir` has wildcard
  DNS, so a name resolving proves nothing; only a real request does.

## v3

```bash
S="${CLAUDE_SKILL_DIR}/scripts/arvan-api.sh"

"$S" v3:ir-central1/availability-zones | jq -c '.data[] | {region, code, name, state}'
for r in ir-central1 ir-northwest1 eu-west1; do
  "$S" "v3:$r/servers" | jq -c '.data[]? | {id, name, state, az: .availabilityZone, flavor: .flavor.id, ips: [.ipAddresses[]? | select(.isPublic) | .ipAddress]}'
done
"$S" "v3:ir-central1/flavors?perPage=50" | jq -c '.data[] | {id, name, cpuCores, memoryMegaBytes, diskGigaBytes, pricePerMonth}'
```

Plain curl: `curl -s -H "Authorization: Apikey $TOKEN" https://ecc.ir-central1.arvanapis.ir/v3/servers`.

### Listing conventions

- Pagination: `page`, `perPage`. `flavors`, `images` and `networks` return
  `meta.pagination {current, lastPage, next, perPage, previous, totalItems}` with a default page
  size of 10 (**live**). `servers` and `firewalls` returned no `meta` (with one server, `page=2&perPage=1` still returned it, so
  request `perPage=100` and treat a full page as possibly truncated); `volumes` returned `{}` when empty.
- Filtering: `?{field}={op}:{value}` with `eq, neq, gt, gte, lt, lte, in, nin`
  (`in`/`nin` take a comma-separated list). **live**: `name=eq:no-such-name` returned 0 servers and
  `id=in:<uuid>` returned the match.
- Sorting: `sortBy=asc:name,desc:createDate`.
- Server objects (**live**): `id, name, state, availabilityZone, flavor{id,cpuCores,ramMegaBytes,rootDiskGigaBytes},
  image{id,name,os,version}, ipAddresses[{ipAddress,version,isPublic,networkName,macAddress}], sshKeyName,
  backupEnabled, failoverEnabled, createDate, taskState, taskId`. The field is `state`, not `status`.

### Endpoints

| Area | Read | Write (confirm first) |
|---|---|---|
| Zones | `GET /availability-zones` (**live**) | none |
| Servers | `GET /servers` (**live**), `GET /servers/{id}` (**live**), `GET /servers/inquiry/{id}` | `POST /servers`, `POST /servers/batch-delete`, `POST /servers/{id}/` + `power-on`, `power-off`, `reboot`, `rename`, `rescue`, `unrescue`, `reset-root-password`, `resize`, `resize-root-disk`, `terminate`, `discard` |
| Flavors | `GET /flavors` (**live**), `GET /flavors/{id}` | `POST /flavors/{id}/calculate` |
| Images | `GET /images` (**live**), `GET /images/{id}` | `POST /images`, `POST /images/batch-delete` |
| Networks | `GET /networks` (**live**), `GET /networks/{id}` | `POST /networks`, `DELETE /networks/{id}`, `POST /networks/{id}/attach`, `/detach` |
| Firewalls | `GET /firewalls` (**live**), `GET /firewalls/{firewallId}` | `POST /firewalls`, `POST /firewalls/batch-delete`, `POST /firewalls/{firewallId}/rules`, `POST /firewalls/{firewallId}/rules/batch-delete` |
| Security groups | `GET /security-groups` is in the spec but returns **404 live**; use `/firewalls` | `POST /security-groups/{id}/attach`, `/detach` |
| Volumes | `GET /volumes` (**live**), `GET /volumes/{volumeId}` | `POST /volumes`, `POST /volumes/batch-delete`, `POST /volumes/{volumeId}/attach`, `/detach` |

v3 has tags for Quota, SSH keys, Backups and Snapshots but **no paths** for them. Use v1 (SSH keys,
snapshots, quota) or v2 (backups).

### Create a server (billable)

Required: `name`, `availabilityZone` (AZ code), `flavorId`, `imageId`, `rootVolumeSizeGigaBytes`.
Optional: `networkIds[]`, `sshKeyName`, `firewallNames[]`, `enableIpv4`, `enableIpv6`,
`initScript`, `secondaryVolumes`, `enableBackup` + `backupName`, `backupId` (create from a backup;
`imageId` is then ignored), `enableFailOver`.

```bash
S="${CLAUDE_SKILL_DIR}/scripts/arvan-api.sh"
BODY='{"name":"web-1","availabilityZone":"ir-thr-fr1","flavorId":"<id from GET /flavors>","imageId":"<uuid from GET /images>","rootVolumeSizeGigaBytes":25,"sshKeyName":"<name from v1 ssh-keys>","enableIpv4":true}'
"$S" --dry-run -d "$BODY" v3:ir-central1/servers        # show the user, get an explicit yes
"$S" --allow-write -d "$BODY" v3:ir-central1/servers
```

The flavor and image must exist in the region you post to; list them on the same regional host.

## v1

```bash
S="${CLAUDE_SKILL_DIR}/scripts/arvan-api.sh"
AZ=ir-thr-fr1
"$S" /ecc/v1/regions | jq -c '.data[] | {code, dc, city, create}'
"$S" "/ecc/v1/regions/$AZ/quota"
"$S" "/ecc/v1/regions/$AZ/ssh-keys"
"$S" "/ecc/v1/regions/$AZ/servers/options" | jq '.data | {droplet_count, droplet_limit}'
```

### Reads verified live

`GET /ecc/v1/regions`, and under `/ecc/v1/regions/{az}`: `servers`, `servers/{id}`,
`servers/options`, `sizes`, `images?type=private|arvan|distributions`, `images/marketplaces`,
`networks`, `ports`, `float-ips`, `securities`, `ssh-keys`, `snapshots`, `volumes`,
`volumes/limits`, `tags`, `quota`.

### Routes that do not exist

| Tried | Result | Use instead |
|---|---|---|
| `GET /ecc/v1/details` | 404 | `GET https://dejban.arvancloud.ir/v1/me` for account identity |
| `GET /regions/{az}/quotas` | 404 | `GET /regions/{az}/quota` (singular) |
| `GET /regions/{az}/subnets` | 404 | subnets are listed inside `GET /regions/{az}/networks`; `GET /subnets/{id}` exists |
| `GET /regions/{az}/ptr` | 404 | PTR values appear on IPs; only `POST /regions/{az}/ptr/` and `DELETE /regions/{az}/ptr/{ip}` exist |

### Write endpoints (from the spec)

| Area | Paths under `/ecc/v1/regions/{az}` |
|---|---|
| Servers | `POST /servers`, `DELETE /servers/:id`, `POST /servers/:id/` + `power-on`, `power-off`, `reboot`, `hard-reboot`, `rebuild`, `resize`, `rename`, `rescue`, `unrescue`, `reset-root-password`, `add-public-ip`, `add-security-group`, `remove-security-group`, `attach-vpc`, `snapshot`, `terminate`; `PUT /servers/:id/resizeRoot`; reads `GET /servers/:id/vnc`, `/servers/:id/actions`, `/servers/inquiry/:task_id` |
| Networks | `POST`/`PATCH /subnets`, `GET`/`DELETE /subnets/:id`, `PATCH /networks/:id/attach`, `/detach`, `PATCH /ports/:id/enable`, `/disable`, `/enablePortSecurity`, `/disablePortSecurity`, `DELETE /ports/:id` |
| Floating IPs | `POST /float-ips`, `DELETE /float-ips/:id`, `PATCH /float-ips/:id/attach`, `PATCH /float-ips/detach` (spec; the official CLI calls `/float-ips/{id}/detach`), `GET /float-ips/ips` |
| PTR | `POST /ptr/`, `DELETE /ptr/:ip` |
| Security groups | `POST /securities`, `DELETE /securities/:id`, `GET`/`POST`/`DELETE /securities/security-rules/:id`, `POST /securities/security-rules/cdn` |
| Volumes and snapshots | `POST /volumes`, `PATCH`/`DELETE /volumes/:id`, `PATCH /volumes/attach`, `/detach`, `PUT`/`DELETE /volumes/:id/snapshot`, `POST /snapshots/servers/:id/`, `POST /snapshots/volumes/:id/`, `POST /snapshots/:id/volumes/`, `PUT /snapshots/:id/revert`, `DELETE /snapshots/:id` |
| SSH keys, tags, images | `POST /ssh-keys`, `POST /ssh-keys/:name`, tags CRUD + `attach`/`detach`/`batch`, `POST /images`, `POST /images/import`, `PATCH`/`DELETE /images/:id` |
| Other | dedicated servers, traffic packages, server groups, databases, IP advertising, `GET /reports/:id/:metric` (server metrics) |

The spec has no `DELETE /ssh-keys/:name`; the official CLI deletes keys with
`DELETE /regions/{az}/ssh-keys/{name}`.

## v2 (undocumented, from the official CLI)

| Method | Path | Notes |
|---|---|---|
| GET | `/ecc/v2/volume/{az}/list` | `{"data": [...]}` (**live**) |
| GET | `/ecc/v2/backup/counts` | `{"data": [{"datacenter", "count"}]}` (**live**) |
| GET | `/ecc/v2/backup/{az}/list` | `{"meta": {"total"}, "data": [...] or null}` with `backup_name`, `instance_id`, `occupancy`, `quota`, `next_backup` (**live**) |
| GET | `/ecc/v2/backup/s3/providers` | `{"providers": [...]}`, no `data` wrapper (**live**) |
| GET | `/ecc/v2/backup/s3/providers/{id}`, `/ecc/v2/backup/{az}/details/{volumeId}`, `/ecc/v2/backup/s3/{az}/inquiry/{slotId}` | backup slots and S3 export status |
| POST | `/ecc/v2/backup/{az}/create`, `/enable`, `/disable`, `/delete`; `PUT /ecc/v2/backup/{az}/{volumeId}/name`; `POST /ecc/v2/backup/s3/{az}/upload` | backup mutations |
| POST | `/ecc/v2/firewall/{az}/{groupId}/attach`, `/detach` | body `{"port_id": "..."}` |
| POST, PATCH | `/ecc/v2/image/{az}/direct` | TUS resumable image upload (follow the `Location` header) |

There is no restore endpoint: restore by creating a server with `backupId`. For request bodies of
the v2 mutations, read `modules/iaas/internal/service/backup` in the CLI source before calling them.

## Errors

- `403 {"message":"Account requires info completion"}`: the account's profile/KYC is incomplete.
  It blocks v1, v2 and v3 while CDN, Object Storage and Edge Computing still answer `200`. Not a routing problem.
- `420`: quota limit reached (official CLI handles it explicitly).
- `401`: v1 returns an empty body, v2 returns `{"code": 3|4, "message": "invalid credentials"}`.
- Empty results are normal for regions without resources; always check every region.

## Usage, quota, balance

No published spec has a wallet, balance or invoice endpoint (checked all path lists). Wallet
balance is panel-only (dashboard, Wallet tab / کیف پول). The nearest API data:

| Product | Endpoint | What it is |
|---|---|---|
| IaaS v1 | `GET /ecc/v1/regions/{az}/quota` | resource limits (**live**) |
| IaaS v1 | `GET /ecc/v1/regions/{az}/volumes/limits`, `/servers/options` | volume and server limits (**live**) |
| CDN | `GET /cdn/4.0/plans`, `GET /cdn/4.0/domains/{domain}/plans` | plan prices and `needed_balance` (**live**) |
| Object Storage | `GET https://storage.arvanapis.ir/v1/reports/storage`, `/traffic`, `/operations`, `/usage-rate` | usage (storage and traffic **live**) |
| Edge Computing | `GET /edge-computing/v1/reports/requests` | request report |

Quota limits are managed in the panel under Settings, Quota management. Docs:
https://docs.arvancloud.ir/fa/accounts/iam/quota and https://docs.arvancloud.ir/fa/accounts/dashboard.
