-- UI\Changelog.lua
-- Changelog data + a reusable renderer used by the Changelog settings page.
-- To add notes for a future version, add an entry to CHANGELOG below.

local addonName, adpm = ...

-- ─── Changelog data ───────────────────────────────────────────────────────────
-- Add newest entry at the TOP. Each entry: { version, lines[] }
local CHANGELOG = {
    {
        version = "1.0.8",
        lines = {
            { text = "Restock tracking",                                                       tag = "new" },
            { text = "Set Min/Max stock targets for your currently selected Flask and Potion on the main settings page.", tag = nil },
            { text = "Restock trigger mode",                                                    tag = "new" },
            { text = "Choose whether you're warned below Min (only when critically low) or below Max (any time you're not fully stocked).", tag = nil },
            { text = "Dungeon/raid low-stock warning",                                          tag = "new" },
            { text = "Get a popup entering a dungeon or raid if you're below your threshold. Can be turned off separately from restock tracking itself.", tag = nil },
            { text = "Auction House shopping panel",                                            tag = "new" },
            { text = "A draggable panel appears at the AH for whatever's low, with live prices and a real Buy button per item (this spends gold, so double-check the quantity shown before clicking).", tag = nil },
            { text = "Readability",                                                              tag = "fix" },
            { text = "Lightened the muted gray text used throughout Settings, which was hard to read against the dark background.", tag = nil },
        },
    },
    {
        version = "1.0.7",
        lines = {
            { text = "New potions: Liquid Luster and Alluring Nostrum",                       tag = "new" },
            { text = "Both are now selectable on the Potion page, with crafted, Silver, Gold, and Fleeting tiers where available.", tag = nil  },
            { text = "Nested settings tree",                                                  tag = "new" },
            { text = "Options are now split into Flask, Potion, and Changelog pages under Auto DPS Pot Macro.", tag = nil  },
            { text = "Changelog page",                                                        tag = "new" },
            { text = "Added a Changelog page to Settings so you can see what's new without a separate popup.", tag = nil  },
            { text = "Interface update",                                                      tag = "upkeep"  },
            { text = "Added support for patch 12.1.0 (interface 120100).",                    tag = nil  },
            { text = "Spec profile sync",                                                     tag = "fix" },
            { text = "Flask/Potion selections could show a stale choice after zoning or a loading screen, even though the correct macros were still active behind the scenes.", tag = nil },
            { text = "Selections now resync whenever your active spec is (re)detected, not just on an explicit spec change.", tag = nil },
            { text = "Changelog display",                                                     tag = "fix" },
            { text = "Divider lines no longer overlap wrapped text, and now appear consistently between every version entry.", tag = nil },
            { text = "Settings layout",                                                       tag = "changed" },
            { text = "Options (chat notifications, minimap toggle) now live on the main page instead of their own separate tab.", tag = nil },
        },
    },
    {
        version = "1.0.6",
        lines = {
            { text = "Updated TOC for patch 12.0.7 — Midnight: Revelations. No functional changes.", tag = "upkeep" },
        },
    },
    {
        version = "1.0.5",
        lines = {
            { text = "Per-specialization profiles",                                          tag = "new" },
            { text = "Flask and potion selections now save separately for each spec.",       tag = nil  },
            { text = "Swapping specs automatically switches your macros.",                   tag = nil  },
            { text = "Fix: Minimap toggle slash command now works correctly.",               tag = "fix" },
        },
    },
    {
        version = "1.0.4",
        lines = {
            { text = "Combat-safe fallback macros",                                          tag = "new" },
            { text = "Macros now include all owned quality tiers as fallbacks.",             tag = nil  },
            { text = "If you run out of Gold pots mid-pull, Silver kicks in automatically.", tag = nil  },
        },
    },
    {
        version = "1.0.3",
        lines = {
            { text = "Dynamic Macro Icons",                                                                          tag = "fix" },
            { text = "Changed #showtooltip item:ID to bare #showtooltip so the macro icon and tooltip update dynamically as you consume items mid-combat.", tag = nil },
            { text = "Previously the icon locked to the first item ID and greyed out when depleted, even though the fallback /use lines still worked.", tag = nil },
        },
    },
    {
        version = "1.0.2",
        lines = {
            { text = "Combat-Safe Fallback Macros",                                                                  tag = "new" },
            { text = "Macros now include all owned quality variants as fallback /use lines.",                        tag = nil  },
            { text = "If you run out of Fleeting potions mid-fight, the macro automatically falls back to Crafted versions without needing a mid-combat update.", tag = nil },
        },
    },
    {
        version = "1.0.1",
        lines = {
            { text = "Character-Specific Storage",                                                                   tag = "fix" },
            { text = "All settings (selected flask/potion, minimap position, chat notifications) now save per-character instead of account-wide.", tag = nil },
            { text = "This lets different characters keep different consumable preferences without conflicts.",      tag = nil },
        },
    },
    {
        version = "1.0.0",
        lines = {
            { text = "Initial Release",                                                                              tag = "new" },
            { text = "Support for all 4 flask types (Blood Knights, Shattered Sun, Magisters, Thalassian Resistance).", tag = nil },
            { text = "Support for all 5 combat potion types (Recklessness, Draught, Light's Potential, Zealotry, Mana).", tag = nil },
            { text = "Smart quality priority: Fleeting Gold > Fleeting Silver > Crafted Gold > Crafted Silver.",      tag = nil },
            { text = "Automatic macro creation and updates (ADPMFlask, ADPMPot).",                                    tag = nil },
            { text = "Modern Settings panel with scrollable interface.",                                              tag = nil },
            { text = "Minimap button with LibDBIcon integration.",                                                    tag = nil },
            { text = "Key binding support for quick usage.",                                                          tag = nil },
            { text = "Combat-aware throttling (0.5s delay, combat lockdown).",                                        tag = nil },
            { text = "Real-time status display showing active item quality and counts.",                             tag = nil },
            { text = "Migration support for minimap position data.",                                                  tag = nil },
        },
    },
}

-- ─── Colours ──────────────────────────────────────────────────────────────────
local C_VERSION = "ffcc00"
local C_NEW     = "44ff88"
local C_FIX     = "ff9944"
local C_CHANGED = "66aaff"
local C_REMOVED = "ff5555"
local C_UPKEEP  = "cc88ff"
local C_BODY    = "dddddd"

local function col(hex, t) return "|cff"..hex..t.."|r" end

-- ─── Reusable list builder ─────────────────────────────────────────────────────
--- Populates `content` (any Frame) with the full changelog, word-wrapped to `width`.
--- Used by the Changelog settings subcategory.
--- @return number totalHeight The height content should be set to.
function adpm.BuildChangelogList(content, width)
    local y = -4
    for i, entry in ipairs(CHANGELOG) do
        -- Version header
        local vfs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        vfs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        vfs:SetText(col(C_VERSION, "Version " .. entry.version))
        y = y - 24

        for _, line in ipairs(entry.lines) do
            local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetWidth(width - 8)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)

            local prefix = ""
            if line.tag == "new" then
                prefix = col(C_NEW,     "[New] ")
            elseif line.tag == "fix" then
                prefix = col(C_FIX,     "[Fix] ")
            elseif line.tag == "changed" then
                prefix = col(C_CHANGED, "[Changed] ")
            elseif line.tag == "removed" then
                prefix = col(C_REMOVED, "[Removed] ")
            elseif line.tag == "upkeep" then
                prefix = col(C_UPKEEP,  "[Upkeep] ")
            end

            fs:SetText(prefix .. col(C_BODY, line.text))
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", line.tag and 0 or 12, y)

            -- measure height after setting text+width
            fs:SetSpacing(2)
            y = y - fs:GetStringHeight() - 20
        end

        -- Divider between versions
        y = y - 8
        local div = content:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(0.4, 0.35, 0.1, 0.6)   -- subtle gold rule
        div:SetSize(width, 1)
        div:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        y = y - 20
    end

    local totalHeight = math.abs(y) + 16
    content:SetHeight(totalHeight)
    return totalHeight
end
