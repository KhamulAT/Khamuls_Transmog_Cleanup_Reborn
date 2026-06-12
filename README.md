# Khamul's Transmog Cleanup Reborn

A World of Warcraft addon to mass-sell items (mostly transmog) at vendors.

When you open a merchant window, a companion frame opens next to it listing the sellable
items in your bags. Filter by quality, bind type, transmog status, and item category,
set a maximum item level, ignore individual items, and sell the rest with one click —
optionally limited to 12 items per click so everything stays recoverable via buyback.

## Features

- Opens/closes automatically with the merchant window, attached to its right side
- Filter columns:
  - **Quality**: Poor, Common, Uncommon, Rare, Epic, Legendary
  - **Binding**: BoE, BoP, BoA, Warbound, On Use
  - **Transmog status** (MoP Classic only): learned / can't be learned / learnable
    by another character
  - **Excludes**: skip items from recent expansions (Midnight, The War Within,
    Dragonflight — retail only) and class set tokens
  - **Categories**: non-transmog equipment, consumables, trade goods, junk & other
  - **Selling**: safeguard sale, "don't sell above auction profit" with gold
    threshold, verbose chat output (per-item sale lines instead of just a summary)
- Max item level slider (inclusive cap; up to 298 on retail, 582 on MoP Classic)
- Retail learns transmogs when items are sold (regardless of class), so unlearned
  items are listed with a "will be learned on sale" status; on MoP Classic, items
  whose appearance **you can still learn are never listed or sold**
- Item list shows a will-sell/won't-sell icon, item level, status (including why an
  item is skipped, e.g. above threshold), vendor price, and auction price per row
- Per-item ignore list (ignored items sink to the bottom) and all filter settings
  stored account-wide; vendor total of the pending sale shown at the bottom
- Safeguard sale: sells at most 12 items per click (fits in the 12 buyback slots),
  cheapest items first
- Optional auction price column and threshold protection via
  [Auctionator](https://www.curseforge.com/wow/addons/auctionator) or
  [TradeSkillMaster](https://www.tradeskillmaster.com/) (configured in the addon options)
- Transmog status via [CanIMogIt](https://www.curseforge.com/wow/addons/can-i-mog-it)
  (required on retail; MoP Classic falls back to the native API)
- Localized: deDE, enUS, esES, frFR, itIT, koKR, ptBR, ruRU, zhCN

## Supported clients

- Retail (`Khamuls_Transmog_Cleanup_Reborn.toc`, Interface 120005)
- Mists of Pandaria Classic (`Khamuls_Transmog_Cleanup_Reborn_Mists.toc`, Interface 50504)

## Usage

The frame opens automatically at any merchant. `/ktc` toggles it manually (selling is
only possible while a merchant window is open).

## Development / deployment

Copy `bin\.env.sample` to `bin\.env`, adjust `WoWRootFolder` and `WoWClientsFolder`,
then run `bin\publish2wowdir.ps1` to sync the repository into the WoW AddOns folders.

`bin\release.ps1` builds a release zip (`Release_Archive\<VERSION>.zip`) containing
only the files required at runtime; pass `-RetailOnly` to omit the Mists TOC.

The addons under `Referenced_Extensions\` are only used as API references during
development; they are never deployed or bundled.

## License

MIT — see [LICENSE](LICENSE).
