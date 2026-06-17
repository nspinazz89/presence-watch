---
name: presence-aware
description: Adapt how you work to whether the user is physically present, using presence-watch's present/away signal. Use at the start of a task and whenever deciding whether to block on a question or notify asynchronously — especially when the user may be away from their machine (AFK).
---

# Presence-aware working

`presence-watch` records whether the user is at their desk (via Apple Watch
Bluetooth proximity). Read that signal and let it shape *how* you work — when to
ask vs. decide for yourself, when to interrupt vs. notify asynchronously. It
changes your **interaction style only**, never *what* you're permitted to do.

## Check presence

Run the helper — it prints exactly one of `present`, `away`, or `unknown`:

```sh
<presence-watch>/bin/presence-state.sh
```

(Replace `<presence-watch>` with the install path, or set `PRESENCE_STATE_CMD`.)

## How to adapt

**`present` — the user is at the machine:**
- Work interactively as normal: ask clarifying questions when they help, surface
  things inline.
- Don't fire push notifications for anything they can already see on screen.

**`away` — the user has left:**
- Keep making progress. Don't stall waiting on input you can reasonably decide
  yourself; pick the sensible default and note it.
- Collect anything that genuinely needs the human into one place instead of
  emitting questions they can't see.
- When you finish, or hit something truly blocking, send **one** async
  notification through the user's configured channel — don't assume they're
  watching the terminal.
- Prefer reversible actions; defer irreversible or outward-facing ones until
  they're back, unless already authorized.

**`unknown` — the sensor isn't reporting:**
- **Fail open: behave exactly as you would without this skill.** Never let a
  dead sensor silently change your behavior.

## Notes
- Re-check on long-running tasks — presence can flip mid-run.
- `unknown` is the safe default; treat it as "no signal," not as "away."
