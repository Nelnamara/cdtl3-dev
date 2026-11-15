# Feature panel, 12 Nov 2026

Five reviewers read CDTL3 as a WoW beginner, a pro healer, a pro DPS, a pro tank and an addon author. Ideas two or more of them asked for are merged at the top. Go means worth doing; scope comes after.

Marks live on the CDTL3 Review List (https://claude.ai/artifact/WMUgWuZnMD8anEq5jtjqSL).

## Asked by several players

### 1. Per-spell ready sounds and a spoken name

*Possible on every client · Beginner, Healer, DPS, Tank · Today: one Normal and one Highlight sound per ready frame*

Tank: "One sound per frame means I can't tell Shield Wall from taunt without looking."
Each spell in Filters gets its own ready sound and flash, and an option to say the spell's name. A master mute and a Play sound test button go on the Ready tab.

### 2. Charge count and recharge on the icon

*Partly on Retail and Forever · Healer, DPS, Tank · Today: a stacks tag; the spell charge code is commented out*

DPS: "On Fire Blast I need '2 charges, next in 6 s', not a bare recharge timer."
A charge count on the icon corner, the recharging charge riding the lane, and Ready when one comes back. On Retail and Forever the count can be shown but not compared in combat, so no "alert at 2 charges" there; charges in combat are so far proven only by the test harness.

### 3. Starter setups by role

*Possible on every client · Beginner, Healer, DPS, Tank · Today: Quick Style changes looks only*

Healer: "My 3 to 5 minute cooldowns are the point, but the default Ignore Threshold hides them."
Quick Style gains setups for Healer, Tank and DPS plus a simple Starter: which lanes exist, what goes on each, and thresholds that fit the role. The Starter is one lane with bigger icons.

### 4. Say why a spell or buff isn't showing

*Possible on every client · Beginner, Tank, Healer · Today: the settings exist but the cause isn't stated*

Tank: "My 3-minute defensives vanish and I can't tell whether Hide Long Timers, Ignore Threshold or Max Time did it."
Each Filters entry shows a one-line reason ("Ignored: over the 120 s threshold", "Hidden: longer than lane 1's Max Time") with a Show anyway button, and the first auto-ignore prints one chat line saying so.

### 5. Alerts when a buff lands or drops

*Partly on Retail and Forever · DPS, Healer, Tank · Today: no gained or fell-off alert*

Tank: "I lose Ignore Pain and only notice three seconds later."
Per buff in Filters: Alert when gained (procs, externals) and Alert when it ends (active mitigation), each with a sound and a flash. Full on the Classic clients; on Retail and Forever only for buffs in the Cooldown Manager's Tracked Bars while in combat.

### 6. Boss-timing and tank-buster markers on a lane

*Needs a probe first · Healer, Tank · Retail and Forever; Classic only through boss mods*

Healer: "I want 'raid damage in 40 s' on the same lane as 'Revival ready in 25 s'."
Upcoming boss events slide along a lane as markers, from Blizzard's encounter timeline. A probe would first show whether those times are readable or hidden in combat; on Classic the times would have to come from DBM or BigWigs messages.

### 7. Show modes: in combat, boss fights, per lane

*Possible on every client · Beginner, Healer, Tank · Today: one global Hide out of combat*

Tank: "I want taunt and interrupt visible before the pull while the long defensives hide."
Hide out of combat moves onto each lane, bar frame and ready frame, with Dim instead of hide and a Boss fights only mode. A beginner is asked once in the welcome window: Always, Only in combat, or Only in groups.

### 8. One clear estimate-versus-exact marking

*Possible · Beginner, Healer · Retail and Forever*

Healer: "In combat I can't tell whether a Custom CD Time spell or an item countdown is real."
One dim style and a tooltip line ("estimate, from your cast" or "exact, game timer") on every icon and bar, a one-line legend in the lane settings, and `/cdtl3 combattimers` listing what is estimated. Today only buffs dim.

### 9. Spell lists per spec and talent loadout

*Possible · DPS, Healer · Clients with specs*

DPS: "After a talent swap the lane still shows spells I no longer have."
Filters gets Hide spells I don't know and an Only for this spec rule per entry, and learned cooldown lengths are remembered per loadout. Spec profiles exist on the Profiles tab today, but they swap everything.

## WoW beginner

### 10. A first-run welcome that explains the screen

*Possible on every client · Today: the welcome window holds only the combat timers notice, on Retail and Forever*

"A window talked about combat timers and the Cooldown Manager, and I never learned what the bar in the middle of my screen is for."
On a first install: three lines on what lanes are, with Show me (sample icons), Lock in place and Open settings buttons. What's new moves behind its own button.

### 11. A Preview button with a plain name

*Possible · Today: `/cdtl3 test` and the Test Panel*

"Nothing shows until I cast something, so I thought it was broken."
A Preview with sample icons button on the first settings tab, in the welcome window and in the minimap tooltip, turning into Stop preview while it runs.

### 12. A move-then-lock step

*Possible · Today: frames start unlocked; locking is `/cdtl3 lock` or a minimap right-click*

"Nobody told me I can drag the icons or should lock them, and I could drag one by accident in a dungeon."
While frames are unlocked, an outline and a banner say Drag me, then click Lock, with a Lock button. It goes away after the first lock and points to Edit Mode where the client has it.

### 13. Plain names and a Simple settings view

*Possible · Today: tooltips and the Quick Style tab*

"Split (Time), Ignore Threshold and Transition bars mean nothing to me, and five tabs make me afraid to touch anything."
A Simple tab first: what to show, timeline width, icon size, ready sound, position. Jargon settings get a one-line example, and each tab opens with one sentence on what it's for.

### 14. Pick my spells from the spellbook

*Possible · Today: a spell appears in Filters only after its first use*

"The lane fills with every cooldown; I just want my three main spells."
Filters › My spells lists the spellbook with icons and ticks, plus Show only the ticked spells. It works before a spell has ever been cast.

### 15. Minimap tooltip and a Help tab

*Possible · Today: the slash commands are listed on CurseForge and in the README, not in game*

"I only learned right-click locks frames from the CurseForge page."
The minimap tooltip lists left-click, right-click and drag. A Help tab answers the common questions with exact steps and shows the `/cdtl3 auras` report in a window instead of chat.

### 16. Say the flight timer is CDTL3's at the first flight

*Possible · Today: only the changelog mentions it*

"A place-name icon counted down my flight and I only found out it was CDTL3 from the changelog."
At the first flight, one chat line says CDTL3 is counting it and points to Global › Flight timers.

## Pro healer

### 17. Mana bar beside the mana cooldowns

*Possible; percent text partly on Retail and Forever · Today: lane tracking has Class Power, hard to find*

"I watch mana against the boss clock and want Innervate, Mana Tea and Hymn of Hope next to it."
Lane tracking calls it Mana for healers and gets a taller bar with percent text. In combat on Retail and Forever the bar fills but the percent can't be read.

### 18. Raid cooldown roster

*MoP, TBC and Era only · Blocked on Retail and Forever (combat log closed)*

"On MoP I call raid cooldowns and want to see when others' Rallying Cry and Hymn are back."
A Raid cooldowns lane or bar frame, one icon per caster, built from the combat log, with a tick list in Filters.

### 19. Externals I gave: target and time left

*Exact on Classic; an estimate on Retail and Forever*

"After Ironbark I want the target's name and the effect's time left, not only my cooldown."
A Show effect on target option per spell: a second countdown named with the target. On Retail and Forever it's an estimate from the cast and won't see an early removal.

### 20. Trinkets and potions exact in combat

*Retail and Forever · Needs a probe first*

"Item cooldowns freeze in combat, yet my on-use trinket and healing potion are part of the plan."
Follow the item's use-spell cooldown through the same exact timer spells use, if a probe shows the game allows it, and mark the entry exact in combat in Filters.

### 21. Anchor lanes to another frame, plus a compact mode

*Possible · Today: positions come from Edit Mode or unlock-and-drag*

"Lanes land on my raid frames and boss-mod bars."
An Anchor to setting per lane (player frame, the Cooldown Manager, a named frame) with an offset; only CDTL3's own frames move. Plus a compact single-row mode.

## Pro DPS

### 22. Burst window marker

*Possible on Classic; partly on Retail and Forever · Today: Pinned and Highlight*

"I can't see at a glance whether my cooldowns, trinket, potion and racial line up for the next burst."
A line on the lane at a chosen "in N s" mark; pinned icons that will be ready before it light up. On Retail and Forever the line draws, but ready-before-the-line can't be worked out in combat.

### 23. Pandemic refresh window on DoTs

*Era, TBC and MoP only · Blocked on Retail and Forever (enemy debuffs)*

"I refresh DoTs in the last 30%, so the icon should change colour in that window."
A Refresh window (%) per debuff in Filters that recolours the icon or bar and gives one cue. Dynamic Color does a time-based warning today, on bars only.

### 24. Burst pack: lust, Sated, trinkets, potion

*Possible on Classic; partly on Retail and Forever · Today: Custom timers by hand*

"I don't want to hand-build timers for lust, Sated, trinket procs and my potion."
One Burst pack button under Filters › Defaults adds those and sends them to a burst lane, with the trinket proc cooldowns the built-in data is missing today.

### 25. Ready-soon warning

*Possible on Classic; partly on Retail and Forever · Today: Dynamic Color recolours bars only*

"I need a cue 5 s before a big cooldown returns so I can hold the pull or potion."
Warn N s before ready per spell, with an icon pulse and an optional sound. On Retail and Forever, while the time is hidden, the cue can only come from an estimate.

### 26. GCD-aware icons

*Partly on Retail and Forever · Today: a GCD lane tracking option*

"A 1.4 s tail looks like a real cooldown."
Icons whose only wait is the global cooldown dim, and the GCD bar tints when the next ready icon lands inside it.

### 27. Fight clock and cooldown forecast

*Possible on Classic; estimates on Retail and Forever*

"I want to know which cooldowns are back for the 3:00 burst, past the lane's Max Time."
A fight clock on the lane with ticks at 2, 3 and 5 minutes showing where each pinned cooldown will be.

## Pro tank

### 28. A what's-ready board for defensives

*Possible on every client · Today: Pinned and ready-frame durations, rarely found*

"I need to see which defensive I have right now, even ones ready for minutes."
A ready frame mode Stay until used: ready icons bright, cooling ones dimmed with their timer. The ready state stays readable in combat.

### 29. Boss swing timer

*TBC, MoP and Era only · Blocked on Retail and Forever (combat log closed)*

"On TBC and MoP I time Shield Block to the boss's next swing, and only my own swing is shown."
A lane tracking choice Target melee swing, showing the boss's next hit as a bar.

### 30. Pull in the Cooldown Manager's tracked buffs

*Possible · Retail and Forever*

"Exact combat buff timers need each buff added in /cdm, then found in Filters, then given a lane."
A Filters › Buffs button Pull from Cooldown Manager that makes and assigns entries for every Tracked Bars buff and flags the ones not tracked.

### 31. Resource bar with a threshold colour

*Possible on Classic; fixed colour on Retail and Forever · Today: Health, Class Power, Combo Points tracking*

"I want a rage, Holy Power or stagger bar that changes colour at a number I care about."
Lane tracking for the tank's resource (and stagger for Brewmaster) with Change colour at. On Retail and Forever the hidden value can fill the bar but not be compared, so the colour stays fixed in combat.

## Addon maker

### 32. Public messages: timer started, ready, ended

*Possible; times nil while hidden · Hooks in at Cooldown.lua*

"I can't make a WeakAura react to 'Bestial Wrath is ready' without hooking private frames."
CallbackHandler messages `CDTL3_TimerStarted`, `CDTL3_TimerReady` and `CDTL3_TimerEnded` with plain data (type, id, name, icon, duration, expires, estimated). While values are hidden, duration and expires are nil and Ready still fires.

### 33. Register a timer type from outside

*Possible for known lengths · Hooks in at Cooldown.lua, CDTL3.lua*

"Flights needed edits in about five places, and an outside author can't make them."
`CDTL3:RegisterTimerType(key, {...})`, `StartTimer` and `StopTimer`, with flights and custom timers as the first users, replacing the per-type chains in Cooldown.lua and CDTL3.lua.

### 34. Versioned share strings with an import preview

*Possible · Today: Import/Export checks the shape only*

"An import overwrites everything without a preview."
A `!CDTL3:2!` header with the client, a preview ("3 lanes, 41 spells, made on 3.1.1 Retail") with Confirm, a warning for spells this client doesn't have, import into a new profile, and a copy button per lane.

### 35. One /cdtl3 report for bug reports

*Possible · Today: auras, oaf and combattimers are separate*

"A bug report means pasting several slash outputs by hand."
One command opens a copyable box: version, client and build, the combat timers status, the aura report, lanes, non-default settings, entry counts, recent errors, memory, and the issues link.

### 36. Log the errors that pcall swallows

*Possible · Today: debug mode prints, failures vanish*

"Every hidden-value pcall failure vanishes."
A small error log (last 200 lines) that counts failures per place without printing; `/cdtl3 log` shows it and the report includes it.

### 37. Translations with AceLocale

*Possible · Today: English only*

"Every string is inline English across Options.lua's 6,961 lines."
AceLocale with an English base, options titles and chat lines first, published to CurseForge's translation tool. Flight point names would come from the game's own names.

### 38. Performance controls and /cdtl3 perf

*Possible · Today: no rate control or profiler*

"Each cooldown frame runs its own OnUpdate, and nobody can tell which part is heavy."
An Update rate setting (full, 30 or 15 per second) for visuals only, pause while hidden per lane, and `/cdtl3 perf` with CPU, memory and frame counts.

### 39. Account-wide entries and profiles by context

*Possible · Today: Profiles tab and spec profiles*

"An alt starts empty, because everything of value is per profile."
Custom timers and per-spell overrides can be account-wide; new characters start from default, last used, or a template; profiles can switch by raid, Mythic+, PvP and world as well as by spec.

### 40. Masque groups per type and media fallbacks

*Possible · Today: one Masque group*

"There's one Masque group for everything, and a missing sound pack plays nothing."
Masque sub-groups per timer type, a "media missing, using default" note in the dropdowns, and CDTL3's own sounds and borders registered with LibSharedMedia.

### 41. A read-only API of what's tracked

*Partly on Retail and Forever (times nil while hidden)*

"A raid cooldown panel has to scrape `CDTL3.cooldowns`, whose fields change between versions."
A versioned `CDTL3.API`: `GetTimers()`, `GetTimer(type, id)`, `IsReady(type, id)`, `GetLane(name)`, returning copies of plain data.

### 42. /cdtl3 help and an Extending CDTL3 page

*Possible · Today: commands listed on CurseForge and in the README*

"The slash commands and CDTL3.Compat exist, but another author would never find them."
`/cdtl3 help` lists every subcommand, and a public page covers the messages, the API and timer types.

### 43. Save and share your own looks

*Possible · Today: built-in Quick Style looks only*

"I can't save a look of my own or hand one to a friend."
Save current look as…, export and import a look as a string, and Apply to: this lane, this bar frame, or all.
