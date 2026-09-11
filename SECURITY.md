# Security

This skill drives a cloud account: DNS, servers, buckets, and TLS
certificates. A leaked key or a prompt that writes one into the repo is
the failure mode that matters.

## Reporting

Do not open a public issue for:

- a prompt or example that would put an API key, S3 secret, or acme.sh
  token into git
- a way the skill tells an agent to echo `ARVAN_KEY` (or whatever the
  env is called) into a ticket, a log, or `assets/config.example.json`
- a cert-deploy hook that would copy a private key to a host you did
  not name

Use a
[private vulnerability advisory](https://github.com/erfnzdeh/arvancloud-agent-skill/security/advisories/new).
Redact keys. A leaked machine-user key is revoked in npanel under IAM,
not by opening an issue.

## In scope

- Instructions that persist secrets inside the skill directory
- Auth header mistakes that would send a key to the wrong host
- Object Storage examples that confuse the machine-user key with S3
  credentials
- `dns_arvan` / acme.sh steps that leave a token in a world-readable file

## Out of scope

- ArvanCloud's own API, panel, or IAM. Report those to them.
- A 403 from an under-permissioned key. That is IAM, not this repo.
- Anyone using the skill against an account they own. That is the point.

## Operator notes

`assets/config.example.json` is names only. Real state belongs in
`~/.config/arvan/config.json`, which is outside the skill. If a key has
been in a chat or a screenshot, revoke it and make another machine user.
