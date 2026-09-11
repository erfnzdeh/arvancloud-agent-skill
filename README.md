# ArvanCloud's API Agent Skill

![license](https://img.shields.io/github/license/erfnzdeh/arvancloud-agent-skill) ![type](https://img.shields.io/badge/type-Agent_Skill-blueviolet) ![works with](https://img.shields.io/badge/works_with-Claude_Code-D97757?logo=claude&logoColor=white) ![status](https://img.shields.io/badge/status-unofficial-orange)

Unofficial, community-maintained [Agent Skill](https://code.claude.com/docs/en/skills) for driving [ArvanCloud](https://arvancloud.ir)'s APIs (CDN, DNS, Cloud Server / IaaS, Object Storage, Edge Computing, Cloud Container, VOD/Live/Video Ads) and issuing Let's Encrypt wildcard TLS certs via acme.sh's `dns_arvan` plugin — from Claude Code, Cursor, or any agent that supports the `SKILL.md` format.

Not affiliated with or endorsed by ArvanCloud.

## What's in here

- `SKILL.md` — the skill itself (frontmatter + instructions, product map, auth, gotchas).
- `references/dns-and-tls.md` — DNS record CRUD + Let's Encrypt wildcard cert issuance.
- `references/iaas.md` — Cloud Server / IaaS specifics (3.0 vs legacy 1.0).
- `assets/config.example.json` — placeholder for per-user config (no secrets — just env var *names*).

No credentials are stored in this repo. The skill reads an API key from an environment variable (`$ARVAN_KEY`) at runtime; see the "Setup" section in `SKILL.md`.

## Install

### Claude Code

Personal (all your projects):

```bash
git clone https://github.com/erfnzdeh/arvancloud-agent-skill.git ~/.claude/skills/arvancloud-api
```

Project-specific (travels with a single repo):

```bash
git clone https://github.com/erfnzdeh/arvancloud-agent-skill.git .claude/skills/arvancloud-api
```

### Cursor

Cursor loads persistent instructions from `.cursor/rules/` rather than `SKILL.md`. To use this skill in Cursor, convert it into a rule (e.g. copy `SKILL.md`'s body into a `.cursor/rules/arvancloud-api.mdc` file) or reference this repo's `SKILL.md` directly from a rule.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Endpoint corrections and gotchas
go in [issues](https://github.com/erfnzdeh/arvancloud-agent-skill/issues).
Security reports are private: see [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE).
