# Contributing

Corrections to endpoints, auth, and the cert flow are the useful patches.
This is a skill, not an SDK: the files an agent reads have to stay true,
or it will call the wrong host with the wrong header.

## Before you write code

Open an [issue](https://github.com/erfnzdeh/arvancloud-agent-skill/issues)
if you are adding a product surface, not just fixing a path.

Things to keep:

- **The API key never lives in this repo.** Not in `SKILL.md`, not in
  `assets/config.example.json`, not in a reference as a "worked example".
  The skill reads an env var whose *name* may be in
  `~/.config/arvan/config.json`. The value does not.
- **Live OpenAPI specs are the source of truth.** If the panel and this
  skill disagree, the spec wins. Say which URL you checked.
- **Object Storage is not the machine-user key.** S3 credentials are a
  different pair. Do not collapse them.

There is no test suite. A change to an endpoint should include the
`curl` (redact the header) that proved it.

## Setup

```bash
npx skills add erfnzdeh/arvancloud-agent-skill
```

Or clone the repo under `~/.cursor/skills/arvancloud-api` / `~/.claude/skills/arvancloud-api` as in the README. The skill lives in `skills/arvancloud-api/`. You need an ArvanCloud machine-user
key in an environment variable to exercise anything. Do not put that key
in a PR.

## Pull requests

- One product or one gotcha per PR.
- Keep `SKILL.md` short enough that an agent will actually read it.
  Long tables go in `references/`.
- Match the surrounding prose. No em dashes.
- Do not commit `~/.config/arvan/config.json` or a filled-in key.

## Surfaces

| Path | What it is |
|---|---|
| `SKILL.md` | Frontmatter, product map, auth, the rules that bite. |
| `references/dns-and-tls.md` | DNS CRUD and acme.sh `dns_arvan`. |
| `references/iaas.md` | Cloud Server v3, v1 and undocumented v2; regions and AZs. |
| `references/object-storage.md` | Object Storage management API and S3 endpoints. |
| `references/products.md` | Edge Computing, Live, VOD, Video Ads, Cloud Container. |
| `references/mcp-cross-check.md` | Corrections against `arvancloud-mcp`, the official CLI and older skill versions. |
| `scripts/arvan-api.sh` | Request wrapper. Keep it bash 3.2 compatible and GET-only by default. |
| `scripts/arvan-inventory.sh` | Read-only account snapshot. GET requests only. |
| `assets/config.example.json` | Env *names* only. No values. |

Contributions are under the same MIT license as the rest of the repo.
Not affiliated with or endorsed by ArvanCloud.
