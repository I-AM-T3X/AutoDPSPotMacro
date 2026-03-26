-- Core\MacroEngine.lua
-- Responsible for creating, updating, and icon-syncing the two macros.

local addonName, adpm = ...

local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- ─── Internal helpers ─────────────────────────────────────────────────────────

local function ensureMacro(name)
    if not GetMacroInfo(name) then
        CreateMacro(name, ICON_FALLBACK)
    end
end

--- Builds a /use macro body for a single item ID.
--- Uses /use so the game auto-manages the cooldown display on action bars.
--- Falls back to #showtooltip only if no item is available.
local function buildMacroBody(itemID)
    if not itemID then
        return "#showtooltip\n"
    end
    return string.format("#showtooltip item:%d\n/use item:%d", itemID, itemID)
end

--- Updates a macro's body and icon to match a given item ID.
local function applyMacro(macroName, itemID)
    ensureMacro(macroName)
    local body = buildMacroBody(itemID)
    local icon = itemID and select(10, GetItemInfo(itemID)) or ICON_FALLBACK
    EditMacro(macroName, macroName, icon, body)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Recalculates the best available flask and potion, updates both macros,
--- caches the active IDs on adpm, and optionally prints a status message.
--- @param silent boolean  if true, suppresses chat output regardless of DB setting
function adpm.UpdateMacros(silent)
    local flaskID  = adpm.GetBestFlaskID()
    local potionID = adpm.GetBestPotionID()

    local flaskChanged  = flaskID  ~= adpm.activeFlaskID
    local potionChanged = potionID ~= adpm.activePotionID

    adpm.activeFlaskID  = flaskID
    adpm.activePotionID = potionID

    applyMacro(adpm.MACRO_FLASK,  flaskID)
    applyMacro(adpm.MACRO_POTION, potionID)

    -- Notify the options panel to refresh its status row (if open)
    if adpm.RefreshStatusRow then
        adpm.RefreshStatusRow()
    end

    -- Chat feedback (only on actual changes, not every bag event)
    if not silent and ADPMDB.showChatStatus and (flaskChanged or potionChanged) then
        local flaskDef  = flaskID  and adpm.GetFlaskDef(ADPMDB.selectedFlask)
        local potionDef = potionID and adpm.GetPotionDef(ADPMDB.selectedPotion)

        local flaskName  = flaskDef  and ("|cff" .. flaskDef.color  .. flaskDef.label  .. "|r") or "|cffaaaaaa(none)|r"
        local potionName = potionDef and ("|cff" .. potionDef.color .. potionDef.label .. "|r") or "|cffaaaaaa(none)|r"

        print("|cff00ccff[AutoDPSPotMacro]|r Flask: " .. flaskName .. "  Potion: " .. potionName)
    end
end

--- Prints the current macro status to chat regardless of settings.
function adpm.PrintStatus()
    local flaskDef  = ADPMDB.selectedFlask  and adpm.GetFlaskDef(ADPMDB.selectedFlask)
    local potionDef = ADPMDB.selectedPotion and adpm.GetPotionDef(ADPMDB.selectedPotion)

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
