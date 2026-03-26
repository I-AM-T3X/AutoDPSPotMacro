-- Core\MacroEngine.lua
-- Responsible for creating, updating, and icon-syncing the two macros.
-- Creates CHARACTER SPECIFIC macros.

local addonName, adpm = ...

local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local function ensureMacro(name)
    local macroID = GetMacroInfo(name)
    if not macroID then
        macroID = CreateMacro(name, ICON_FALLBACK, nil, true)
    end
    return macroID
end

local function buildMacroBody(itemID)
    if not itemID then
        return "#showtooltip\n"
    end
    return string.format("#showtooltip item:%d\n/use item:%d", itemID, itemID)
end

local function applyMacro(macroName, itemID)
    local macroID = ensureMacro(macroName)
    local body = buildMacroBody(itemID)
    local icon = itemID and select(10, GetItemInfo(itemID)) or ICON_FALLBACK
    EditMacro(macroID, macroName, icon, body)
end

function adpm.UpdateMacros(silent)
    local flaskID  = adpm.GetBestFlaskID()
    local potionID = adpm.GetBestPotionID()

    local flaskChanged  = flaskID  ~= adpm.activeFlaskID
    local potionChanged = potionID ~= adpm.activePotionID

    adpm.activeFlaskID  = flaskID
    adpm.activePotionID = potionID

    applyMacro(adpm.MACRO_FLASK,  flaskID)
    applyMacro(adpm.MACRO_POTION, potionID)

    if adpm.RefreshStatusRow then
        adpm.RefreshStatusRow()
    end

    -- CHANGED: ADPMDB -> ADPMCharDB
    if not silent and ADPMCharDB.showChatStatus and (flaskChanged or potionChanged) then
        local flaskDef  = flaskID  and adpm.GetFlaskDef(ADPMCharDB.selectedFlask)
        local potionDef = potionID and adpm.GetPotionDef(ADPMCharDB.selectedPotion)

        local flaskName  = flaskDef  and ("|cff" .. flaskDef.color  .. flaskDef.label  .. "|r") or "|cffaaaaaa(none)|r"
        local potionName = potionDef and ("|cff" .. potionDef.color .. potionDef.label .. "|r") or "|cffaaaaaa(none)|r"

        print("|cff00ccff[AutoDPSPotMacro]|r Flask: " .. flaskName .. "  Potion: " .. potionName)
    end
end

function adpm.PrintStatus()
    -- CHANGED: ADPMDB -> ADPMCharDB
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
end