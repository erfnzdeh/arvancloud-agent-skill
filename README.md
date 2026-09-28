# ArvanCloud's API Agent Skill

[![skills.sh](https://skills.sh/b/erfnzdeh/arvancloud-agent-skill)](https://skills.sh/erfnzdeh/arvancloud-agent-skill)
[![npm](https://img.shields.io/npm/v/arvancloud-api-skill)](https://www.npmjs.com/package/arvancloud-api-skill)
[![license](https://img.shields.io/github/license/erfnzdeh/arvancloud-agent-skill)](LICENSE)
[![stars](https://img.shields.io/github/stars/erfnzdeh/arvancloud-agent-skill)](https://github.com/erfnzdeh/arvancloud-agent-skill/stargazers)
![type](https://img.shields.io/badge/type-Agent_Skill-blueviolet)
![works with](https://img.shields.io/badge/works_with-Claude_Code-D97757?logo=claude&logoColor=white)
![works with](https://img.shields.io/badge/works_with-Cursor-000000)
![status](https://img.shields.io/badge/status-unofficial-orange)

Unofficial, community-maintained [Agent Skill](https://agentskills.io) for driving [ArvanCloud](https://arvancloud.ir)'s APIs (CDN, DNS, Cloud Server / IaaS, Object Storage, Edge Computing, Cloud Container, VOD/Live/Video Ads) and issuing Let's Encrypt wildcard TLS certs via acme.sh's `dns_arvan` plugin, from Claude Code, Cursor, or any agent that supports the `SKILL.md` format.

Not affiliated with or endorsed by ArvanCloud.

## Install

Primary (Claude Code, Cursor, Codex, and 60+ other agents):

```bash
npx skills add erfnzdeh/arvancloud-agent-skill
```

That command discovers the `arvancloud-api` skill in this repo. If the installer asks which skill to add, choose `arvancloud-api`.

### npm / skillpm

```bash
npx skillpm install arvancloud-api-skill
```

Package: [`arvancloud-api-skill`](https://www.npmjs.com/package/arvancloud-api-skill) on npm.

### Claude Code plugin

```text
/plugin marketplace add erfnzdeh/arvancloud-agent-skill
/plugin install arvancloud-api@arvancloud-agent-skill
```

The marketplace name is `arvancloud-agent-skill`; the plugin name is `arvancloud-api`. Submitted to Anthropic's plugin directory for review.

### Cursor

Browse or install from [cursor.directory/plugins/arvancloud-api](https://cursor.directory/plugins/arvancloud-api). The listing may stay hidden until their security scan finishes.

Cursor also picks the skill up from a clone (below) or from `npx skills add`.

### Manual clone

Personal (Claude Code):

```bash
git clone https://github.com/erfnzdeh/arvancloud-agent-skill.git ~/.claude/skills/arvancloud-api
```

Personal (Cursor):

```bash
git clone https://github.com/erfnzdeh/arvancloud-agent-skill.git ~/.cursor/skills/arvancloud-api
```

Project-specific clones work the same way under `.claude/skills/` or `.cursor/skills/`. Cursor also loads compatible skills from `.claude/skills/`.

## Setup

No credentials live in this repo. The skill reads an API key from an environment variable at runtime (default name `$ARVAN_KEY`: confirm the real name; see Setup in [`skills/arvancloud-api/SKILL.md`](skills/arvancloud-api/SKILL.md)). Per-user state (region, cert-deploy hooks) belongs in `~/.config/arvan/config.json`.

## What it covers

- CloudDNS records and domains, cache purge, CDN security settings
- Cloud Server / IaaS: v3 regional API, legacy v1, and the undocumented v2 backup and volume routes
- Regions and availability zones, including which v3 hosts actually work
- Object Storage management API and S3 endpoints (separate auth scheme)
- Edge Computing, Cloud Container, VOD, Live, Video Ads
- Account identity (`/v1/me`), multi-account keys, and a table of real error responses
- Let's Encrypt DNS-01 wildcards via acme.sh `dns_arvan`
- Two API helper scripts: a safe request wrapper and a read-only account inventory

Hosts, paths and response shapes were checked against the published OpenAPI specs and read-only live calls.

## What's in here

- `skills/arvancloud-api/SKILL.md`: the skill itself (frontmatter + instructions, product map, auth, gotchas).
- `skills/arvancloud-api/references/dns-and-tls.md`: DNS records, domains, cache purge, CDN settings, Let's Encrypt wildcard cert issuance.
- `skills/arvancloud-api/references/iaas.md`: Cloud Server v3, v1 and v2, regions, create body, backups, quota.
- `skills/arvancloud-api/references/object-storage.md`: Object Storage management API, S3 endpoints, usage reports.
- `skills/arvancloud-api/references/products.md`: Edge Computing, Live, VOD, Video Ads, Cloud Container.
- `skills/arvancloud-api/references/mcp-cross-check.md`: corrections against `arvancloud-mcp`, the official CLI, and earlier versions of this skill.
- `skills/arvancloud-api/scripts/arvan-api.sh`: request wrapper (key resolution, write guard, retries, error hints).
- `skills/arvancloud-api/scripts/arvan-inventory.sh`: read-only snapshot of one account.
- `skills/arvancloud-api/assets/config.example.json`: placeholder for per-user config (no secrets, just env var *names*).
- `.claude-plugin/`: Claude Code marketplace + plugin manifests.
- `.cursor-plugin/`: Cursor plugin manifest.
- `package.json`: npm / skillpm package `arvancloud-api-skill`.

## Listings

| Hub | Link |
| --- | --- |
| GitHub | [erfnzdeh/arvancloud-agent-skill](https://github.com/erfnzdeh/arvancloud-agent-skill) |
| skills.sh | [skills.sh/erfnzdeh/arvancloud-agent-skill](https://skills.sh/erfnzdeh/arvancloud-agent-skill) |
| npm | [arvancloud-api-skill](https://www.npmjs.com/package/arvancloud-api-skill) |
| Cursor Directory | [cursor.directory/plugins/arvancloud-api](https://cursor.directory/plugins/arvancloud-api) |
| Cursor Forum | [Built for Cursor](https://forum.cursor.com/t/arvancloud-api-unofficial-agent-skill-for-arvancloud-dns-iaas-object-storage-cdn-and-lets-encrypt/171446) |
| Claude plugin directory | Submitted via Console; self-serve install is the `/plugin marketplace add` path above |

The skills.sh website index can lag the CLI. If search does not show the skill yet, install with `npx skills add` anyway.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Endpoint corrections and gotchas
go in [issues](https://github.com/erfnzdeh/arvancloud-agent-skill/issues).
Security reports are private: see [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
