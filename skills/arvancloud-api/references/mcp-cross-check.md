# arvancloud-mcp cross-check

This repo is a lightweight Agent Skill; `dwin-gharibi/arvancloud-mcp` is a
full MCP server with typed tools plus a generic `arvan_request` escape hatch.
Use the MCP repo as a useful comparison source, but do not copy its endpoint
catalog blindly. Always prefer the live OpenAPI specs and a read-only API
smoke check when they disagree.

## What to adopt from the MCP

- Normalize machine-user auth to `Authorization: Apikey <uuid>`. Accept a user
  env var that already contains `apikey ...`, `Apikey ...`, or only the UUID,
  then send canonical `Apikey ...` on requests.
- Use a single unified API base for most products: `https://napi.arvancloud.ir`.
  IaaS 3.0 is the exception because its preferred base is regional:
  `https://ecc.{region}.arvancloudapis.ir/v3`.
- Keep read-only and destructive operations visibly separate. The MCP exposes
  read/destructive hints and an `ARVAN_READ_ONLY=true` mode; this skill should
  similarly ask before DNS mutations, server changes, cache purges, deletes,
  certificate installs, SSH commands, and Terraform/Kubernetes actions.
- Treat Object Storage as S3-compatible and separate from the machine-user API
  key. Use `ARVAN_S3_ACCESS_KEY`, `ARVAN_S3_SECRET_KEY`, `ARVAN_S3_REGION`, and
  optionally `ARVAN_S3_ENDPOINT`.
- Use timeout/retry settings when scripting repeated API calls:
  `ARVAN_TIMEOUT`, `ARVAN_MAX_RETRIES`, and `ARVAN_BACKOFF_FACTOR`.

## Verified during comparison

Read-only smoke checks with the configured API key showed:

- `GET /cdn/4.0/domains?per_page=1` returned `200`.
- Both the existing raw lowercase prefix and canonical `Apikey` auth worked on
  CDN, but canonical `Apikey` should be documented.
- `GET /vod/2.0/channels` returned `200`.
- `GET /cdn/4.0/apps` returned `200`.
- `GET /cdn/4.0/metric-exporters` returned `200`.
- `GET /live/2.0/streams` matched the published path family but returned
  `404 Domain not found.` for this account state; the MCP's `/channels` route
  returned a plain `404`.
- Legacy IaaS `/ecc/v1` routes returned ArvanCloud's account-state `403`
  response (`Account requires info completion`) rather than `404`, which is
  enough to confirm the route family exists for this account/key but is blocked
  by account state.

## Corrected MCP claims

The MCP catalog has a few route claims that did not match the live specs or
runtime checks:

- Live Streaming 2.0 uses `streams`, not `channels`. The published spec lists
  `/streams`, `/streams/{stream}`, `/streams/{stream}/start-record`, and
  `/streams/{stream}/stop-record`. `GET /live/2.0/channels` returned `404`.
- IaaS 1.0 quota is singular: `GET /ecc/v1/regions/{region}/quota`. The MCP's
  `/quotas` route is not in the published `iaas-1.0.json` spec.
- CDN DNSSEC lives under DNS records:
  `GET /cdn/4.0/domains/{domain}/dns-records/dnssec` and
  `PUT /cdn/4.0/domains/{domain}/dns-records/dnssec/actions`. The MCP's
  `/domains/{domain}/dnssec` route is not in the `cdn-4.0.yml` spec.
- CDN cache purge is `DELETE /domains/{domain}/caching/purge`; `GET`/`PATCH`
  settings still use `/domains/{domain}/caching`.

## Service coverage worth documenting

The MCP's product grouping is a good checklist for future references:

- `compute` - legacy IaaS `/ecc/v1` servers, images, plans, SSH keys, tags,
  PTR, power actions, rebuild/resize.
- `network` - `/ecc/v1` private networks, subnets, security groups, floating
  IPs, ports.
- `storage` - `/ecc/v1` block volumes and snapshots.
- `cdn` - domains, caching, page rules, WAF/firewall, rate limits, logs, metric
  exporters, SSL, CDN apps.
- `dns` - DNS records, cloud toggle, zone import/export, DNSSEC.
- `vod` - VOD channels, videos, audio, subtitles, watermarks, profiles.
- `live` - live streams, analytics, reports, watermarks, custom domain.
- `objectstorage` - S3-compatible bucket/object operations.

