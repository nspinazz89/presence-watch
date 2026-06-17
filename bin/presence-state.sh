#!/bin/zsh
# presence-state — print the presence the daemon last recorded:
#   present | away | unknown
#
# "unknown" means the daemon hasn't written within FRESH_SECS (presumed dead or
# asleep). Consumers should treat unknown as "behave normally" — i.e. FAIL OPEN,
# so a stopped sensor never silently changes behavior. This is the read side of
# the daemon; the daemon itself writes the state file every tick.
set -u

HERE=${0:A:h}
ROOT=${HERE:h}
CONF=${PRESENCE_CONF:-$ROOT/presence.conf}
[[ -f "$CONF" ]] && source "$CONF"

STATE_DIR=${STATE_DIR:-$HOME/Library/Application Support/presence-watch}
FRESH_SECS=${PRESENCE_FRESH_SECS:-300}
STATE_FILE="$STATE_DIR/state"

[[ -f "$STATE_FILE" ]] || { print unknown; exit 0; }

now=$(date +%s)
mtime=$(stat -f %m "$STATE_FILE" 2>/dev/null || echo 0)
if (( now - mtime > FRESH_SECS )); then
  print unknown
else
  cat "$STATE_FILE"
fi
