# Blizzard sound shortlist (to vet by ear)

These are registered with LibSharedMedia in `Media.lua` as "Blizzard: <name>". Pick any of them in a
sound dropdown (Ready frame sounds, a spell's Own Ready Sound, buff alert sounds, the Simple tab) and
it plays once, so you can hear it. Keep the ones you like; the rest come out.

How each was confirmed: its file data ID is in the `SoundKitEntry` table of all five builds in
`tools/spell-list-check/builds.json` (Era 1.15.9.70576, Forever 1.60.1.70888, TBC 2.5.6.70577, MoP
5.5.4.70631, Retail 12.1.5.70783; tables from wago.tools), and its path comes from the wowdev community
listfile (github.com/wowdev/wow-listfile). `node tools/spell-list-check/sounds.js <listfile.csv> ids:<id,id>`
repeats the check. The SoundKit column is a SoundKit that holds the file in all five clients.

Left out: Ready Check (file 567409, SoundKit 8960) is in the Era and Forever tables only. Nothing here
was heard by the person who wrote the list; whether each is short and clear is for your ear.

| Name | File ID | Path | SoundKit |
|---|---|---|---|
| Blizzard: Raid Warning | 567397 | sound/interface/raidwarning.ogg | 8959 |
| Blizzard: PvP Warning | 567488 | sound/interface/pvpwarning.ogg | 4574 |
| Blizzard: Quest Complete | 567439 | sound/interface/iquestcomplete.ogg | 878 |
| Blizzard: Quest Accepted | 567400 | sound/interface/iquestactivate.ogg | 618 |
| Blizzard: Quest Progress | 567516 | sound/interface/iquestupdate.ogg | 3201 |
| Blizzard: Level Up | 569593 | sound/spells/levelup.ogg | 124 |
| Blizzard: Reputation Rank Up | 568016 | sound/spells/reputationlevelup.ogg | 8473 |
| Blizzard: Queue Joined | 568587 | sound/spells/pvpenterqueue.ogg | 8458 |
| Blizzard: Queue Pop | 568011 | sound/spells/pvpthroughqueue.ogg | 8459 |
| Blizzard: Alarm Clock 1 | 567436 | sound/interface/alarmclockwarning1.ogg | 18871 |
| Blizzard: Alarm Clock 2 | 567399 | sound/interface/alarmclockwarning2.ogg | 12867 |
| Blizzard: Alarm Clock 3 | 567458 | sound/interface/alarmclockwarning3.ogg | 12889 |
| Blizzard: Text Ping | 567484 | sound/interface/igtextpopupping02.ogg | 7355 |
| Blizzard: Whisper | 567421 | sound/interface/itellmessage.ogg | 3081 |
| Blizzard: Group Invite | 567451 | sound/interface/iplayerinvitea.ogg | 880 |
| Blizzard: Map Ping | 567416 | sound/interface/mapping.ogg | 3175 |
| Blizzard: Friend Online | 567518 | sound/interface/friendjoin.ogg | 3332 |
| Blizzard: Battle.net Toast | 567402 | sound/interface/ui_bnettoast.ogg | 18019 |
| Blizzard: Store Toast | 915759 | sound/interface/ui_blizzardstore_toast.ogg | 39517 |
| Blizzard: Flight Point Discovered | 567497 | sound/interface/ignewtaxinodediscovered.ogg | 1519 |
| Blizzard: Coin | 567428 | sound/interface/lootcoinsmall.ogg | 120 |
| Blizzard: Night Elf Bell | 566558 | sound/doodad/belltollnightelf.ogg | 6674 |
| Blizzard: Shay's Bell | 568154 | sound/spells/shaysbell.ogg | 6555 |
| Blizzard: Holy Cast | 569763 | sound/spells/cast/holycast.ogg | 2562 |
| Blizzard: Sparkle Chime | 5259954 | sound/spells/10.1.5_magic_general_sweetener_chimes_shimmer_sparkle_short_01.ogg | 306222 |
| Blizzard: Gold Cast | 6226466 | sound/spells/gold/11.1_magic_gold_cast_large_01.ogg | 306221 |
| Blizzard: Trading Post Celebration | 4906957 | sound/interface/trading_post/ui_tradingpost_purchasecelebration_01.ogg | 303831 |
| Blizzard: Trading Post Coins | 4910746 | sound/interface/trading_post/ui_tradingpost_collectingcoins_01.ogg | 306216 |
