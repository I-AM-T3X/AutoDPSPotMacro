-- Core\MacroEngine.lua
-- Responsible for creating, updating, and icon-syncing the two macros.
-- Creates CHARACTER SPECIFIC macros with fallback chains for combat safety.

local addonName, adpm = ...

local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- ─── Internal helpers ─────────────────────────────────────────────────────────

--- Ensures a character-specific macro exists.
--- Returns the macroID (index) for use with EditMacro.
local function ensureMacro(name)
    local macroID = GetMacroInfo(name)
    if not macroID then
        -- 4th argument 'true' = character specific macro
        macroID = CreateMacro(name, ICON_FALLBACK, nil, true)
    end
    return macroID
end

--- Builds a /use macro body with fallback items.
--- WoW tries each /use line in order until one succeeds.
--- This ensures combat safety: if you run out of the best quality mid-fight,
--- the macro falls back to lower qualities without needing an update.
--- @param bestID number|nil The highest priority item ID (for #showtooltip)
--- @param fallbackIDs table Array of all owned IDs to include as fallbacks
--- @return string macroBody
local function buildMacroBody(bestID, fallbackIDs)
    local lines = {}
    
    -- Showtooltip uses the best item for icon/display
    if bestID then
        table.insert(lines, string.format("#showtooltip item:%d", bestID))
    else
        table.insert(lines, "#showtooltip")
    end
    
    -- Add all owned items as /use lines in priority order
    -- WoW will try each until one succeeds (has charges/cd available)
    if fallbackIDs and #fallbackIDs > 0 then
        for _, id in ipairs(fallbackIDs) do
            table.insert(lines, string.format("/use item:%d", id))
        end
    elseif bestID then
        -- Fallback to just the best ID if no fallbacks provided
        table.insert(lines, string.format("/use item:%d", bestID))
    end
    
    return table.concat(lines, "\n")
end

--- Updates a macro's body and icon to match a given item ID and fallbacks.
--- Uses macroID to ensure we edit the correct character-specific macro.
--- @param macroName string Name of the macro
--- @param bestID number|nil Best item ID for tooltip/icon
--- @param fallbackIDs table|nil Array of all owned IDs for fallbacks
local function applyMacro(macroName, bestID, fallbackIDs)
    local macroID = ensureMacro(macroName)
    local body = buildMacroBody(bestID, fallbackIDs)
    local icon = bestID and select(10, GetItemInfo(bestID)) or ICON_FALLBACK
    -- Use macroID instead of name to guarantee we're editing the character macro
    EditMacro(macroID, macroName, icon, body)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Recalculates the best available flask and potion, updates both macros,
--- caches the active IDs on adpm, and optionally prints a status message.
--- @param silent boolean  if true, suppresses chat output regardless of DB setting
function adpm.UpdateMacros(silent)
    -- Get best IDs + all owned IDs for combat-safe fallback macros
    local flaskBest, flaskFallbacks = adpm.GetOwnedFlaskIDs(ADPMCharDB.selectedFlask)
    local potionBest, potionFallbacks = adpm.GetOwnedPotionIDs(ADPMCharDB.selectedPotion)

    local flaskChanged  = flaskBest  ~= adpm.activeFlaskID
    local potionChanged = potionBest ~= adpm.activePotionID

    adpm.activeFlaskID  = flaskBest
    adpm.activePotionID = potionBest

    -- Build macros with fallback chains
    applyMacro(adpm.MACRO_FLASK, flaskBest, flaskFallbacks)
    applyMacro(adpm.MACRO_POTION, potionBest, potionFallbacks)

    -- Notify the options panel to refresh its status row (if open)
    if adpm.RefreshStatusRow then
        adpm.RefreshStatusRow()
    end

    -- Chat feedback (only on actual changes, not every bag event)
    if not silent and ADPMCharDB.showChatStatus and (flaskChanged or potionChanged) then
        local flaskDef  = flaskBest  and adpm.GetFlaskDef(ADPMCharDB.selectedFlask)
        local potionDef = potionBest and adpm.GetPotionDef(ADPMCharDB.selectedPotion)

        local flaskName  = flaskDef  and ("|cff" .. flaskDef.color  .. flaskDef.label  .. "|r") or "|cffaaaaaa(none)|r"
        local potionName = potionDef and ("|cff" .. potionDef.color .. potionDef.label .. "|r") or "|cffaaaaaa(none)|r"

        print("|cff00ccff[AutoDPSPotMacro]|r Flask: " .. flaskName .. "  Potion: " .. potionName)
    end
end

--- Prints the current macro status to chat regardless of settings.
function adpm.PrintStatus()
    local flaskDef  = ADPMCharDB.selectedFlask  and adpm.GetFlaskDef(ADPMCharDB.selectedFlask)
    local potionDef = ADPMCharDB.selectedPotion and adpm.GetPotionDef(ADPMCharDB.selectedPotion)

    local function fmt(def, activeID)
        if not def then return "|cffaaaaaa-- none selected --|r" end
        local owned = activeID and adpm.items[activeID] and adpm.items[activeID]:GetCount() or 0
        local quality = ""
        if activeID then
            local isFleeting = false
            for _, fid in ipairs(def.fleetingIDs or {}) do
                if fid == activeID then isFleeting = true; break end
            end
            if isFleeting then
                quality = "|cff88ccffFleeting|r"
            else
                local pos, total = 1, #def.craftedIDs
                for i, cid in ipairs(def.craftedIDs) do
                    if cid == activeID then pos = i; break end
                end
                quality = pos == total and "|cffffcc00Gold|r" or "|cffc0c0c0Silver|r"
            end
        end
        return "|cff" .. def.color .. def.label .. "|r " .. quality .. " |cffaaaaaa(x" .. owned .. ")|r"
    end

    print("|cff00ccff[AutoDPSPotMacro] Status|r")
    print("  Flask : " .. fmt(flaskDef, adpm.activeFlaskID))
    print("  Potion: " .. fmt(potionDef, adpm.activePotionID))
    print("  Macros: |cffcccccc" .. adpm.MACRO_FLASK .. "|r  |cffcccccc" .. adpm.MACRO_POTION .. "|r")
    print("  |cff888888(Fallbacks enabled: macros work even if you run out of the best quality mid-combat)|r")
end