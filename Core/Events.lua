-- Core\Events.lua
-- Registers WoW events and drives macro updates.
-- Updates are throttled: rapid bag events collapse into one deferred update
-- 0.5s after the last trigger, so we never spam EditMacro during looting.

local addonName, adpm = ...

local THROTTLE_DELAY = 0.5  -- seconds

local ticker = nil

local function cancelTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function scheduleDeferredUpdate()
    cancelTicker()
    ticker = C_Timer.NewTicker(THROTTLE_DELAY, function()
        cancelTicker()
        if not adpm.inCombat then
            adpm.UpdateMacros()
        end
    end, 1)
end

-- ─── Event frame ──────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame", "AutoDPSPotMacroEventFrame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")   -- entered combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")    -- left combat
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("ITEM_COUNT_CHANGED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")

frame:SetScript("OnEvent", function(self, event, arg1, ...)
    -- ── Initialisation ──────────────────────────────────────────────────────
    if event == "ADDON_LOADED" and arg1 == adpm.ADDON_NAME then
        adpm.InitDB()
        adpm.BuildMinimapButton()
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        adpm.inCombat = UnitAffectingCombat("player") == true
        if not adpm.inCombat then
            -- Slight delay on login so item cache is warm
            C_Timer.After(1.5, function()
                adpm.UpdateMacros(true)  -- silent on first load
            end)
        end
        return
    end

    -- ── Combat guard ────────────────────────────────────────────────────────
    if event == "PLAYER_REGEN_DISABLED" then
        adpm.inCombat = true
        cancelTicker()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        adpm.inCombat = false
        -- Immediately update after combat ends (bags may have changed)
        adpm.UpdateMacros()
        return
    end

    -- ── Bag / inventory changes (throttled) ─────────────────────────────────
    if event == "BAG_UPDATE"
    or event == "BAG_UPDATE_DELAYED"
    or event == "ITEM_COUNT_CHANGED"
    or event == "PLAYER_EQUIPMENT_CHANGED"
    or event == "TRAIT_CONFIG_UPDATED" then
        if not adpm.inCombat then
            scheduleDeferredUpdate()
        end
        return
    end
end)

-- ─── Slash commands ────────────────────────────────────────────────────────────

SLASH_ADPM1 = "/adpm"
SLASH_ADPM2 = "/adpmauto"

SlashCmdList["ADPM"] = function(msg)
    local cmd = strtrim(msg or ""):lower()

    if cmd == "" or cmd == "config" or cmd == "options" then
        Settings.OpenToCategory(adpm.adpmCategoryID)

    elseif cmd == "status" then
        adpm.PrintStatus()

    elseif cmd == "update" then
        adpm.UpdateMacros()
        print("|cff00ccff[AutoDPSPotMacro]|r Macros refreshed.")

    elseif cmd == "minimap" then
        ADPMDB.minimapHidden = not ADPMDB.minimapHidden
        adpm.SetMinimapButtonVisible(not ADPMDB.minimapHidden)
        print("|cff00ccff[AutoDPSPotMacro]|r Minimap button " .. (ADPMDB.minimapHidden and "hidden" or "shown") .. ".")

    elseif cmd == "help" then
        print("|cff00ccff[AutoDPSPotMacro]|r Commands:")
        print("  |cffcccccc/adpm|r           Open options")
        print("  |cffcccccc/adpm status|r    Show current macro status")
        print("  |cffcccccc/adpm update|r    Force macro refresh")
        print("  |cffcccccc/adpm minimap|r   Toggle minimap button")
        print("  |cffcccccc/adpm help|r      This message")
    else
        print("|cff00ccff[AutoDPSPotMacro]|r Unknown command. Type |cffcccccc/adpm help|r for options.")
    end
end
