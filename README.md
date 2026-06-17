# presence-watch

Know when you're at your desk — by Apple Watch proximity, not keyboard idle.

A tiny macOS daemon that reads your **Apple Watch's Bluetooth signal strength**
(the same "is my Watch near" signal macOS uses for auto-unlock) and emits a
`present` / `away` state to pluggable sinks. Use it to silence notifications
while you're there, ping you when you walk off, or feed presence to your own
system.

## Why Watch proximity instead of keyboard/idle time?

The usual trick — "idle for N minutes = away" — breaks on an always-on machine
whose screen stays active: you can walk away with the screen wide awake and idle
time never accrues, or sit reading without typing and get marked away. Watch
proximity measures the thing you actually care about — **is the human here** —
and survives a screen that never sleeps.

The catch is honesty: **Watch RSSI is noisy** (it swung -44 → -87 dB at one desk
while sitting still). presence-watch handles that with a threshold plus
hysteresis, and the noise is why both are tunable. See `presence.conf.example`.

## How it works

```
sense  ──>  decide  ──>  sinks
RSSI        threshold     heartbeat | edge
            + hysteresis
```

- **sense** — `system_profiler SPBluetoothDataType`, parse the RSSI for your
  Watch's paired Bluetooth address. (No active BLE scanning, no entitlements:
  it reads the paired-device table, which is why a randomized-MAC Watch is still
  findable.)
- **decide** — `present` if `RSSI >= RSSI_THRESHOLD`. `present` is immediate;
  `away` is debounced over `AWAY_MISSES` consecutive weak/absent reads so one
  dropped scan doesn't flap.
- **sinks** — each adapter declares a delivery **mode**:
  - `heartbeat` — called **every tick** with the current state. For
    freshness-based consumers that want a steady pulse (and that should fail
    open if the daemon dies).
  - `edge` — called **only on a `present`<->`away` transition**. For
    notify-style consumers that must not spam.

  One daemon serves both: a heartbeat sink and an edge sink can run side by side.

## Quick start

```sh
git clone … && cd presence-watch
cp presence.conf.example presence.conf
bin/find-my-watch.sh                 # find your Watch's BT address
$EDITOR presence.conf                # set WATCH_ADDR, pick SINKS
bin/presence-watch.sh                # run one tick, watch stdout
```

Then install the 60s LaunchAgent — see `install/com.presence-watch.plist.example`.

## Writing a sink

A sink is any executable answering two calls:

```sh
my-sink mode                          # prints "heartbeat" or "edge"
my-sink emit <state> <rssi> <prev>    # state=present|away, prev=previous state
```

Drop it in `adapters/<name>.sh` (or point `SINKS` at an absolute path to keep
private sinks out of the repo) and add its name to `SINKS`. `adapters/stdout.sh`
is the reference edge sink — copy it. `adapters/webhook.sh` is a real heartbeat
sink (POSTs `present`/`away` to any HTTP endpoint you configure).

## Reading presence (and the Claude skill)

Sinks *push* state outward. To *pull* the current state on demand, use:

```sh
bin/presence-state.sh        # prints: present | away | unknown
```

It reads the state the daemon last wrote and returns `unknown` if the daemon
hasn't reported within `PRESENCE_FRESH_SECS` (default 300) — so a dead sensor
fails open instead of lying.

Bundled with that primitive is **`skill/presence-aware/`**, a
[Claude Code](https://docs.claude.com/en/docs/claude-code) skill that teaches an
agent to adapt its working style to your presence: work interactively when
you're `present`, act autonomously and notify asynchronously when you're `away`,
and behave normally when `unknown`. Install it by copying (or symlinking) the
folder into `~/.claude/skills/`:

```sh
ln -s "$PWD/skill/presence-aware" ~/.claude/skills/presence-aware
```

The daemon is the sensor; the skill is the behavior. Either is useful alone.

## Config

All keys live in `presence.conf` (gitignored) and are env-overridable:

| key | default | meaning |
|-----|---------|---------|
| `WATCH_ADDR` | — (required) | your Watch's Bluetooth address |
| `RSSI_THRESHOLD` | `-75` | present if `RSSI >=` this; near ≈ -50 |
| `AWAY_MISSES` | `2` | consecutive weak reads before `away` |
| `SINKS` | `stdout` | space-separated adapter names/paths |
| `STATE_DIR` | `~/Library/Application Support/presence-watch` | miss/state files |

## Requirements & limits

- macOS, an Apple Watch **Bluetooth-paired to this Mac**, `zsh`, `curl`.
- The Watch must appear in `system_profiler SPBluetoothDataType` with a live
  `RSSI` line; if `find-my-watch.sh` shows no RSSI for it, this approach won't
  work on your setup.
- Reads undocumented `system_profiler` output — robust today, not API-guaranteed.

## Security & privacy

- **Presence is sensitive** — it reveals when you're at your desk. Logs default
  to your user Logs dir, never world-readable `/tmp`. If you route a sink or log
  somewhere shared, assume others can see your comings and goings.
- **`presence.conf` is sourced as shell** — it can run arbitrary code. Keep it
  owned by and writable only by you; never accept one from an untrusted source.
- **Sinks run with your privileges** — only list sinks you trust in `SINKS`.
- **No secrets in the repo.** Tokens are read from the macOS keychain at runtime;
  the webhook sink passes its token to curl via stdin so it never appears in
  `ps`, and requires you to set its target URL explicitly.
