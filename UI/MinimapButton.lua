-- UI\MinimapButton.lua

local addonName, adpm = ...

local ICON_TEXTURE = "Interface\\Icons\\INV_Alchemy_Potion_05"

local hasLibDBIcon, LibDBIcon = pcall(LibStub, "LibDBIcon-1.0")
local hasLDB, LDB = pcall(LibStub, "LibDataBroker-1.1")

function adpm.SetMinimapButtonVisible(visible)
    if not hasLibDBIcon then return end
    if visible then
        LibDBIcon:Show("AutoDPSPotMacro")
    else
        LibDBIcon:Hide("AutoDPSPotMacro")
    end
end

function adpm.BuildMinimapButton()
    if not hasLibDBIcon or not hasLDB then
        adpm.BuildFallbackMinimapButton()
        return
    end

    local ldb = LDB:NewDataObject("AutoDPSPotMacro", {
        type = "launcher",
        text = "Auto DPS Pot Macro",
        icon = ICON_TEXTURE,
        
        OnClick = function(self, button)
            if button == "LeftButton" then
                Settings.OpenToCategory(adpm.adpmCategoryID)
            elseif button == "RightButton" then
                adpm.PrintStatus()
            end
        end,
        
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cff00ccffAuto DPS Pot Macro|r", 1, 1, 1)
            tooltip:AddLine(" ")
            tooltip:AddLine("Left-click: Open options", 0.8, 0.8, 0.8)
            tooltip:AddLine("Right-click: Print status", 0.8, 0.8, 0.8)
            tooltip:AddLine(" ")
            
            -- CHANGED: ADPMDB -> ADPMCharDB
            local flaskDef  = ADPMCharDB.selectedFlask  and adpm.GetFlaskDef(ADPMCharDB.selectedFlask)
            local potionDef = ADPMCharDB.selectedPotion and adpm.GetPotionDef(ADPMCharDB.selectedPotion)
            
            tooltip:AddDoubleLine(
                "Flask:",
                flaskDef and ("|cff" .. flaskDef.color .. flaskDef.label .. "|r") or "|cffaaaaaa--none--|r",
                0.6, 0.6, 0.6, 1, 1, 1)
            tooltip:AddDoubleLine(
                "Potion:",
                potionDef and ("|cff" .. potionDef.color .. potionDef.label .. "|r") or "|cffaaaaaa--none--|r",
                0.6, 0.6, 0.6, 1, 1, 1)
        end,
    })

    -- CHANGED: ADPMDB -> ADPMCharDB
    LibDBIcon:Register("AutoDPSPotMacro", ldb, ADPMCharDB.minimap)
    
    -- CHANGED: ADPMDB -> ADPMCharDB
    if ADPMCharDB.minimap.hide then
        LibDBIcon:Hide("AutoDPSPotMacro")
    end
end

function adpm.BuildFallbackMinimapButton()
    local btn = CreateFrame("Button", "AutoDPSPotMacroMinimapBtn", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    bg:SetAllPoints()

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetAllPoints()

    local MINIMAP_RADIUS = 80
    local function updatePosition()
        -- CHANGED: ADPMDB -> ADPMCharDB
        local angle = math.rad(ADPMCharDB.minimap.minimapPos or 220)
        btn:SetPoint("CENTER", Minimap, "CENTER",
            MINIMAP_RADIUS * math.cos(angle),
            MINIMAP_RADIUS * math.sin(angle))
    end

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff00ccffAuto DPS Pot Macro|r", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Open options", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Print status", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        -- CHANGED: ADPMDB -> ADPMCharDB
        local flaskDef  = ADPMCharDB.selectedFlask  and adpm.GetFlaskDef(ADPMCharDB.selectedFlask)
        local potionDef = ADPMCharDB.selectedPotion and adpm.GetPotionDef(ADPMCharDB.selectedPotion)
        GameTooltip:AddDoubleLine(
            "Flask:",
            flaskDef and ("|cff" .. flaskDef.color .. flaskDef.label .. "|r") or "|cffaaaaaa--none--|r",
            0.6, 0.6, 0.6, 1, 1, 1)
        GameTooltip:AddDoubleLine(
            "Potion:",
            potionDef and ("|cff" .. potionDef.color .. potionDef.label .. "|r") or "|cffaaaaaa--none--|r",
            0.6, 0.6, 0.6, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            Settings.OpenToCategory(adpm.adpmCategoryID)
        elseif button == "RightButton" then
            adpm.PrintStatus()
        end
    end)

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            -- CHANGED: ADPMDB -> ADPMCharDB
            ADPMCharDB.minimap.minimapPos = math.deg(math.atan2(cy - my, cx - mx))
            updatePosition()
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    updatePosition()
    -- CHANGED: ADPMDB -> ADPMCharDB
    if ADPMCharDB.minimap.hide then btn:Hide() end
end