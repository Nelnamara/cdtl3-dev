# CooldownTimeline 3

## v3.0.8

**New**
- **Edit Mode support** (LibEditMode) — lanes, bar frames and ready frames appear in Edit Mode with quick size sliders and a shortcut to their full settings; positions are saved per Edit Mode layout and follow layout switches. Classic Era keeps `/cdtl3 unlock`
- **Quick Style** — one-click looks for every lane, bar frame and ready frame: CDTL3 Classic, Minimal, Blizzard Modern, Class Colours. Minimal and Modern also make icon highlighting visible (the shipped highlight border is "None")
- **Copy settings** — each lane, bar frame and ready frame can copy every setting from another (name, position and enabled state are kept)
- **Per-spell bar colors** — Filters → any entry → *Own Bar Color*; wins over school, class and frame colors
- **Spell School Color actually works** — schools were never recorded and had no pickers, so every bar was grey. They're now learned from your casts (combat log) with a picker per school under Colors; hidden where the combat log is closed
- **Modern Blizzard bar textures** — unit-frame health/power bars (including grey, tintable versions) and cast bars, offered only where the client has them
- **Per-spec profiles** (LibDualSpec) — Profiles → *Enable spec profiles*

**Audit and restructure** — the code was audited end to end (it has passed through three maintainers) and the duplicated parts consolidated:
- Import now really applies (it replaced the profile table AceDB doesn't save) and validates the string before touching anything
- Filters fixes: Set All, Clear Individual Settings and Save Custom; items matched by item name; time inputs validated; Ignore Threshold applied once
- Power text tags work for every class; "highlighted" tags read the right setting; class color pickers update live; lanes 2/3 got the time-format default lane 1 had
- Every newly discovered spell, item, buff, rune and custom is built by one set of helpers (13 copies had drifted apart — e.g. the Ignore Threshold was inclusive in some and not others)
- Lanes, bar frames and ready frames are each declared once in the defaults (about 1,150 duplicated lines removed); border options are generated from one function
- Unit events are registered for you and your pet only, so raids no longer wake the addon for every member
- Options that depend on the combat log (enemy debuffs, melee swing, school colors) say so or hide where it's closed
- Dead code removed throughout

**WoW: Forever and compatibility**
- **World of Warcraft: Forever support** — Forever reports a vanilla-era interface number (`16001`) but runs the modern Midnight-era API, so the old version check sent it down the Classic code paths and called functions Forever doesn't have (`GetSpellInfo`, `GetSpellCooldown`, `UnitAura`, the old spellbook API). CDTL3 now detects Forever by its interface number and uses the retail API paths while keeping the vanilla-era spell data. Ships a `_Camelot` TOC (the Forever client doesn't fall back to `_Mainline`) plus a plain `CooldownTimeline3.toc` fallback
- **Combat log registration can't break detection** — it's only registered where the client provides it, and a refusal no longer aborts registering the other cooldown events. The combat log is closed to addons on Forever
- **Updated the bundled Ace3 libraries to r1403** — the old copy called globals newer clients removed (`SetDesaturation`) and passed a boolean as tooltip alpha, which errored in the options window on Forever and will on WoW 12.1.5
- **Item/spellbook lookups ready for 12.1.5** — `GetItemSpell`/`GetItemInfoInstant` (removed in 12.1.5) and `IsSpellKnown`/`IsSpellKnownOrOverridesKnown` (deprecation-only since 11.2) now go through wrappers that use `C_Item`/`C_SpellBook` when the old globals are gone; the action-button glow highlight falls back to the border highlight where the glow API is missing
- **Buff/debuff detection without the combat log** — buffs and debuffs on you (and custom aura triggers) were only discovered through the combat log, which Forever closes to addons, so e.g. Mark of the Wild never appeared under Buffs. They're now also picked up from `UNIT_AURA`: newly added auras, recasts of a buff you already have (an aura *update*), and buffs already on you at login, `/reload` or zoning (a *full* update). Auras that are secret (in combat, encounters, M+, PvP) are skipped. Debuffs you apply to enemies and the swing timer still need the combat log
- **Secret-value hardening for lanes, items and auras** — on Forever (and Midnight while restricted) player health/power, attack speed, item cooldowns and even the `UNIT_AURA` payload can be secret. Lane HEALTH / CLASS_POWER / COMBO_POINTS tracking now feeds secret values straight to the status bar (which accepts them) instead of dividing them; swing timers show a full bar, the mana/energy tick estimate pauses, item cooldowns keep counting down from their last readable value, and text tags show `?` when a value is secret
- **Fixed detected buffs/debuffs missing from the Filters list** — a buff seen at login, before the character was known, was saved without an owner and never listed for anyone (Mark of the Wild showed `yours=false` in `/cdtl3 auras`). Saved entries are now claimed for your character whenever the aura is seen again, and the login scan waits until the character is known
- **Fixed the debug frame's Options button** — it still used `Settings.OpenToCategory("CDTL3")`, which errors on Midnight and Forever; it now opens the CDTL3 window like `/cdtl3`
- **New `/cdtl3 auras`** — prints every buff/debuff on you as CDTL3 sees it (or that it's hidden/secret), whether it's saved, ignored and assigned to you, plus whether aura events are arriving — for troubleshooting buff detection
- **Fixed an options error in Filters** — with `<< Select >>` (no entry) chosen in a Filters list, the Custom CD Time fields looked up settings that don't exist and errored (`Options.lua: attempt to index local 's'`); they now stay hidden until a real entry is selected
- **Fixed buffs/debuffs recording spell ID 0 on Classic clients** — a typo in the Classic aura reader dropped the spell ID
- TOCs bumped: MoP Classic `50504`, TBC Anniversary `20506`, Classic Era `11509`
