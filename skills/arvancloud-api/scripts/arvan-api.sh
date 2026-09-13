#!/usr/bin/env bash
# arvan-api.sh: small, safe curl wrapper for ArvanCloud REST APIs.
# Status line and hints go to stderr, the response body goes to stdout (pipe it to jq).
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: arvan-api.sh [-X METHOD] [-d JSON | -d @file.json] [--allow-write] [--dry-run] [--retries N] <target>

Targets:
  /cdn/4.0/domains           https://napi.arvancloud.ir/cdn/4.0/domains (any napi path)
  v3:<region>/servers        https://ecc.<region>.arvanapis.ir/v3/servers
                             region is ir-central1, ir-northwest1 or eu-west1 (not an AZ code)
  storage:/v1/buckets        https://storage.arvanapis.ir/v1/buckets
  auth:/v1/me                https://dejban.arvancloud.ir/v1/me
  https://...                full URL; only https on *.arvancloud.ir or *.arvanapis.ir

Key: taken from the env var named by $ARVAN_KEY_ENV, else "apiKeyEnv" in
~/.config/arvan/config.json, else $ARVAN_KEY. A bare UUID or an "apikey <uuid>"
value (any case) is normalized to "Authorization: Apikey <uuid>".

Any method other than GET/HEAD refuses to run without --allow-write.
Use --dry-run to print the exact request (without the key) for confirmation.
Exit codes: 0 success, 1 HTTP or network error, 2 usage, 3 key env var unset, 4 write refused.
EOF
  exit 2
}

need_value() { [ $# -ge 2 ] && [ -n "$2" ] || { echo "arvan-api: $1 needs a value" >&2; usage; }; }

method=GET data="" allow_write=0 dry_run=0 target="" retries=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X|--method) need_value "$@"; method="$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')"; shift 2 ;;
    -d|--data) need_value "$@"; data="$2"; shift 2 ;;
    --allow-write) allow_write=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --retries) need_value "$@"; retries="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "arvan-api: unknown option $1" >&2; usage ;;
    *) [ -z "$target" ] || usage; target="$1"; shift ;;
  esac
done
[ -n "$target" ] || usage
case "$method" in *[!A-Z]*|'') echo "arvan-api: invalid method '$method'" >&2; exit 2 ;; esac
if [ -n "$data" ] && [ "$method" = GET ]; then method=POST; fi

bad_suffix() { echo "arvan-api: '$target' must continue with a path starting with /" >&2; exit 2; }
case "$target" in
  https://*) url="$target" ;;
  http://*) echo "arvan-api: refusing plain http; the key is only sent over https" >&2; exit 2 ;;
  v3:*) rest="${target#v3:}"; region="${rest%%/*}"; path="${rest#"$region"}"
        case "$region" in ''|*[!a-z0-9-]*) echo "arvan-api: invalid v3 region '$region'" >&2; exit 2 ;; esac
        case "$path" in /*) ;; *) bad_suffix ;; esac
        url="https://ecc.${region}.arvanapis.ir/v3${path}" ;;
  storage:*) path="${target#storage:}"; case "$path" in /*) ;; *) bad_suffix ;; esac
        url="https://storage.arvanapis.ir${path}" ;;
  auth:*) path="${target#auth:}"; case "$path" in /*) ;; *) bad_suffix ;; esac
        url="https://dejban.arvancloud.ir${path}" ;;
  /*) url="https://napi.arvancloud.ir${target}" ;;
  *) echo "arvan-api: target must start with /, v3:, storage:, auth: or https://" >&2; exit 2 ;;
esac

# Only ever send the key to ArvanCloud API hosts.
hostpart="${url#https://}"; host="${hostpart%%[/?#]*}"
case "$host" in
  *[!a-z0-9.-]*|'') echo "arvan-api: refusing host '$host' (no userinfo, ports or unusual characters)" >&2; exit 2 ;;
  *.arvancloud.ir|*.arvanapis.ir) ;;
  *) echo "arvan-api: refusing to send the API key to '$host'; only *.arvancloud.ir and *.arvanapis.ir are allowed" >&2; exit 2 ;;
esac

cfg="${ARVAN_CONFIG:-$HOME/.config/arvan/config.json}"
cfg_get() { [ -f "$cfg" ] && command -v jq >/dev/null 2>&1 && jq -r "$1 // empty" "$cfg" 2>/dev/null || true; }
timeout="$(cfg_get .timeoutSeconds)"; timeout="${timeout:-60}"
[ -n "$retries" ] || retries="$(cfg_get .maxRetries)"; retries="${retries:-3}"
backoff="$(cfg_get .backoffFactor)"; backoff="${backoff:-1}"
case "$retries" in *[!0-9]*|'') echo "arvan-api: retries must be a non-negative integer" >&2; exit 2 ;; esac

is_write=1
case "$method" in GET|HEAD) is_write=0 ;; esac

if [ "$dry_run" = 1 ]; then
  printf '%s %s\n' "$method" "$url"
  case "$data" in
    '') ;;
    @*) f="${data#@}"; [ -r "$f" ] || { echo "arvan-api: cannot read body file $f" >&2; exit 2; }
        printf 'body (from %s):\n' "$f"; cat "$f"; printf '\n' ;;
    *) printf 'body: %s\n' "$data" ;;
  esac
  exit 0
fi
if [ "$is_write" = 1 ] && [ "$allow_write" != 1 ]; then
  echo "arvan-api: refusing $method $url without --allow-write." >&2
  echo "Show the user the method, URL and body (use --dry-run), get an explicit yes, then re-run with --allow-write." >&2
  exit 4
fi

var="${ARVAN_KEY_ENV:-}"
[ -n "$var" ] || var="$(cfg_get .apiKeyEnv)"
var="${var:-ARVAN_KEY}"
case "$var" in ''|[0-9]*|*[!A-Za-z0-9_]*) echo "arvan-api: invalid env var name '$var'" >&2; exit 2 ;; esac
raw="${!var:-}"
if [ -z "$raw" ]; then
  echo "arvan-api: \$$var is unset or empty. Ask the user which env var holds their ArvanCloud API key." >&2
  exit 3
fi
# Trim whitespace/CR/LF and strip an "apikey" prefix in any case. The key goes through a pipe, never argv.
tok="$(printf '%s' "$raw" | tr -d '\r\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^[Aa][Pp][Ii][Kk][Ee][Yy][[:space:]]+//')"
[ -n "$tok" ] || { echo "arvan-api: \$$var contains no key" >&2; exit 3; }

umask 077
tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
printf 'Authorization: Apikey %s\n' "$tok" > "$tmpdir/auth"
body="$tmpdir/body"

req_args=(-X "$method")
[ "$method" != HEAD ] || req_args=(-I)
if [ -n "$data" ]; then req_args+=(-H 'Content-Type: application/json' --data-binary "$data"); fi

attempt=0
while :; do
  : > "$body"; : > "$tmpdir/headers"
  rc=0
  code="$(curl -sS -m "$timeout" "${req_args[@]}" -o "$body" -D "$tmpdir/headers" -w '%{http_code}' \
    -H @"$tmpdir/auth" -H 'Accept: application/json' "$url" 2>"$tmpdir/err")" || rc=$?
  [ "$rc" = 0 ] || code=000
  retryable=0
  case "$code" in
    429) retryable=1 ;;
    5??) [ "$is_write" = 0 ] && retryable=1 ;;
    # Only transient curl failures (connect, timeout, TLS handshake, empty reply, send/recv). Never DNS (6) or certificate (60) errors.
    000) case "$rc" in 7|28|35|52|55|56) [ "$is_write" = 0 ] && retryable=1 ;; esac ;;
  esac
  if [ "$retryable" = 1 ] && [ "$attempt" -lt "$retries" ]; then
    delay="$(awk -v b="$backoff" -v a="$attempt" 'BEGIN { printf "%.1f", b * (2 ^ a) }')"
    echo "arvan-api: HTTP $code on $method $url, retrying in ${delay}s" >&2
    sleep "$delay"; attempt=$((attempt + 1)); continue
  fi
  break
done

echo "HTTP $code $method $url" >&2
if [ "$code" = 000 ]; then
  cat "$tmpdir/err" >&2
  case "$rc" in
    6) echo "hint: host did not resolve. Check the base URL against the product map in SKILL.md." >&2 ;;
    60) echo "hint: TLS name mismatch. v3 hosts take a region (ir-central1, ir-northwest1, eu-west1), not an AZ code." >&2 ;;
  esac
fi
case "$code" in
  3??) loc="$(grep -i '^location:' "$tmpdir/headers" | tail -1 | tr -d '\r' | cut -d' ' -f2-)"
       echo "hint: redirect to ${loc:-an unknown location}. Not followed, so the key is never forwarded; call the final https URL directly." >&2 ;;
  401) echo "hint: key rejected. Check its value, that it is not revoked, and that it belongs to this account." >&2 ;;
  403) if grep -qi 'info completion' "$body"; then
         echo "hint: the account's profile/KYC is incomplete. The route is valid; finish verification in the panel." >&2
       elif grep -qi 'upgrade plan' "$body"; then
         echo "hint: this feature needs a higher product plan. The key and route are fine." >&2
       else
         echo "hint: the machine user lacks an IAM access rule for this product or resource." >&2
       fi ;;
  404) grep -qi 'domain not found' "$body" && echo "hint: Live, VOD and Video Ads need their product domain first (GET/POST /<product>/2.0/domain)." >&2 || true ;;
  405) grep -q 'required_plan' "$body" && echo "hint: this feature is gated by the CDN plan (see required_plan in the body)." >&2 || true ;;
  420) echo "hint: IaaS quota limit reached (see GET /ecc/v1/regions/{az}/quota)." >&2 ;;
  428) echo "hint: Cloud Container has no namespace for this account in that zone yet." >&2 ;;
  429) echo "hint: rate limited; slow down or raise backoffFactor." >&2 ;;
esac
if [ "$method" = HEAD ]; then cat "$tmpdir/headers"; else cat "$body"; fi
case "$code" in 2??) exit 0 ;; *) exit 1 ;; esac
