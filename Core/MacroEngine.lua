-- Core\MacroEngine.lua
-- Responsible for creating, updating, and icon-syncing the two macros.
-- Creates CHARACTER SPECIFIC macros with fallback chains for combat safety.

local addonName, adpm = ...

local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- ─── Internal helpers ─────────────────────────────────────────────────────────

local function ensureMacro(name)
    local macroID = GetMacroInfo(name)
    if not macroID then
        macroID = CreateMacro(name, ICON_FALLBACK, nil, true)
    end
    return macroID
end

--- Builds a /use macro body with fallback items.
--- Uses bare #showtooltip (no item ID) so the icon updates dynamically
--- as the macro cycles through fallback items during combat.
local function buildMacroBody(bestID, fallbackIDs)
    local lines = {}
    
    -- Bare #showtooltip allows dynamic icon updates as items are consumed
    -- If we used #showtooltip item:ID, the icon would lock to that ID
    table.insert(lines, "#showtooltip")
    
    -- Add all owned items as /use lines in priority order
    if fallbackIDs and #fallbackIDs > 0 then
        for _, id in ipairs(fallbackIDs) do
            table.insert(lines, string.format("/use item:%d", id))
        end
    elseif bestID then
        table.insert(lines, string.format("/use item:%d", bestID))
    end
    
    return table.concat(lines, "\n")
end

--- Updates a macro's body and icon to match a given item ID and fallbacks.
local function applyMacro(macroName, bestID, fallbackIDs)
    local macroID = ensureMacro(macroName)
    local body = buildMacroBody(bestID, fallbackIDs)
    -- Use bestID for initial icon, but #showtooltip will update dynamically
    local icon = bestID and select(10, GetItemInfo(bestID)) or ICON_FALLBACK
    EditMacro(macroID, macroName, icon, body)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

function adpm.UpdateMacros(silent)
    local flaskBest, flaskFallbacks = adpm.GetOwnedFlaskIDs(ADPMCharDB.selectedFlask)
    local potionBest, potionFallbacks = adpm.GetOwnedPotionIDs(ADPMCharDB.selectedPotion)

    local flaskChanged  = flaskBest  ~= adpm.activeFlaskID
    local potionChanged = potionBest ~= adpm.activePotionID

    adpm.activeFlaskID  = flaskBest
    adpm.activePotionID = potionBest

    applyMacro(adpm.MACRO_FLASK, flaskBest, flaskFallbacks)
    applyMacro(adpm.MACRO_POTION, potionBest, potionFallbacks)

    if adpm.RefreshStatusRow then
        adpm.RefreshStatusRow()
    end

    if not silent and ADPMCharDB.showChatStatus and (flaskChanged or potionChanged) then
        local flaskDef  = flaskBest  and adpm.GetFlaskDef(ADPMCharDB.selectedFlask)
        local potionDef = potionBest and adpm.GetPotionDef(ADPMCharDB.selectedPotion)

        local flaskName  = flaskDef  and ("|cff" .. flaskDef.color  .. flaskDef.label  .. "|r") or "|cffaaaaaa(none)|r"
        local potionName = potionDef and ("|cff" .. potionDef.color .. potionDef.label .. "|r") or "|cffaaaaaa(none)|r"

        print("|cff00ccff[AutoDPSPotMacro]|r Flask: " .. flaskName .. "  Potion: " .. potionName)
    end
end

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