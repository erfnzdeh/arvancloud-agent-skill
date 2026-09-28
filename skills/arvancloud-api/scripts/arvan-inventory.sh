#!/usr/bin/env bash
# arvan-inventory.sh: read-only snapshot of the account behind one API key.
# Covers identity, cloud servers in every region, backups, CDN domains, Object Storage,
# Edge Computing and VOD. Every call is a GET made through arvan-api.sh.
# Usage: arvan-inventory.sh            (key resolved the same way as arvan-api.sh)
#        ARVAN_V3_REGIONS="eu-west1" arvan-inventory.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
api="$here/arvan-api.sh"
command -v jq >/dev/null 2>&1 || { echo "arvan-inventory: jq is required" >&2; exit 2; }
errf="$(mktemp)"; trap 'rm -f "$errf"' EXIT

# v3 regional hosts verified on 2026-09-13. ir-southwest1-a has no working v3 host yet, so it uses v1.
regions="${ARVAN_V3_REGIONS:-ir-central1 ir-northwest1 eu-west1}"
v1_only_azs="${ARVAN_V1_ONLY_AZS:-ir-southwest1-a}"
page_size=100

emit() { while IFS= read -r line; do printf '%-24s %s\n' "$1" "$line"; done; }
fail() { printf '%-24s ERROR %s\n' "$1" "$(grep -E '^(HTTP|hint|arvan-api|curl)' "$errf" | tr '\n' ' ')"; }

# show LABEL TARGET JQ_FILTER [COUNT_FILTER]: one compact JSON line per result, "(none)" or the error.
# If COUNT_FILTER yields page_size, the list may be truncated (these endpoints did not return pagination metadata).
show() {
  local label="$1" target="$2" filter="$3" count_filter="${4:-}" out res count
  if ! out="$("$api" "$target" 2>"$errf")"; then fail "$label"; return; fi
  if ! res="$(printf '%s' "$out" | jq -c "$filter" 2>"$errf")"; then
    printf '%-24s ERROR unexpected response shape: %s\n' "$label" "$(head -c 200 "$errf")"; return
  fi
  if [ -n "$res" ]; then printf '%s\n' "$res" | emit "$label"; else printf '%-24s (none)\n' "$label"; fi
  if [ -n "$count_filter" ]; then
    count="$(printf '%s' "$out" | jq -r "$count_filter" 2>/dev/null || echo 0)"
    [ "$count" != "$page_size" ] || printf '%-24s WARNING %s items returned, list may be truncated\n' "$label" "$page_size"
  fi
}

echo "# identity"
show account auth:/v1/me '.data | {identityType, account: .account.name, accountId: .account.id, machineUser: .identity.name}'

echo "# cloud servers (v3)"
for r in $regions; do
  show "servers:$r" "v3:$r/servers?perPage=$page_size" \
    '.data[]? | {id, name, state, az: .availabilityZone, flavor: .flavor.id, publicIps: [.ipAddresses[]? | select(.isPublic) | .ipAddress]}' \
    '.data | length'
done
for az in $v1_only_azs; do
  show "servers:$az(v1)" "/ecc/v1/regions/$az/servers" '.data[]? | {id, name, status, az: "'"$az"'", flavor: .flavor.id}'
done

echo "# backups (v2)"
show backups /ecc/v2/backup/counts '.data[]? | {az: .datacenter, count}'

echo "# cdn domains"
page=1
while :; do
  if ! out="$("$api" "/cdn/4.0/domains?per_page=$page_size&page=$page" 2>"$errf")"; then fail domains; break; fi
  printf '%s' "$out" | jq -c '.data[]? | {domain, status, plan_level, type, ns: .ns_keys}' | emit domain
  last="$(printf '%s' "$out" | jq -r '.meta.last_page // 1')"
  [ "$page" -lt "$last" ] || break
  page=$((page + 1))
done

echo "# object storage"
show storage-usage storage:/v1/reports/storage '.data'
show buckets "storage:/v1/buckets?perPage=$page_size" \
  '{count: (.data | length), names: [.data[]? | .name]}' '.data | length'

echo "# edge computing and vod"
show edge-computes /edge-computing/v1/edge-computes '{count: (.meta.total // (.data | length))}'
show vod-channels /vod/2.0/channels '{count: (.meta.total // (.data | length))}'
