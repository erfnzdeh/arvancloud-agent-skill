# Cross-check: arvancloud-mcp, the official CLI, and earlier versions of this skill

This skill is a lightweight Agent Skill. Two other projects cover similar ground:

- `dwin-gharibi/arvancloud-mcp`: a full MCP server with typed tools and a generic
  `arvan_request` escape hatch.
- The official ArvanCloud CLI (`git.arvancloud.ir/arvancloud/cli`, Go, v0.4.x): its source
  documents the account identity endpoint, the undocumented IaaS v2 routes and the AZ codes.

Use both as comparison sources, not as truth. When they disagree with the published OpenAPI specs
or a read-only live call, the spec plus the live call win.

## What to adopt

- Normalize machine-user auth to `Authorization: Apikey <uuid>`; accept env values that already
  contain `apikey ...`, `Apikey ...` or only the UUID.
- Identify the account with `GET https://dejban.arvancloud.ir/v1/me` (used by the CLI's login).
- Keep read-only and destructive operations visibly separate. The MCP has an
  `ARVAN_READ_ONLY=true` mode; this skill's `scripts/arvan-api.sh` refuses non-GET methods without
  `--allow-write`.
- Treat Object Storage S3 as separate from the machine-user key (`ARVAN_S3_ACCESS_KEY`,
  `ARVAN_S3_SECRET_KEY`, `ARVAN_S3_REGION`, optional `ARVAN_S3_ENDPOINT`).
- Use timeouts and bounded retries when scripting repeated calls. Never auto-retry a write that
  may have been applied.

## Corrections verified on 2026-09-13

| Claim (source) | Reality | Evidence |
|---|---|---|
| v3 host `ecc.{region}.arvancloudapis.ir` with `ir-thr-c2` (earlier skill) | `ecc.{region}.arvanapis.ir` with `ir-central1`, `ir-northwest1`, `eu-west1` | `arvancloudapis.ir` names do not resolve; spec server is `ecc.[region].arvanapis.ir`; live 200 |
| v3 region can be an AZ code (common guess) | AZ-code hosts fail TLS (curl 60) | live |
| v3 `GET /security-groups` (spec) | 404; `GET /firewalls` works | live |
| Live Streaming `channels` (MCP) | `streams`; `/live/2.0/channels` returns `Cannot GET` | spec + live |
| IaaS quota `/quotas` (MCP) | singular `/ecc/v1/regions/{az}/quota` | spec + live 200 vs 404 |
| `GET /ecc/v1/details` (earlier skill) | 404 | live |
| `GET /ecc/v1/regions/{az}/subnets` and `GET .../ptr/` (earlier skill) | 404, not in spec as GET | spec + live |
| CDN DNSSEC `/domains/{domain}/dnssec` (MCP) | `/domains/{domain}/dns-records/dnssec` and `PUT .../dnssec/actions` | spec + live |
| Cache purge `DELETE /domains/{domain}/caching/purge` (earlier skill) | `POST /domains/{domain}/caching/purge` with `{"purge": ...}`; legacy `DELETE /domains/{domain}/caching` | spec |
| Object Storage usage `/v1/stats/storage` on `http://storage.arvanapis.ir` (earlier skill) | `https://storage.arvanapis.ir/v1/reports/storage` (and `/traffic`) | spec + live 200; `/v1/stats/storage` 404; `http` 301 |
| DNS `mx` and `srv` values are arrays, `aname` and `srv` use `host` (earlier skill) | `mx` and `srv` are objects; `aname` uses `location`; `srv` uses `target`; `cname` also needs `host_header` | spec schemas + live record shapes |
| CDN `GET /plans` is the only plans route | both `GET /plans` and `GET /domains/{domain}/plans` work | live |
| Four AZs (official CLI v0.4) | a fifth AZ exists: `ir-southwest1-a` (Qeysar, Ahwaz); v1/v2 work, v3 host does not | v3 `/availability-zones` + live |

## Account-state responses are not route errors

- `403 {"message":"Account requires info completion"}` on IaaS v1, v2 and v3 means the account's
  profile is incomplete. CDN, Object Storage and Edge Computing still return 200 for the same key.
- `404 {"message":"Domain not found."}` on `/live/2.0/streams` means no Live domain is set up.
- `428 no namespace is found` on CaaS means no Cloud Container namespace exists in that zone.

## Service coverage checklist

- `identity`: `dejban /v1/me`.
- `compute`: IaaS v3 servers, flavors, images; v1 SSH keys, tags, PTR, VNC, quota; v2 backups.
- `network`: v3 networks and firewalls; v1 floating IPs, ports, security rules.
- `storage`: v3/v1 volumes, v1 snapshots, v2 volume list.
- `cdn`: domains, caching and purge, page rules, WAF/firewall, DDoS, rate limits, SSL, load
  balancers, health checks, reports, apps, metric exporters.
- `dns`: records, cloud toggle, import/export, DNSSEC.
- `objectstorage`: management API (buckets, reports, replications, access points) and S3.
- `edge`: edge computes, deploy, routes, env variables, logs, applications.
- `vod`, `live`, `vads`, `caas`: see `references/products.md`.
