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
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == adpm.ADDON_NAME then
        adpm.InitDB()
        adpm.BuildMinimapButton()
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        adpm.inCombat = UnitAffectingCombat("player") == true
        adpm.RefreshActiveSpec()
        if adpm.SyncRadiosToProfile then adpm.SyncRadiosToProfile() end
        if not adpm.inCombat then
            C_Timer.After(1.5, function()
                adpm.UpdateMacros(true)
                if adpm.RebuildSpecHeader then adpm.RebuildSpecHeader() end
            end)
        end
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Spec changed: re-detect spec, rebuild options header, refresh macros
        local changed = adpm.RefreshActiveSpec()
        if changed then
            if ADPMCharDB.showChatStatus then
                local specName = select(2, GetSpecializationInfo(GetSpecialization())) or "Unknown"
                print("|cff00ccff[AutoDPSPotMacro]|r Switched to |cffffcc00" .. specName .. "|r spec profile.")
            end
            if adpm.RebuildSpecHeader then adpm.RebuildSpecHeader() end
            if adpm.SyncRadiosToProfile then adpm.SyncRadiosToProfile() end
            if not adpm.inCombat then
                adpm.UpdateMacros()
            end
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
        ADPMCharDB.minimap.hide = not ADPMCharDB.minimap.hide
        adpm.SetMinimapButtonVisible(not ADPMCharDB.minimap.hide)
        print("|cff00ccff[AutoDPSPotMacro]|r Minimap button " .. (ADPMCharDB.minimap.hide and "hidden" or "shown") .. ".")

    elseif cmd == "changelog" or cmd == "changes" then
        Settings.OpenToCategory(adpm.adpmChangelogCategoryID or adpm.adpmCategoryID)

    elseif cmd == "restock" then
        Settings.OpenToCategory(adpm.adpmCategoryID)

    elseif cmd == "restockdebug" then
        local s = adpm.GetRestockStatus()
        print("|cff00ccff[AutoDPSPotMacro]|r Restock debug:")
        print(string.format("  enabled: %s", tostring(s.enabled)))
        print(string.format("  Flask: %s | have %d | min %d | max %d | LOW=%s",
            s.flaskDef and s.flaskDef.label or "|cffff4444none selected|r",
            s.flaskCount, s.flaskMin, s.flaskMax, tostring(s.flaskLow)))
        print(string.format("  Potion: %s | have %d | min %d | max %d | LOW=%s",
            s.potionDef and s.potionDef.label or "|cffff4444none selected|r",
            s.potionCount, s.potionMin, s.potionMax, tostring(s.potionLow)))
        print("  AuctionHouseFrame loaded: " .. tostring(AuctionHouseFrame ~= nil))

    elseif cmd == "ahtest" then
        print("|cff00ccff[AutoDPSPotMacro]|r Manually running the AH panel build...")
        local before = adpm.DebugRestockAHState()
        print(string.format("  before: AH loaded=%s panel exists=%s shown=%s",
            tostring(before.auctionHouseFrameExists), tostring(before.panelExists), tostring(before.panelShown)))

        local ok, err = pcall(adpm.CheckRestockAtAH)

        if ok then
            print("|cff44ff88  CheckRestockAtAH ran without error.|r")
        else
            print("|cffff4444  CheckRestockAtAH ERRORED:|r " .. tostring(err))
        end

        -- GetLeft/Right/Top/Bottom can read back nil if queried in the same
        -- tick a frame was just positioned -- the layout pass that actually
        -- computes them hasn't run yet. Wait one tick before reading.
        C_Timer.After(0, function()
            local after = adpm.DebugRestockAHState()
            print(string.format("  after: panel exists=%s shown=%s parent=%s",
                tostring(after.panelExists), tostring(after.panelShown), after.panelParent))
            print(string.format("  screen: %sx%s", tostring(after.screenWidth), tostring(after.screenHeight)))
            if after.left then
                print(string.format("  panel coords: left=%s right=%s top=%s bottom=%s strata=%s level=%s",
                    tostring(after.left), tostring(after.right), tostring(after.top), tostring(after.bottom),
                    tostring(after.strata), tostring(after.level)))
            else
                print("|cffff4444  panel coords still nil after a tick -- frame may not be anchored at all.|r")
            end
            if after.ahRight then
                print(string.format("  AuctionHouseFrame: right=%s strata=%s", tostring(after.ahRight), tostring(after.ahStrata)))
            end
        end)

    elseif cmd == "help" then
        print("|cff00ccff[AutoDPSPotMacro]|r Commands:")
        print("  |cffcccccc/adpm|r               Open options")
        print("  |cffcccccc/adpm status|r        Show current macro status")
        print("  |cffcccccc/adpm update|r        Force macro refresh")
        print("  |cffcccccc/adpm minimap|r       Toggle minimap button")
        print("  |cffcccccc/adpm changelog|r     Show version changelog")
        print("  |cffcccccc/adpm restock|r       Open restock settings")
        print("  |cffcccccc/adpm restockdebug|r  Print restock status to chat")
        print("  |cffcccccc/adpm ahtest|r        Manually test the AH panel (run this AT the AH)")
        print("  |cffcccccc/adpm help|r          This message")
    else
        print("|cff00ccff[AutoDPSPotMacro]|r Unknown command. Type |cffcccccc/adpm help|r for options.")
    end
end