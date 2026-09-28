# Edge Computing, Live, VOD, Video Ads, Cloud Container

All five use the machine-user key (`Authorization: Apikey <uuid>`) on `https://napi.arvancloud.ir`.
**live** = confirmed with read-only calls on 2026-09-13; other rows come from the published specs.
Mutations were not live-tested.

```bash
S="${CLAUDE_SKILL_DIR}/scripts/arvan-api.sh"
```

## Edge Computing 1.0

Base: `https://napi.arvancloud.ir/edge-computing/v1`. Spec: `ec-1.0.yaml` (version 1.8.1).

| Method | Path | Notes |
|---|---|---|
| GET | `/edge-computes` | `{"data": [...], "meta": {"total", "per_page", "page", "total_page"}}` (**live**); `page`, `per_page` |
| GET | `/edge-computes/{edgeComputeId}` | one app |
| POST, PUT, DELETE | `/edge-computes`, `/edge-computes/{edgeComputeId}` | create, update, delete |
| POST | `/edge-computes/deploy` | body `{"name", "bundled_code"}` required, optional `namespace`, `tag` |
| GET | `/edge-computes/{edgeComputeId}/deployments` | deployment history |
| GET, POST | `/edge-computes/{edgeComputeId}/env-variables`; `POST .../env-variables/delete` | environment variables |
| GET, POST, PUT, DELETE | `/edge-computes/{edgeComputeId}/routes[/{route_id}]` | routes |
| GET | `/edge-computes/{edgeComputeId}/reports/console-logs` | `period` one of `5m, 15m, 30m, 1h, 6h, 12h, 24h` (default `1h`), `log_levels[]` of `DEBUG, INFO, WARN, ERROR`, plus a search filter |
| GET | `/edge-computes/{edgeComputeId}/reports/requests`, `/reports/requests` | request reports |
| GET | `/plans` (**live**), `/namespace` (**live**) | plan features; namespace, `arvanedge.ir` domain and the account owner's name (personal data, don't echo it needlessly) |
| GET, POST | `/applications` (**live**) | ready-made apps such as a waiting room |
| PATCH | `/applications/{edgeComputeId}` | configure an application |
| GET | `/applications/{edgeComputeId}/metrics` | application metrics |
| GET | `/templates` (**live, no auth**), `/templates/{key}` | starter templates with git URLs |

Deploy a bundled script (confirm first):

```bash
BODY="$(mktemp)"
jq -n --rawfile code dist/worker.js '{name: "my-app", tag: "1.0.0", bundled_code: $code}' > "$BODY"
"$S" --dry-run -d @"$BODY" /edge-computing/v1/edge-computes/deploy      # prints the full body, including the code
"$S" --allow-write -d @"$BODY" /edge-computing/v1/edge-computes/deploy
rm -f "$BODY"
"$S" "/edge-computing/v1/edge-computes/<id>/reports/console-logs?period=1h"
```

## Live Streaming 2.0

Base: `https://napi.arvancloud.ir/live/2.0`. Spec: `live-2.0.json`.

Nothing works until the Live product domain exists: `GET /streams` and `GET /domain` both return
`404 {"message":"Domain not found."}` on accounts without one (**live**). There is no `/channels`
route (`Cannot GET /2.0/channels`, **live**).

| Area | Endpoints |
|---|---|
| Product domain | `GET /domain`, `POST /domain` |
| Streams | `GET /streams`, `POST /streams`, `GET`/`PATCH`/`DELETE /streams/{stream}` |
| Stream control | `POST /streams/{stream}/start-record`, `/stop-record`, `/start-pull`, `/stop-pull` |
| Stream metrics | `GET /streams/{stream_id}/metrics/` + `bitrate`, `concurrent-viewers`, `fps`, `rebuffer-ratio`, `startup-time`, `stats`, `ttff`, `watch-time` |
| Analytics and reports | `GET /analytics/play-count`, `/analytics/traffic`, `/analytics/watch-time`; `GET /report/geo`, `/report/statistics`, `/report/traffics`, `/report/user-agent`, `/report/visitors`; `POST /report/play-time`, `/report/watch-time` |
| Watermarks | `GET`/`POST /watermarks`, `GET`/`PATCH`/`DELETE /watermarks/{watermark}` |

## VOD (Video Platform) 2.0

Base: `https://napi.arvancloud.ir/vod/2.0`. Spec: `vod-2.0.json` (Swagger 2).

`GET /channels` returns 200 with Laravel-style `links`/`meta` pagination (**live**). `GET /domain`
returns `404 {"message":"userdomain not found."}` until the VOD domain is set (**live**).

| Area | Endpoints |
|---|---|
| Product domain | `GET /domain`, `POST /domain` |
| Channels | `GET`/`POST /channels`, `GET`/`PATCH`/`DELETE /channels/{channel}` |
| Per channel | `GET`/`POST /channels/{channel}/videos`, `/audios`, `/files`, `/profiles`, `/watermarks`; `PATCH /channels/{channel}/files/{file}` |
| Videos | `GET`/`PATCH`/`DELETE /videos/{video}`; `GET`/`POST /videos/{video}/audio-tracks`, `/subtitles`, `/thumbnail`; `GET`/`PUT /videos/{video}/tags` |
| Items | `GET`/`PATCH`/`DELETE /audios/{audio}`, `/profiles/{profile}`, `/watermarks/{watermark}`; `GET`/`DELETE /subtitles/{subtitle}`, `/audio-tracks/{audio_track}`; `GET /files/{file}`, `DELETE /files/{file}` |
| Tags | `GET`/`POST /tags` |
| Analytics and reports | `GET /analytics/play-count`, `/analytics/traffic`, `/analytics/watch-time`; `GET /report/geo`, `/report/statistics`, `/report/traffics`, `/report/user-agent`, `/report/visitors` |

## Video Ads 2.0

Base: `https://napi.arvancloud.ir/vads/2.0`. Spec: `vads-2.0.json` (Swagger 2).

`GET /channels` returns 200 (**live**). `GET /domain` returns `404 {"message":"User domain not found."}`
until set (**live**). There is no top-level campaign list: `GET /campaigns` is 404 (**live**); list
campaigns per channel.

| Area | Endpoints |
|---|---|
| Product domain | `GET /domain`, `POST /domain` |
| Channels | `GET`/`POST /channels`, `GET`/`PUT`/`DELETE /channels/{channel}`, `GET`/`POST /channels/{channel}/ads`, `GET`/`POST /channels/{channel}/campaigns` |
| Campaigns | `GET`/`PUT`/`DELETE /campaigns/{campaign}`, `GET`/`POST /campaigns/{campaign}/ads`, `GET`/`PUT`/`DELETE /campaigns/{campaign}/ads/{ad}` |
| Ads | `GET`/`PUT`/`DELETE /ads/{ad}` |
| Reports | `GET /ads/{ad}/reports/track/{event}/{period}`, `GET /campaigns/{campaign}/reports/track/{event}/{period}`, `GET /campaigns/{campaign}/ads/{ad}/reports/track/{event}/{period}`, `GET /agencies/{agency}/income` |
| Transactions | `GET`/`POST /transactions`, `GET /transactions/{transaction}` |

## Cloud Container (CaaS) 1.25

Base: `https://napi.arvancloud.ir/caas/v2/zones/{zone}` with zone `ir-thr-ba1` or `ir-tbz-sh1`
(the spec's two servers). Spec: `paas-1.25.json` (134 paths, 299 operations).

The API is the Kubernetes REST API behind Arvan auth: paths such as
`/api/v1/namespaces/{namespace}/pods`, `/configmaps`, `/services`, `/persistentvolumeclaims`, with
Kubernetes JSON objects. API groups in the spec: `/api/v1`, `/apis/apps/v1`, `/apis/batch/v1`,
`/apis/rbac.authorization.k8s.io/v1`, `/apis/networking.k8s.io/v1`, `/apis/autoscaling/v1|v2|v2beta2`,
`/apis/events.k8s.io/v1`, `/apis/coordination.k8s.io/v1`, `/apis/discovery.k8s.io/v1`. Accounts without a Cloud Container namespace get
`428 {"message":"no namespace is found", "kind":"Status", ...}` on `GET /api/v1/namespaces` (**live**).

```bash
"$S" /caas/v2/zones/ir-thr-ba1/api/v1/namespaces
"$S" "/caas/v2/zones/ir-thr-ba1/api/v1/namespaces/<ns>/pods" | jq -r '.items[] | "\(.metadata.name) \(.status.phase)"'
```
