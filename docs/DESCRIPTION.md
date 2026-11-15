# CooldownTimeline 3 (CDTL3)

CDTL3 shows your cooldowns as icons that slide along a timeline toward a "ready" mark. When something comes back up you get a sound, a flash and an icon in a Ready frame. It also tracks your items, buffs and debuffs, internal cooldowns, and even your flight path timers. There's nothing to set up first. Spells, items and buffs show up as you use them.

One download covers Retail (Midnight), MoP Classic, TBC Anniversary, Classic Era and WoW: Forever.

CDTL3 picks up where Vreenak's original Cooldown Timeline and cliffclive's V2 rewrite left off. I picked it up when Midnight broke it, and I've kept it going since.

## What's new in 3.2.0

This is the biggest update CDTL3 has had. If you already use it, a What's new window pops up once after you update, and it'll give you a quick tour if you want one.

The big stuff:

- Setting up is way easier. There's a short tour, a Simple tab with the settings most people actually change, and Healer, Tank and DPS setups you can try on your own frames before you keep them.
- Filters tell you why something isn't showing, with a Show anyway button. You can also pick spells right out of your spellbook.
- Group play. A Caster lane puts each player's name under their icon, and my new companion addon CooldownCollaborator brings your group's cooldowns onto your lanes (more on that below). There's also a Burst pack for trinkets, potions and lust where your client has it, and a Ready board for the cooldowns you pin.
- Sounds! Every spell can have its own ready sound, CDTL3 can say its name out loud, and Blizzard's own alerts and chimes have their own menu under every sound menu.
- Planning a fight: a burst window on the lane, a Fight Timeline, charge pips, a mana gauge, and a pulse right before a cooldown comes back.
- Profiles by zone, a starting profile for new characters, lists you can share across characters, and share strings that show you what's in them before you import.
- And a long list of fixes. They're all in the changelog below.

## What it does

**Getting started**
- A short tour the first time you install it, and a Simple tab with the settings most people change
- Starter, Healer, Tank and DPS setups you can preview on your own frames, then keep or undo
- Ready-made looks (CDTL3 Classic, Minimal, Blizzard Modern, Class Colours), plus your own saved looks
- An optional ~ in front of times CDTL3 has to estimate (Retail and WoW: Forever)

**Lanes and icons**
- Three lanes, three bar frames and three Ready frames. Send each spell, item or buff wherever you want it
- Charge pips, a flash when a buff lands or drops, and a pulse right before a cooldown is back. These are off until you turn them on under Lanes › (a lane) › Effects, or per spell in Filters
- A burst window shaded on the lane, with a list of what will be back in time for it
- A mana gauge on the lane, and a lane bar that changes colour at a resource number (not in combat on Retail or WoW: Forever)
- Flight timers, a countdown to landing on every flight path
- In combat on Retail and WoW: Forever, spell cooldowns follow the game's own timer at their real length

**Boards and groups**
- A Ready frame that keeps a slot for every cooldown you pin, lit up when it's ready
- A Fight Timeline, a strip from the pull showing where each pinned cooldown will be, with flags you can move (2, 3 and 5 minutes to start)
- A Caster lane for other players' cooldowns, with the caster's name under each icon
- A countdown strip on your cooldown icon for the effect you put on someone (Filters › Spells › Show effect on target)
- A Burst pack for lust and Sated where your client has them, plus your trinkets and a potion

**Filters**
- Everything CDTL3 finds is listed, with a line that tells you why something isn't showing
- Pick spells from your spellbook before you've ever cast them
- Hide spells you don't know, or keep a spell to one spec (Retail and MoP)
- One button sets up every buff in Blizzard's Cooldown Manager Tracked Bars (Retail and WoW: Forever)

**Sounds and showing**
- A ready sound, a flash and a spoken name for each spell (spoken where the game has text to speech). Every sound menu plays your pick as you choose it, and Blizzard's own sounds have a menu of their own
- Show each lane, bar frame or Ready frame all the time, only in combat, or only in boss fights
- Edit Mode support (not on Classic Era), and you can anchor frames to other frames

**Profiles and sharing**
- Per-spec profiles, lists shared across your characters, and profiles by zone (raid, dungeon, PvP, open world)
- Share your settings as a string, and see what's inside one before you import it
- Masque skins, and any font, texture or sound from LibSharedMedia

## Works with CooldownCollaborator

CooldownCollaborator is my other addon. It shares the big group cooldowns between players who run it, and CDTL3 shows them right on your lanes next to your own: yours, and those of anyone in your group who also runs it.

Please try it out! Testing in all kinds of groups (dungeons, raids, battlegrounds, with friends who run it too) is encouraged and really appreciated. Let me know what you see, good or bad, at https://github.com/Nelnamara/CooldownCollaborator/issues.

- They show up on Lane 1. To move them to another lane, bar frame or Ready frame, or turn them off, go to **Filters › Defaults › Group cooldowns**.
- To see who cast what, tick **Lanes › (a lane) › General › Caster lane**. Each caster's name shows under their icon in their class colour.
- CooldownCollaborator's settings have a box called *Show group cooldowns on CooldownTimeline3's lanes*. It's on by default when CDTL3 is loaded.
- On MoP Classic, TBC Anniversary and Classic Era, CDTL3 can read other players' raid cooldowns from the combat log on its own (**Filters › Defaults › Track raid cooldowns**). Retail and WoW: Forever hide other players' casts, so there both players need CooldownCollaborator.

## Getting started

1. Install it with the CurseForge or Wago app. The folder has to be named `CooldownTimeline3`.
2. Restart the game all the way. A brand new addon isn't picked up by `/reload`.
3. Take the short tour on your first login, or type `/cdtl3` to open the settings.
4. Go play. Cooldowns, items and buffs show up on the lane as you use them. The Simple tab has the basics, and Quick Style has the Healer, Tank and DPS setups.
5. Drag the frames where you like them, then type `/cdtl3 lock`.

## Commands

- `/cdtl3` opens the settings. The Help tab lists every command with a Run button
- `/cdtl3 lanes`, `ready`, `bars`, `filters` or `profiles` jumps straight to that tab
- `/cdtl3 lock` and `/cdtl3 unlock` lock or unlock the frames so you can move them
- `/cdtl3 test` fills the frames with sample icons
- `/cdtl3 minimap` shows or hides the minimap button
- `/cdtl3 combattimers` tells you if combat timers are running, and `on` or `off` switches them (Retail and WoW: Forever)
- `/cdtl3 auras` shows your buffs and debuffs the way CDTL3 sees them. Handy if a buff won't show up
- `/cdtl3 report` makes a bug report you can copy, `/cdtl3 log` shows errors that happened quietly, and `/cdtl3 perf` shows CPU and memory
- `/cdtl3 help` lists every command in chat

## Bugs and requests

Found a bug or want something added? Open an issue on GitHub: https://github.com/Nelnamara/cdtl3-dev/issues. Type `/cdtl3 report` in game and paste what it gives you into the issue, it helps a ton. There's no Discord, GitHub is the place.

## Changelog

### 3.2.0

**Getting started**
- A three-step tour the first time you install it. It shows you the lane, the bars and the Ready frame with sample icons, then lets you lock everything in place or open the settings
- The Simple tab comes first: what to track, timeline width, icon size, the ready sound and a lock button
- Setups by role (Quick Style › Setup). Starter, Healer, Tank or DPS shows up on your own frames with sample icons first. Keep saves it, Undo puts your lanes back, and a setup you never kept gets undone the next time you log in
- Your own looks. Save the current look as a card, put it on everything or on one lane, bar frame or Ready frame, and share it as a string
- Help. The minimap tooltip shows if your frames are locked and if combat timers are on, and Alt-click opens a Help tab with every command
- An optional ~ in front of estimated times (Retail and WoW: Forever, Global › Mark estimated times with ~, off by default), so you can tell a time CDTL3 counts itself from one that follows the game's own timer

**Lanes and icons** (all of these are off until you turn them on, under Lanes › (a lane) › Effects or per spell in Filters)
- Charge pips on spells with charges. The icon rides the recharge until every charge is back
- Buff alerts. The lane flashes when a buff lands or drops, with a sound (in combat on Retail and WoW: Forever, this works for buffs in the Cooldown Manager's Tracked Bars)
- A burst window shaded on the lane, with an optional Ready-by list of the cooldowns that will be back for it (with ticks on Classic clients; on Retail and WoW: Forever the list shows the timers)
- A refresh zone for DoTs on Classic Era, TBC and MoP, a pulse before a cooldown comes back (Filters › Warn before ready), and GCD waits that sit in the Ready frame so they don't look like a real cooldown
- A mana gauge at the Ready end of a lane, a lane bar that changes colour at a resource number when the lane tracks Class Power or Stagger (not in combat on Retail or WoW: Forever), and Brewmaster Stagger tracking

**Boards and groups**
- A Ready frame that keeps every cooldown you pin. Tick Pinned on a spell in Filters, then set the Ready frame's Mode to Stay until used. It's lit up when ready and dimmed with the time left while it cools
- A Fight Timeline (its own tab, off until you tick Enabled). It's a strip from the pull with a line for now and flags you can move (2, 3 and 5 minutes to start), showing where each pinned cooldown will be. On Retail and WoW: Forever the end times are estimates, marked with a ~
- A Caster lane for other players' cooldowns, with each caster's name under their icon. It's fed by the combat log on MoP, TBC and Classic Era, and by CooldownCollaborator on every client (on Retail and WoW: Forever the other player needs it too, since the game hides their casts)
- Group cooldowns from CooldownCollaborator show on your lanes: yours, and those of anyone in your group who runs it. They land on Lane 1, and Filters › Defaults › Group cooldowns moves them to another lane, bar frame and Ready frame, or turns them off. On MoP, TBC and Classic Era, CDTL3's own combat log raid cooldowns step aside while CooldownCollaborator is feeding them, so nothing shows twice
- Externals you gave (Filters › Spells › Show effect on target). A strip on your cooldown icon shows who you put it on and how long it has left. Exact on Classic clients, an estimate from your cast on Retail and WoW: Forever
- Burst pack (Filters › Defaults) sets up lust and Sated where your client has them, plus your trinkets and potion, on a Burst lane, with an optional Burst strip

**Filters**
- Filters tell you why a spell or buff isn't showing. Pick an entry and a line says what's hiding it (over the Ignore Threshold, longer than the lane's Max Time, its lane is switched off, and so on) with a Show anyway button. The first time a long cooldown gets ignored on its own, you get one line in chat about it
- My spells. Filters › Spells lists your spellbook's cooldowns with tick boxes, so you can pick spells before you've ever cast them, plus Show only the ticked spells
- Hide spells I don't know and Only for this spec. Spells you've talented out of leave the lane, and a spell can be kept to one spec (Retail and MoP)
- Pull from Cooldown Manager (Retail and WoW: Forever). One button in Filters › Buffs sets up every buff in the Cooldown Manager's Tracked Bars

**Sounds and showing**
- A ready sound per spell. Each one can have its own sound, flash when it's ready, and say its name out loud where the game has text to speech (in the voice you picked in the game's text to speech settings, or the first voice installed). The Ready tab gets Mute ready sounds
- You hear a sound as you pick it. Every sound menu plays your choice once, the menus are twice as wide so you can read the long names, and a Play sound button next to each one plays it again
- Blizzard sounds. A handful of the game's own alerts and chimes (raid warning, quest complete, level up, alarm clocks, bells and more) in a Blizzard sound menu right under every sound menu. Each one is checked to exist on every client
- Show per lane, bar frame and Ready frame: Always, Only in combat or Boss fights only, with Dim instead of hide. The default follows the Global tab's Hide out of combat, same as before
- Preview with sample icons. A button at the top of the Global tab (or Shift-click the minimap button) shows sample icons until you hit Stop preview
- Placing frames. Until your first lock, the "Frames unlocked" box tells you to drag the frames and then click Lock (and that Edit Mode can place them too). Your first flight tells you the countdown is CDTL3's and where to turn it off

**Placing and profiles**
- Anchor to. A lane, bar frame or Ready frame can follow the player frame, the Cooldown Manager or any frame by name, with an offset. Only CDTL3's own frames ever move
- Share my Custom timers and spell settings with all my characters (Profiles tab, off by default), New characters start on (the Default profile, the last one you used, or one you pick), and Profiles by zone (raids, dungeons, PvP, open world)

**Sharing**
- Share strings with a preview. An import tells you what's in it first ("3 lanes, 41 spells, made on 3.1.1 Retail"), warns you about spells your client doesn't have, and can go into a new profile. Imported spells show up in your Filters right away. Each lane has Copy this lane. Older strings still import
- Masque gets a group for each timer type (spells, items, buffs and so on) and keeps your current skin
- A missing font, bar texture or sound shows "(missing)" in its menu and uses CDTL3's own instead of going silent

**For bug reports and other addons**
- `/cdtl3 report` opens a bug report ready to copy, `/cdtl3 log` shows what failed quietly, `/cdtl3 perf` shows memory and frame counts, and `/cdtl3 help` lists every command
- Update rate (Global tab) and Pause while hidden (per lane) for slower machines. Timers and Ready stay on time either way
- Other addons can listen for a timer starting, coming ready and ending, read what's tracked, and add their own timers to the lanes. See [Extending CDTL3](https://github.com/Nelnamara/cdtl3-dev/blob/main/docs/EXTENDING.md)

**Fixes**
- Setup previews always show sample icons sized to the setup you picked, every time you pick one, and they keep going until you Keep or Undo. The preview's split marks fit inside its lanes too
- A lane no longer draws a split mark past its Max Time
- Importing a "Settings only" string as "All settings and data" no longer empties your Filters lists, and a damaged string gets refused before it can change anything
- Clearing a spell's settings, Reset Profile and Copy From now ask first when other characters on the profile use them, instead of quietly wiping them
- Cooldowns on a switched-off lane no longer lose their bar for the last 2 minutes
- An early reset (Cold Snap, Preparation, Readiness) now shows the Ready icon along with the sound, and a switched-off Ready frame doesn't play one
- Ready › Highlight Duration and Pinned Hide Time now do what they say
- The "Frames unlocked" box follows the lock when you switch profiles, and its Lock button always locks
- Custom › Add New: Enabled can be unticked, and a mistyped Trigger ID gets refused (Retail and WoW: Forever)
- In combat on Retail and WoW: Forever, the GCD marker shows, a Tracked Bars buff no longer jumps to Ready after Alt+Z, and a new trinket or potion no longer shows a frozen 16:40 bar
- Lanes: Secondary Tracking shows as soon as you turn it on, the secondary marker on vertical lanes moves along the lane, lane texts with live tags update, Override Autohide brings back an empty lane, every lane and bar frame comes back at the pull with Hide out of combat, and Split Count takes whole numbers
- Edit Mode sliders reach the same sizes as the options window. Lane width now goes to 1000 and bar width to 600 in both
- Grouped stacking does a lot less work and looks the same, and a lone icon in a short stack stays in the lane
- TBC Anniversary: flights that don't start from the flight map no longer count down under internal names
- Undo on a setup preview puts a buff you gained, or a spell you cast, during the preview back on its own lane, instead of leaving it on the preview's lane until a reload
- Bar frames: the little transition line stays inside its bar and only shows on a bar that will hand off to its lane. It used to sit way out to the right, over other frames, when the lane held more time than the whole cooldown
- Test mode no longer lists test cooldowns twice
- WoW: Forever: Haunt is gone from the built-in Warlock list, since Blizzard removed it from the class
- Classic clients read buffs and the combat log through Blizzard's current names, ahead of the old ones going away

### Older versions

The full history, all the way back to Vreenak's original, is in the changelog on GitHub: https://github.com/Nelnamara/cdtl3-dev/blob/main/CHANGELOG.md

## Credits

- Original addon: Vreenak (US-Remulos)
- V2 rewrite: cliffclive
- Midnight patch and CDTL3: Nelnamara
