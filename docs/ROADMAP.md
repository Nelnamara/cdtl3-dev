# CDTL3 roadmap

Work that is planned or built but waits on something. Not packaged (`docs/` is in `.pkgmeta`'s ignore list).

## Trinkets and use items

Waits for: a Forever character with an on-use trinket. Retail only if and when the owner feels like testing there.

All the walk lines below stay on the walk sheet, marked Later until they can be done.

### Testable on Forever now (a potion or healthstone is enough)
- **Test build 2, "a trinket or potion you've never used with CDTL3"**: the red team fix for the frozen 16:40 bar. Use a potion or healthstone in combat that CDTL3 has never seen: no frozen bar, and it shows once combat ends.
- **Probe walk, Forever lines**: run with a potion on 13 Nov 2026 (results below). Needs the probe build (`dist/CooldownTimeline3-3.1.1-probe-items-boss.zip`, branch `probe-items-boss`, never released); put review-2 back afterwards.

### When the character has an on-use trinket
- **Probe walk again, with the trinket on a bar**: the same Forever lines, so the report covers a trinket as well as a potion.
- **Test build 2, Burst pack** (Filters › Defaults › Burst pack): the Burst lane picks up both trinkets and the potion, and the Burst strip's trinket slots fill.

### Retail (only if he chooses to)
- **Probe walk, Retail lines**: trinket and potion on a bar, any mob or a dummy, one Midnight dungeon boss for the boss timeline row.

### Trinkets and potions exact in combat (feature panel card 20)
**Probe result, Forever, 13 Nov 2026** (`docs/probe-results/2026-11-13-forever-druid-items.txt`, level 17 Druid, Minor Rejuvenation Potion used in combat):
- Potions need nothing new on Forever. The item cooldown calls stay readable in combat: `C_Container.GetItemCooldown` (what `CDTL3:GetItemCooldown` in Helpers.lua already uses), `C_Item.GetItemCooldown`, `C_Container.GetContainerItemCooldown` and `C_Spell.GetItemCooldown`. Every read was on cooldown from the use until ready at exactly 120 s, with none hidden.
- Only the spell and action bar routes hide their numbers in combat (`C_Spell.GetSpellCooldown`, `C_ActionBar.GetActionCooldown`, timer objects). Their `isActive` stays readable. So the action bar route isn't needed on Forever.
- Still open: **trinkets**. CDTL3 reads equipped trinkets through `GetInventoryItemCooldown("player", slot)`, which the probe didn't call. If it turns out hidden in combat, `C_Item.GetItemCooldown(itemID)`, readable here for the potion, is the switch. Check by running the probe again once the character has an on-use trinket.
- Retail is unknown until someone runs the probe there.

### Boss timing (feature panel card 6)
**Probe result, Forever, 13 Nov 2026:** Forever has no boss timeline (`C_EncounterTimeline.IsFeatureAvailable()` false, Blizzard_EncounterTimeline not loaded). Boss markers on Forever would have to come from DBM or BigWigs messages, as on Classic. Retail is unknown until someone fights a Midnight boss with the probe running.
