# Extending CDTL3

For other addon authors and WeakAuras. CDTL3 sends messages when a timer starts, becomes ready and ends, offers a read-only API of what it tracks, and keeps a small compatibility layer for game functions that moved between clients.

Everything here is public and versioned: `CDTL3.API.version` is `1`. Anything not on this page (frames, `CDTL3.cooldowns`, `CDTL3.db`) is private and changes between releases.

## Hidden values

On Retail and WoW: Forever the game hides some cooldown and aura values in combat. CDTL3 never passes a hidden value out. While a timer's times are hidden, `duration` and `expires` are `nil`, and everything else is still there. A timer's `estimated` field is `true` when the time is only CDTL3's estimate (a buff it can't read in combat, a flight time it has not learned). Check for `nil` before you use a time.

## Messages

CDTL3 embeds AceEvent, so the messages go through AceEvent's message system (CallbackHandler underneath). Listen with `RegisterMessage` on any AceEvent object:

| Message | When |
| --- | --- |
| `CDTL3_TimerStarted` | A timer starts, or restarts from a new use. Moving a running timer to another lane is not a start. |
| `CDTL3_TimerReady` | The countdown reached zero. This is what a "Bestial Wrath is ready" aura wants. It still fires while times are hidden. |
| `CDTL3_TimerEnded` | The timer is done: its time in the Ready frame ran out, or it had no Ready frame to wait in. |

Each message carries one table of plain data, new for every message:

| Field | Meaning |
| --- | --- |
| `type` | `"spells"`, `"petspells"`, `"items"`, `"buffs"`, `"debuffs"`, `"offensives"`, `"customs"`, `"runes"` or `"flights"` |
| `id` | The spell, item or aura ID CDTL3 tracks it under |
| `name` | Display name |
| `icon` | Icon texture ID |
| `duration` | Full length in seconds, or `nil` while hidden or unknown |
| `expires` | When it ends, in `GetTime()` seconds, or `nil` while hidden. At Ready and Ended it is the time of the message. |
| `estimated` | `true` when the times are an estimate |

Ignored and switched-off timers send nothing. Treat the table as read-only; every listener gets the same one.

## API

`CDTL3.API` is a plain table of functions (call them with a dot). Each returns fresh copies of plain data, never CDTL3's own tables, so changing a result changes nothing in CDTL3. The timer tables have the message fields plus `lane` (1 to 3) and `ready` (`true` once the countdown is over).

- `CDTL3.API.version` is the API version (`1`). New fields can appear in a version; a removed or changed one raises it.
- `CDTL3.API.GetTimers()` is a list of every running timer.
- `CDTL3.API.GetTimer(type, id)` is one timer, running or ready, or `nil` when CDTL3 does not track it.
- `CDTL3.API.IsReady(type, id)` is `true` or `false`, or `nil` when CDTL3 does not track it.
- `CDTL3.API.GetLane(name or number)` is `{ number, name, enabled, timers }` for a lane (the name is matched without case; `timers` lists the running timers on it), or `nil`.

Example: print a line when Bestial Wrath is ready, and list the lane 1 timers on demand.

```lua
local Listener = {}
LibStub("AceEvent-3.0"):Embed(Listener)

Listener:RegisterMessage("CDTL3_TimerReady", function(message, timer)
	if timer.type == "spells" and timer.name == "Bestial Wrath" then
		print(timer.name .. " is ready")
	end
end)

function ListLane1()
	local API = CDTL3 and CDTL3.API
	if not API or API.version ~= 1 then return end
	local lane = API.GetLane(1)
	for _, timer in ipairs(lane and lane.timers or {}) do
		-- expires is nil while the game hides it
		local left = timer.expires and (timer.expires - GetTime())
		print(timer.name, left and string.format("%.0f s", left) or "hidden")
	end
end
```

## CDTL3.Compat

Some game functions exist only on some clients; WoW: Forever ships none of Blizzard's deprecation fallbacks, and Retail removed `GetItemSpell` outright. `CDTL3.Compat` wraps them so one call works everywhere:

- `CDTL3.Compat.GetItemSpell(item)`
- `CDTL3.Compat.GetItemInfoInstant(item)`
- `CDTL3.Compat.IsSpellKnown(spellID, isPet)`
- `CDTL3.Compat.IsSpellKnownOrOverridesKnown(spellID, isPet)`

They take the arguments of the game functions they replace and return the same values. If you write an addon for several clients, you can call them instead of the bare globals; guard with `CDTL3 and CDTL3.Compat`, since CDTL3 may not be installed.

## Slash commands

`/cdtl3 help` lists every subcommand with a line each.
