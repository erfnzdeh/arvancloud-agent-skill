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
git clone https://github.com/erfnzdeh/arvancloud-agent-skill.git ~/.cursor/skills/arvancloud-api
```

Or the Claude Code path in the README. You need an ArvanCloud machine-user
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
| `references/iaas.md` | Cloud Server 3.0 vs legacy 1.0. |
| `references/mcp-cross-check.md` | Notes against `arvancloud-mcp`. |
| `assets/config.example.json` | Env *names* only. No values. |

Contributions are under the same MIT license as the rest of the repo.
Not affiliated with or endorsed by ArvanCloud.
