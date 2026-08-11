# SmartBiS

**Best-in-slot gear + enchants, in-game, for Conquest of Azeroth (CoA / Ascension 3.3.5a).**

SmartBiS shows the optimized best-in-slot loadout for your character — per class,
spec, and content phase — right inside the game. No more alt-tabbing to a website
to check what to gear for.

> ⚠️ **Early version.** SmartBiS is under active development — expect rough edges
> and bugs. Reports and suggestions are very welcome (see below)!

<p align="center">
  <img src="https://github.com/user-attachments/assets/244c8000-bc66-4ea5-b8f3-90322a92cbc3" alt="SmartBiS in-game" width="720">
</p>

## Features

- **⭐ Custom Stat Weights (new!)** — click **Weights** to set how much you value each
  stat, and your best-in-slot list recalculates live, right in the game. Saved per
  character; one click on **Default** brings back the standard weights.
- **Optimized loadouts** for all 21 classes / 70 specs, across every phase
  (Pre-Raid → Phase 5) and PvE / PvP.
- **🌱 Leveling mode (new, early)** — cycle the Phase button to **Leveling** to see the best
  gear for your *current character level* while you level up.
- **Auto-detects your class & spec** — `/sbis` opens straight to your character.
- **Recommended enchant per slot**.
- **"Where it drops"** — the source of every item, right on its card.
- **Have / need check** — green = equipped, gold = in your bags, **blue = you own another
  version** (almost BiS — just upgrade the tier), gray = missing, with a counter.
- **Tooltip anywhere** — hover any item (drop, bag, chat link, AH) and it tells
  you if it's BiS for your spec, and in which phases.
- **Minimap button** + `/sbis` slash command.

## Install

1. Download the latest release and extract it.
2. Copy the `SmartBiS` folder into `World of Warcraft\Interface\AddOns\`.
3. Restart the client and enable **SmartBiS** on the character screen.

## Usage

- `/sbis` — open/close, on your current spec.
- **Spec** button — cycle your class's specs (or `/sbis Felsworn|Tyrant`).
- **PvE / PvP** and **Phase** buttons — switch the view.
- **Weights** button — open the stat-weights editor. Type your values, hit **Apply** to
  recalculate, or **Default** to reset.
- Left-click the minimap button to open; drag it to move.

## Bugs & suggestions

Found a bug or have an idea? Please open an issue:
**[github.com/cccarv82/SmartBiS/issues](https://github.com/cccarv82/SmartBiS/issues)**
→ *New issue*.

When reporting a bug, it helps to include:
- Your **class and spec**, and the **PvE/PvP + phase** selected.
- What you expected vs. what happened.
- Any Lua error text, and a screenshot if you can.

## Credits

- Item list and stat weights: **[Bisbeard](https://coa.bisbeard.com/)** — used with the author's permission.

SmartBiS is a fan-made companion and is not affiliated with Bisbeard, Ascension,
Conquest of Azeroth, or Blizzard Entertainment.

## License

[MIT](LICENSE).

<!-- ============================================================
Adding a screenshot (for the maintainer):
  1. Go to github.com/cccarv82/SmartBiS/issues → "New issue" (do NOT submit it).
  2. Drag your screenshot image into the comment box. GitHub uploads it and
     inserts a line like:  ![](https://github.com/user-attachments/assets/xxxx)
  3. Copy that URL and put it in the image line near the top of this file
     (README.public.md, in the private SmartBiS-dev repo), e.g.:
        ![SmartBiS in-game](https://github.com/user-attachments/assets/xxxx)
  4. Commit + push in SmartBiS-dev → the CI republishes and the image shows on
     the public README. (Don't edit the public README directly — the CI overwrites it.)
============================================================ -->
