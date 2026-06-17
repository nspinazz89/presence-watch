#!/bin/zsh
# stdout sink (edge) — reference adapter. Prints a line only when presence
# flips, demonstrating the edge contract: fires once per present<->away
# transition, never every tick. Copy this as the template for your own sink
# (Pushover, WhatsApp, a webhook, an HTTP endpoint, a shell command…).
#
# Contract:
#   <adapter> mode                       -> prints "edge"  (or "heartbeat")
#   <adapter> emit <state> <rssi> <prev> -> delivers the event
set -u

cmd=${1:-}
case "$cmd" in
  mode)
    print edge
    ;;
  emit)
    state=${2:-}; rssi=${3:-}; prev=${4:-}
    print "  -> TRANSITION $prev -> $state (rssi=$rssi)"
    ;;
  *)
    print -u2 "stdout sink: unknown command '$cmd' (want: mode | emit)"; exit 64
    ;;
esac
