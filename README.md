# ArvanCloud's API Agent Skill

[![skills.sh](https://skills.sh/b/erfnzdeh/arvancloud-agent-skill)](https://skills.sh/erfnzdeh/arvancloud-agent-skill)
![license](https://img.shields.io/github/license/erfnzdeh/arvancloud-agent-skill)
![type](https://img.shields.io/badge/type-Agent_Skill-blueviolet)
![works with](https://img.shields.io/badge/works_with-Claude_Code-D97757?logo=claude&logoColor=white)
![works with](https://img.shields.io/badge/works_with-Cursor-000000)
![status](https://img.shields.io/badge/status-unofficial-orange)

Unofficial, community-maintained [Agent Skill](https://agentskills.io) for driving [ArvanCloud](https://arvancloud.ir)'s APIs (CDN, DNS, Cloud Server / IaaS, Object Storage, Edge Computing, Cloud Container, VOD/Live/Video Ads) and issuing Let's Encrypt wildcard TLS certs via acme.sh's `dns_arvan` plugin — from Claude Code, Cursor, or any agent that supports the `SKILL.md` format.

Not affiliated with or endorsed by ArvanCloud.

## Install

Primary (Claude Code, Cursor, Codex, and 60+ other agents):

```bash
npx skills add erfnzdeh/arvancloud-agent-skill
```

### Claude Code plugin

```text
/plugin marketplace add erfnzdeh/arvancloud-agent-skill
/plugin install arvancloud-api@arvancloud-agent-skill
```

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

## What's in here

- `skills/arvancloud-api/SKILL.md` — the skill itself (frontmatter + instructions, product map, auth, gotchas).
- `skills/arvancloud-api/references/dns-and-tls.md` — DNS record CRUD + Let's Encrypt wildcard cert issuance.
- `skills/arvancloud-api/references/iaas.md` — Cloud Server / IaaS specifics (3.0 vs legacy 1.0).
- `skills/arvancloud-api/references/mcp-cross-check.md` — comparison notes against `arvancloud-mcp`, including verified endpoint corrections.
- `skills/arvancloud-api/assets/config.example.json` — placeholder for per-user config (no secrets — just env var *names*).
- `.claude-plugin/` — Claude Code marketplace + plugin manifests.
- `.cursor-plugin/` — Cursor plugin manifest.

No credentials are stored in this repo. The skill reads an API key from an environment variable (`$ARVAN_KEY`) at runtime; see the "Setup" section in `SKILL.md`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Endpoint corrections and gotchas
go in [issues](https://github.com/erfnzdeh/arvancloud-agent-skill/issues).
Security reports are private: see [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE).
