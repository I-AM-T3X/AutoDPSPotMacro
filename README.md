# Auto DPS Pot Macro

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![WoW](https://img.shields.io/badge/WoW-The%20Midnight-9cf.svg)](https://worldofwarcraft.com)

Never manually update your potion macros again. This World of Warcraft addon automatically creates and maintains optimal flask and combat potion macros based on what's actually in your bags, with intelligent priority for quality tiers and fleeting variants.

## Features

- **Smart Macro Management** — Creates two macros (`ADPMFlask` and `ADPMPot`) that automatically update to use your best available consumables
- **Intelligent Quality Priority** — Automatically selects:  
  **Fleeting Gold → Fleeting Silver → Crafted Gold → Crafted Silver**
- **Fleeting Support** — Fully supports fleeting variants from Alchemy cauldrons (Cauldron of Sin'dorei Flasks & Voidlight Potion Cauldron)
- **Combat-Aware Updates** — Queues updates during combat, applies immediately when safe (no taint errors)
- **Throttled Processing** — 0.5s delay on bag changes prevents spam during mass looting
- **Modern Settings UI** — Native integration with WoW's Settings API (not legacy Interface Options)
- **Live Status Tracking** — See current item quality (Fleeting vs Crafted, Gold vs Silver) and bag counts in real-time

## Supported Consumables

### Flasks (1-hour duration)
| Flask | Stat |
|-------|------|
| Flask of the Blood Knights | Haste |
| Flask of the Shattered Sun | Critical Strike |
| Flask of the Magisters | Mastery |
| Flask of Thalassian Resistance | Versatility |

### Combat Potions (30-second duration)
| Potion | Effect |
|--------|--------|
| **Potion of Recklessness** | Best general DPS — trades lowest secondary for highest |
| **Draught of Rampant Abandon** | Primary stat + occasional void zone spawn |
| **Light's Potential** | Primary stat (safe, no downside) |
| **Potion of Zealotry** | Stacking single-target holy damage |
| **Lightfused Mana Potion** | Mana restoration for healers |

## Installation

1. Download the latest release from [Releases](../../releases)
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Ensure the folder is named `AutoDPSPotMacro` (not `AutoDPSPotMacro-main`)
4. Restart WoW or reload UI

## Usage

1. Open the options panel via minimap button or type `/adpm`
2. Select your preferred flask and potion types from the dropdowns
3. Drag the created macros (`ADPMFlask` and `ADPMPot`) to your action bars
4. The macros update automatically as you acquire better qualities or run out of consumables

## Slash Commands


/adpm              Open options panel
/adpm status       Show current macro status and inventory counts
/adpm update       Force immediate macro refresh
/adpm minimap      Toggle minimap button visibility
/adpm help         List all commands


## Technical Details

- **Item Link Parsing** — Uses precise item link scanning to distinguish Silver vs Gold qualities (which share base item IDs in Midnight's crafting system)
- **Combat Lockdown** — Defers all macro edits until out of combat to prevent "Interface action failed" errors
- **LibDBIcon Support** — Optional minimap button with drag positioning (falls back to native button if libraries unavailable)
- **Lightweight** — Only processes bag updates when necessary; throttled to prevent performance impact


## Dependencies

- **Included:** LibDBIcon-1.0 and LibDataBroker-1.1 (for enhanced minimap button functionality)

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE) - see the LICENSE file for details.

---

*Developed for World of Warcraft: The Midnight (12.x)*
