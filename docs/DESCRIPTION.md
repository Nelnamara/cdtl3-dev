# CooldownTimeline 3 (CDTL3)

CDTL3 shows your cooldowns as icons that slide along a timeline toward a "ready" mark. When a cooldown is back, you get a sound, a flash and an icon in a Ready frame. It also times your items, your buffs and debuffs, internal cooldowns, and flights. Nothing to set up first: spells, items and buffs show up as you use them.

Works on Retail (Midnight), MoP Classic, TBC Anniversary, Classic Era and World of Warcraft: Forever. One download covers them all.

Continues Cooldown Timeline by Vreenak and the V2 rewrite by cliffclive.

## What you get

**Getting started**
- A short tour on a first install, and a Simple tab with the settings most people change
- Starter, Healer, Tank and DPS setups you can preview on your real frames, then keep or undo
- Ready-made looks (CDTL3 Classic, Minimal, Blizzard Modern, Class Colours), and your own saved looks
- A ~ before times CDTL3 has to estimate (optional)

**On the lanes and icons**
- Three lanes, three bar frames and three Ready frames: send each spell, item or buff where you want it
- Charge pips on spells with charges, a flash when a buff lands or drops, and a pulse just before a cooldown is back
- A burst window shaded on the lane, with a list of the cooldowns that will be back for it
- A mana gauge on the lane, and a bar that changes colour at a resource number
- Flight timers: a countdown to landing on every flight path
- In combat on Retail and WoW: Forever, spell cooldowns follow the game's own timer at their real length

**Boards and groups**
- A Ready frame that keeps a slot for every pinned defensive, bright when ready
- A Fight Timeline showing where each pinned cooldown will be at 2, 3 and 5 minutes
- A Caster lane for other players' cooldowns, with each caster's name under their icon
- A strip on your cooldown icon showing who you gave an external to
- A Burst pack for lust, Sated, your trinkets and a potion

**Filters**
- Everything detected is listed, with a line that says why something isn't showing
- Pick spells from your spellbook before you have ever cast them
- Hide spells you don't know, or keep a spell to one spec
- One button to set up every buff in Blizzard's Cooldown Manager Tracked Bars (Retail and WoW: Forever)

**Sounds and showing**
- A ready sound, a flash and a spoken name for each spell, and every sound menu plays your choice as you pick it
- Show each lane, bar frame or Ready frame always, only in combat, or only in boss fights
- Edit Mode support (not on Classic Era) and anchoring to other frames

**Profiles and sharing**
- Per-spec profiles, shared lists across your characters, and profiles by zone (raid, dungeon, PvP, open world)
- Share your settings as a string, with a preview of what is inside
- Masque skins, and any font, texture or sound from LibSharedMedia

## Works with CooldownCollaborator

CooldownCollaborator is a separate addon that shares major group cooldowns between players who run it. CDTL3 and CooldownCollaborator work together. With both installed, your group's cooldowns show on CDTL3's lanes next to your own: yours, and those of group members who also run CooldownCollaborator.

- They show on Lane 1 by default. To choose another lane, bar frame or Ready frame, or to switch them off, open **Filters › Defaults** and pick *Group cooldowns*.
- To see who cast each one, tick **Lanes › (a lane) › General › Caster lane**. Each caster's name shows under their icon, in their class colour.
- In CooldownCollaborator's settings, the box *Show group cooldowns on CDTL3's lanes* turns this on or off. It is on by default when CDTL3 is loaded.
- On MoP Classic, TBC Anniversary and Classic Era, CDTL3 can also read other players' raid cooldowns from the combat log on its own: **Filters › Defaults › Track raid cooldowns**. On Retail and WoW: Forever the game hides other players' casts, so their cooldowns need CooldownCollaborator on both players.

## Getting started

1. Install CDTL3 with the CurseForge or Wago app. The folder must be named `CooldownTimeline3`.
2. Restart the game fully. A new addon is not picked up by `/reload`.
3. Follow the short tour on your first login, or type `/cdtl3` to open the settings.
4. Use your abilities. Cooldowns, items and buffs appear on the lane as you use them. The Simple tab has the basics; Quick Style has the Healer, Tank and DPS setups.
5. Drag the frames where you want them, then type `/cdtl3 lock`.

## Commands

- `/cdtl3` opens the settings. The Help tab lists every command with a Run button.
- `/cdtl3 lanes`, `ready`, `bars`, `filters`, `profiles` open that tab
- `/cdtl3 lock` and `/cdtl3 unlock` lock or unlock the frames for moving
- `/cdtl3 test` shows sample icons
- `/cdtl3 minimap` shows or hides the minimap button
- `/cdtl3 combattimers [on|off]` shows or switches the combat timers (Retail and WoW: Forever)
- `/cdtl3 auras` reports your buffs and debuffs as CDTL3 sees them. Use it if a buff won't show
- `/cdtl3 report` opens a bug report you can copy, `/cdtl3 log` shows quiet errors, `/cdtl3 perf` shows CPU and memory
- `/cdtl3 help` lists the commands in chat

## Bugs and requests

Report bugs and ask for features on GitHub: https://github.com/Nelnamara/cdtl3-dev/issues. Type `/cdtl3 report` in game and paste the result into your report. There is no Discord.

## Changelog

### 3.2.0

**Getting started**
- **A three-step tour** on a first install shows what the lane, the bars and the Ready frame are, with sample icons, then Lock in place and Open settings
- **The Simple tab** comes first: what to track, timeline width, icon size, the ready sound and a lock button
- **Setups by role** (Quick Style › Setup): Starter, Healer, Tank or DPS appear on your real frames with sample icons first; *Keep* saves it, *Undo* puts your lanes back, and a setup you never kept is undone at your next login
- **Your own looks** — save the current look as a card, apply it to everything or to one lane, bar frame or Ready frame, and share it as a string
- **Help** — the minimap tooltip shows whether frames are locked and combat timers are on, Alt-click opens a Help tab with every command
- **A ~ before estimated times** (Global tab, off by default) tells a time CDTL3 counts itself from one that follows the game's own timer

**On the lanes and icons**
- **Charge pips** on spells with charges, the icon riding the recharge until every charge is back
- **Buff alerts** — a lane flash when a buff lands or drops, with a sound
- **A burst window** shaded on the lane, with an optional *Ready-by list* of the cooldowns that will be back for it
- **A refresh zone** for DoTs on Classic clients, **a pulse** before a cooldown comes back, and **GCD waits** that sit in the Ready frame instead of looking like a real cooldown
- **A mana gauge** at a lane's Ready end, **a bar that changes colour** at a resource number (and Brewmaster **Stagger** tracking)

**Boards and groups**
- **A Ready frame that shows every pinned defensive** (*Stay until used*), bright when ready and dimmed with its time when cooling
- **A fight timeline** with flags at 2, 3 and 5 minutes showing where each pinned cooldown will be
- **A Caster lane** for other players' cooldowns, with each caster's name under their icon: from the combat log on MoP, TBC and Classic Era, and from CooldownCollaborator where it is installed
- **Group cooldowns from CooldownCollaborator** show on CDTL3's lanes — yours and those of group members who also run it. They land on Lane 1; Filters › Defaults › Group cooldowns picks another lane, bar frame and Ready frame, or switches them off
- **Externals you gave** — a strip on your cooldown icon with the target's name and the effect's time left
- **Burst pack** (Filters › Defaults) sets up lust, Sated, your trinkets and potion on a Burst lane, with an optional Burst strip

**Filters**
- **Says why a spell or buff isn't showing** — pick an entry and a line says what's hiding it (ignored for being over the Ignore Threshold, longer than the lane's Max Time, its lane switched off…) with a *Show anyway* button. The first time a long cooldown is ignored automatically, one chat line says so
- **My spells** — Filters › Spells lists your spellbook's cooldowns with ticks, so you can pick spells before you've ever cast them, plus *Show only the ticked spells*
- **Hide spells I don't know** and **Only for this spec** — spells you've talented out of leave the lane, and a spell can be kept to one spec (Retail and MoP)
- **Pull from Cooldown Manager** (Retail and WoW: Forever) — one button in Filters › Buffs sets up every buff in the Cooldown Manager's Tracked Bars

**Ready sounds and showing**
- **A ready sound per spell** — each entry can have its own sound, flash when ready, and say its name out loud (text to speech, in the voice you picked in the game's text to speech settings, or the first installed voice). The Ready tab gets *Mute ready sounds* and a *Play sound* button
- **Hear a sound as you pick it** — every sound menu plays your choice once, and the menus are twice as wide so long names can be read
- **Blizzard sounds** — a selection of the game's own alerts and chimes (raid warning, quest complete, level up, alarm clocks, bells…) joins every sound menu, each one checked to exist on every client
- **Show per lane, bar frame and Ready frame** — *Always*, *Only in combat* or *Boss fights only*, with *Dim instead of hide*. The default follows the Global tab's *Hide out of combat*, as before
- **Preview with sample icons** — a button at the top of the Global tab (or Shift-click the minimap button) shows sample icons, then *Stop preview*
- **Placing frames** — the "Frames unlocked" box says to drag the frames and then click Lock (and that Edit Mode can place them too) until your first lock. Your first flight says the countdown is CDTL3's and where to turn it off

**Placing and profiles**
- **Anchor to** — a lane, bar frame or Ready frame can follow the player frame, the Cooldown Manager or any frame by name, with an offset. Only CDTL3's own frames move
- **Share my Custom timers and spell settings with all my characters** (Profiles tab, off by default), **New characters start on** (the Default profile, the last one used, or one you choose), and **Profiles by zone** (raids, dungeons, PvP, open world)

**Sharing**
- **Share strings with a preview** — an import first says what's in it ("3 lanes, 41 spells, made on 3.1.1 Retail"), warns about spells your client doesn't have, and can go into a new profile. Imported spells show in your Filters at once. Each lane has *Copy this lane*. Older strings still import
- **Masque** gets a group per timer type (spells, items, buffs…), keeping your current skin
- **A missing font, bar texture or sound** shows "(missing)" in its menu and uses CDTL3's own instead of going silent

**For bug reports and other addons**
- `/cdtl3 report` opens a ready-to-copy bug report, `/cdtl3 log` shows what failed quietly, `/cdtl3 perf` shows memory and frame counts, and `/cdtl3 help` lists every command
- **Update rate** (Global tab) and **Pause while hidden** (per lane) for slower machines; timers and Ready stay on time
- Other addons can listen for a timer starting, getting ready and ending, read what's tracked, and add their own timers to the lanes: see [Extending CDTL3](https://github.com/Nelnamara/cdtl3-dev/blob/main/docs/EXTENDING.md)

**Fixes**
- **Importing a "Settings only" string as "All settings and data" no longer empties your Filters lists**, and a damaged string is refused before it can change anything
- **Clearing a spell's settings, Reset Profile and Copy From now ask first** when other characters on the profile use them, instead of wiping them silently
- **Cooldowns on a switched-off lane** no longer lose their bar for the last 2 minutes
- **An early reset** (Cold Snap, Preparation, Readiness) now shows the Ready icon along with the sound, and a switched-off Ready frame no longer plays one
- **Ready › Highlight Duration and Pinned Hide Time** now do what they say
- **The "Frames unlocked" box** follows the lock when you switch profile, and its Lock button always locks
- **Custom › Add New**: *Enabled* can be unticked, and a mistyped Trigger ID is refused (Retail and WoW: Forever)
- **In combat on Retail and WoW: Forever**: the GCD marker shows, a Tracked Bars buff no longer jumps to Ready after Alt+Z, and a new trinket or potion no longer shows a frozen 16:40 bar
- **Lanes**: Secondary Tracking shows as soon as you turn it on, the secondary marker on vertical lanes moves along the lane, lane texts with live tags update, Override Autohide brings back an empty lane, every lane and bar frame comes back at the pull with *Hide out of combat*, and Split Count takes whole numbers
- **Edit Mode** sliders reach the same sizes as the options window; lane width now goes to 1000 and bar width to 600 in both
- **Grouped stacking** does far less work and looks the same; a lone icon in a short stack stays in the lane
- **TBC Anniversary**: flights that don't start from the flight map no longer count down under internal names
- **Undo on a setup preview** puts a buff you gained, or a spell you cast, during the preview back on its own lane, instead of leaving it on the preview's lane until a reload
- **Bar frames**: the transition indicator line stays inside its bar, and shows only on a bar that will hand off to its lane; it used to sit far out to the right, over other frames, when the lane held more time than the whole cooldown
- **Test mode** no longer lists test cooldowns twice
- **Classic clients** read buffs and the combat log through Blizzard's current names, ahead of the old ones being removed
