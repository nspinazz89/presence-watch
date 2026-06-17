#!/bin/zsh
# webhook sink (heartbeat) — POST the current state to an HTTP endpoint every
# tick. Heartbeat mode suits consumers that trust a report only briefly and
# should fail open if the daemon dies: they want a steady pulse, not just edges.
#
# Contract:
#   <adapter> mode                       -> prints "heartbeat"
#   <adapter> emit <state> <rssi> <prev> -> POSTs {"state":"present|away"}
#
# Config (env or presence.conf):
#   PRESENCE_WEBHOOK_URL    required — where to POST
#   PRESENCE_WEBHOOK_TOKEN  optional — sent as "Authorization: Bearer <token>".
#                           Set it however you like, e.g. from a keychain lookup
#                           in your presence.conf; the daemon doesn't care.
set -u

cmd=${1:-}
case "$cmd" in
  mode)
    print heartbeat
    ;;
  emit)
    state=${2:-}; rssi=${3:-}; prev=${4:-}
    if [[ -z "${PRESENCE_WEBHOOK_URL:-}" ]]; then
      print -u2 "webhook sink: PRESENCE_WEBHOOK_URL is unset; set it in presence.conf"; exit 0
    fi
    if [[ -n "${PRESENCE_WEBHOOK_TOKEN:-}" ]]; then
      # Token goes via stdin (-H @-) so it never lands in the process args (ps).
      code=$(printf 'Authorization: Bearer %s\n' "$PRESENCE_WEBHOOK_TOKEN" \
        | curl -s -o /dev/null -w "%{http_code}" -X POST "$PRESENCE_WEBHOOK_URL" \
          -H @- -H "Content-Type: application/json" \
          --data "{\"state\":\"$state\"}")
    else
      code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PRESENCE_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        --data "{\"state\":\"$state\"}")
    fi
    print "  -> webhook state=$state rssi=$rssi http=$code"
    ;;
  *)
    print -u2 "webhook sink: unknown command '$cmd' (want: mode | emit)"; exit 64
    ;;
esac
