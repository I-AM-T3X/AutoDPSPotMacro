-- Core\Events.lua

local addonName, adpm = ...

local THROTTLE_DELAY = 0.5
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

local frame = CreateFrame("Frame", "AutoDPSPotMacroEventFrame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("ITEM_COUNT_CHANGED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")

frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == adpm.ADDON_NAME then
        adpm.InitDB()
        adpm.BuildMinimapButton()
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        adpm.inCombat = UnitAffectingCombat("player") == true
        if not adpm.inCombat then
            C_Timer.After(1.5, function()
                adpm.UpdateMacros(true)
            end)
        end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        adpm.inCombat = true
        cancelTicker()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        adpm.inCombat = false
        adpm.UpdateMacros()
        return
    end

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
        -- CHANGED: ADPMDB -> ADPMCharDB
        ADPMCharDB.minimapHidden = not ADPMCharDB.minimapHidden
        adpm.SetMinimapButtonVisible(not ADPMCharDB.minimapHidden)
        print("|cff00ccff[AutoDPSPotMacro]|r Minimap button " .. (ADPMCharDB.minimapHidden and "hidden" or "shown") .. ".")

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