#!/bin/zsh
# presence-watch — derive present|away from Apple Watch Bluetooth proximity
# (RSSI via `system_profiler SPBluetoothDataType`, the same "is my Watch near"
# signal macOS uses for auto-unlock) and fan out to pluggable sinks. One tick
# per invocation; run on a ~60s LaunchAgent StartInterval (see install/).
#
# Pipeline:  sense (RSSI) -> decide (threshold + hysteresis) -> sinks
#
# Sinks declare their own delivery mode, so one daemon serves both models:
#   heartbeat  -> called EVERY tick with the current state. For freshness-based
#                 consumers that trust a report only briefly and then fail open
#                 (a steady pulse, not just edges).
#   edge       -> called ONLY on a present<->away transition. For notify-style
#                 consumers ("ping me when I walk away") that must not spam.
set -u

HERE=${0:A:h}                       # absolute dir of this script
ROOT=${HERE:h}                      # project root (parent of bin/)
CONF=${PRESENCE_CONF:-$ROOT/presence.conf}
[[ -f "$CONF" ]] && source "$CONF"

# ---- config: env/conf override these defaults ----
WATCH_ADDR=${WATCH_ADDR:-}                          # required: your Watch's BT address
RSSI_THRESHOLD=${RSSI_THRESHOLD:--75}               # present if rssi >= this (near ≈ -50)
AWAY_MISSES=${AWAY_MISSES:-2}                        # consecutive weak/absent reads -> away
SINKS=${SINKS:-stdout}                               # space-separated adapter names/paths
STATE_DIR=${STATE_DIR:-$HOME/Library/Application Support/presence-watch}

mkdir -p "$STATE_DIR"
MISS_FILE="$STATE_DIR/misses"
STATE_FILE="$STATE_DIR/state"

if [[ -z "$WATCH_ADDR" ]]; then
  print -u2 "presence-watch: WATCH_ADDR is unset — run bin/find-my-watch.sh and set it in $CONF"
  exit 64
fi

# ---- sense: current RSSI for the Watch, empty if it's absent from the scan ----
rssi=$(system_profiler SPBluetoothDataType 2>/dev/null \
  | grep -F -A6 "$WATCH_ADDR" | grep "RSSI" | grep -oE '\-?[0-9]+' | head -1)

# ---- decide: threshold + hysteresis ----
# present is immediate; away is debounced over AWAY_MISSES reads so a single
# dropped/weak scan doesn't flap to "away" and fire a spurious transition.
if [[ -n "$rssi" ]] && (( rssi >= RSSI_THRESHOLD )); then
  raw="present"
else
  raw="away"
fi

misses=$(cat "$MISS_FILE" 2>/dev/null || echo 0)
if [[ "$raw" == "present" ]]; then
  misses=0; state="present"
else
  misses=$((misses + 1))
  (( misses >= AWAY_MISSES )) && state="away" || state="present"
fi
echo "$misses" > "$MISS_FILE"

prev=$(cat "$STATE_FILE" 2>/dev/null || echo "unknown")
echo "$state" > "$STATE_FILE"

print "$(date '+%FT%T%z') rssi=${rssi:-none} raw=$raw misses=$misses -> $state (prev=$prev)"

# ---- dispatch: each sink gets edges or a heartbeat per its declared mode ----
for sink in ${=SINKS}; do
  if [[ "$sink" == */* ]]; then adapter="$sink"; else adapter="$ROOT/adapters/$sink.sh"; fi
  if [[ ! -x "$adapter" ]]; then
    print -u2 "presence-watch: sink '$sink' not found or not executable ($adapter)"; continue
  fi
  mode=$("$adapter" mode 2>/dev/null)
  case "$mode" in
    heartbeat) "$adapter" emit "$state" "${rssi:-none}" "$prev" ;;
    edge)      [[ "$state" != "$prev" ]] && "$adapter" emit "$state" "${rssi:-none}" "$prev" ;;
    *)         print -u2 "presence-watch: sink '$sink' declared unknown mode '$mode' (want heartbeat|edge)" ;;
  esac
done
