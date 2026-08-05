# SmartBiS

**Best-in-slot gear + enchants, in-game, for Conquest of Azeroth (CoA / Ascension 3.3.5a).**

SmartBiS brings [Bisbeard](https://coa.bisbeard.com)'s gear optimizer *inside the
game*. It runs Bisbeard's own solver offline against the CoA item database and
bakes the results into the addon, so you get the exact same optimized loadout —
per class, spec, and content phase — without alt-tabbing to the website.

> Bisbeard is the source of truth. SmartBiS just carries that information into
> your client. Built with the Bisbeard author's permission.

## Features

- **Exact Bisbeard loadouts** — the real solver output, for all 21 classes / 70
  specs, across every database phase (Pre-Raid → Phase 5) and PvE / PvP.
- **Auto-detects your class & spec** — `/sbis` opens straight to your character.
- **Recommended enchant per slot** — also from Bisbeard's solver.
- **"Where it drops"** — the source of every item, right under it.
- **Have / need check** — `v` = equipped, `b` = in your bags, `-` = missing,
  with an `Equipped X/Y` counter.
- **Tooltip anywhere** — hover any item (drop, bag, chat link, AH) and it tells
  you if it's BiS for your spec, and in which phases.
- **Minimap button** + `/sbis` slash command.

## Install

1. Download the latest release and extract it.
2. Copy the `SmartBiS` folder into
   `World of Warcraft\Interface\AddOns\`.
3. Restart the client and enable **SmartBiS** on the character screen.

## Usage

- `/sbis` — open/close, on your current spec.
- **Spec** button — cycle your class's specs (or `/sbis Felsworn|Tyrant`).
- **PvE / PvP** and **Phase** buttons — switch the database view.
- Left-click the minimap button to open; drag it to move.

## Updating the data (maintainers)

The addon data (`SmartBiS_DB.lua`) is generated from Bisbeard. Regenerate it
whenever Bisbeard updates its data or algorithm — no addon code changes needed:

```bash
node tools/build_engine.mjs   # downloads + bundles Bisbeard's solver (Node 18+)
node tools/export_bis.mjs     # runs it, writes SmartBiS_DB.lua
```

`tools/build_engine.mjs` downloads Bisbeard's current web bundle at build time
(it is **not** stored in this repo — it is their code). `tools/export_bis.mjs`
runs that solver for every class/spec/phase and emits the Lua database.

## Credits

- **[Bisbeard](https://coa.bisbeard.com)** — the gear optimizer and data behind
  every recommendation. Used with permission.
- Item data © Blizzard Entertainment.

Not affiliated with Bisbeard, Ascension, Conquest of Azeroth, or Blizzard.

## License

[MIT](LICENSE) for the addon code. See LICENSE for data/attribution notes.
