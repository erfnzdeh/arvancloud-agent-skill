# Object Storage

Object Storage has two APIs with **different credentials**:

| API | Base URL | Auth | Use it for |
|---|---|---|---|
| Management | `https://storage.arvanapis.ir/v1` | machine-user key, `Authorization: Apikey <uuid>` | buckets, usage reports, replication, access points, temp users, antivirus |
| S3-compatible | per region, see below | AWS-style signature with a separate **access key + secret key** from the panel | objects: upload, download, list, delete, presign |

Spec: `https://www.arvancloud.ir/api-docs/storage-1.0.0.yaml` (34 paths, 58 operations).
Plain `http://storage.arvanapis.ir` answers `301`; use `https`. **live** = confirmed with read-only
calls on 2026-09-13.

## S3 endpoints (from the spec)

| Code | Region | Zone | Type | Endpoint |
|---|---|---|---|---|
| `ir-thr-at1` | ir-central1 | Simin | STANDARD | `https://s3.ir-thr-at1.arvanstorage.ir` |
| `ir-pym-hd1` | ir-central1 | Bamdad | HI_OPS | `https://hot.ir-central1.arvanstorage.ir` |
| `ir-tbz-sh1` | ir-north-west | Shahriar | STANDARD | `https://s3.ir-tbz-sh1.arvanstorage.ir` |

The spec's table writes `ir-north-west`; the bucket `region` field uses `ir-northwest1`. All three answer HTTPS with `server: ArvanCloud` (**live**). Other `*.arvanstorage.ir` names may
also answer, so stick to the endpoints above. Any S3 client should work. For example, with the AWS
CLI, credentials come from the env var names in `~/.config/arvan/config.json` (not live-tested
here: no S3 keys were available):

```bash
AK_VAR=$(jq -r .s3AccessKeyEnv ~/.config/arvan/config.json)
SK_VAR=$(jq -r .s3SecretKeyEnv ~/.config/arvan/config.json)
AWS_ACCESS_KEY_ID="${!AK_VAR}" AWS_SECRET_ACCESS_KEY="${!SK_VAR}" \
  aws s3 ls --endpoint-url https://s3.ir-thr-at1.arvanstorage.ir
```

Object writes and deletes need the same confirmation as any other destructive call.

## Management API

```bash
S="${CLAUDE_SKILL_DIR}/scripts/arvan-api.sh"
"$S" storage:/v1/buckets | jq -c '.data[] | {name, region, regionType, multiZoneStatus, isShared, isDeleting}'
"$S" storage:/v1/reports/storage | jq .data
"$S" "storage:/v1/reports/traffic?region=ir-central1" | jq .data
```

Responses use `{"message": "...", "data": ...}`.

### Buckets

| Method | Path | Notes |
|---|---|---|
| GET | `/v1/buckets` | `status` (`all|shared|owned`), `page`, `perPage` (spec default 20; with one bucket the live API returned it even for `page=2&perPage=1`, so don't rely on paging behaviour). Items: `name, region, regionType, ownerName, multiZoneStatus, isShared, isDeleting, createDate` (**live**) |
| POST | `/v1/buckets` | body `{"name", "region"}` required. `name`: 3 to 63 chars, `^[a-z0-9][a-z0-9.-]*[a-z0-9]$`. `region`: `ir-central1` or `ir-northwest1`. Optional `tags[{key,value}]`, `isPublic`, `versioningEnabled`, `multiZoneEnabled`, `lockEnabled` (object lock, default false), `lockRetention` (days, default 30) |
| GET, DELETE | `/v1/buckets/{bucketName}` | details, delete |
| GET, POST | `/v1/buckets/{bucketName}/versioning` | read, change versioning |
| GET, PUT | `/v1/buckets/{bucketName}/lock` | object lock |
| GET | `/v1/buckets/{bucketName}/metrics` | bucket metrics |
| POST | `/v1/buckets/{bucketName}/enable-multi-zone` | enable multi-zone |

A bucket that is being deleted answers `409 {"message":"bucket deletion is already in progress"}` on
its sub-resources (**live**).

### Usage reports

`GET /v1/reports/storage`, `/v1/reports/traffic`, `/v1/reports/operations`, `/v1/reports/usage-rate`,
each with optional `reportDate`, `bucket`, `region` (all four **live**).

- `storage`: `{storageBytes, objectsCount, bucketsCount, maxBucketsCount}`.
- `traffic`: `{fromDate, toDate, uploadBytes, bypassTrafficBytes, cachedTrafficBytes}` for the last month.
- There is no `/v1/stats/...` route (**live** 404).

### Other resources

| Area | Endpoints | Live note |
|---|---|---|
| Replications | `GET`/`POST /v1/replications`, `GET`/`PUT`/`DELETE /v1/replications/{id}`, `POST .../sync`, `POST .../detect-sync-status` | `403 {"message":"Upgrade plan"}` on the base plan |
| Access points | `GET`/`POST /v1/access-points`, `GET`/`DELETE /v1/access-points/{id}` | `403 {"message":"Upgrade plan"}` on the base plan |
| Temp users | `GET`/`POST /v1/temp-users`, `GET`/`PUT`/`DELETE /v1/temp-users/{id}` | GET 200 |
| Credentials | `POST /v1/users/refresh-credentials` | rotates S3 keys (destructive for existing clients) |
| Upload links | `POST /v1/upload/link` | |
| Bucket downloads | `GET`/`POST /v1/bucket-downloads`, `GET`/`PUT`/`DELETE /v1/bucket-downloads/{id}` | |
| Bucket catalogs | `GET`/`POST /v1/bucket-catalogs`, `GET /v1/bucket-catalogs/resources`, `GET`/`PATCH`/`DELETE /v1/bucket-catalogs/{id}` | |
| Antivirus | `GET`/`POST /v1/av`, `GET`/`PUT /v1/av/{id}`, `POST /v1/av/{id}/scan`, `GET .../scans-statistics`, `GET .../scans-summary` | |
| Engine clusters | `GET`/`POST /v1/engine-clusters`, `GET`/`POST`/`PATCH`/`DELETE /v1/engine-clusters/{id}`, `POST .../api-key`, `DELETE .../config/{configId}` | |

The spec's error codes include `USER_IS_DEBTOR` (insufficient balance) and a family of
`VALIDATION_*` codes.
