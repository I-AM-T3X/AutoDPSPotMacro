-- UI\OptionsPanel.lua

local addonName, adpm = ...

local PANEL_W    = 600
local SCROLL_W   = PANEL_W - 20
local MARGIN     = 18
local ROW_H      = 28
local INDENT     = 36

local flaskRadios  = {}
local potionRadios = {}
local statusFlaskText
local statusPotionText

local function colorStr(hex, text)
    return "|cff" .. hex .. text .. "|r"
end

local function addDivider(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    t:SetSize(SCROLL_W - MARGIN * 2, 1)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, y)
    return t
end

local function addHeader(parent, y, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, y)
    fs:SetText(text)
    return fs
end

function adpm.RefreshStatusRow()
    if not statusFlaskText then return end

    -- CHANGED: ADPMDB -> ADPMCharDB
    local flaskDef  = ADPMCharDB.selectedFlask  and adpm.GetFlaskDef(ADPMCharDB.selectedFlask)
    local potionDef = ADPMCharDB.selectedPotion and adpm.GetPotionDef(ADPMCharDB.selectedPotion)

    local flaskID  = adpm.activeFlaskID
    local potionID = adpm.activePotionID

    local function fmtItem(def, activeID)
        if not def then
            return colorStr("888888", "None selected")
        end
        local name = colorStr(def.color, def.label)
        if not activeID then
            return name .. colorStr("ff4444", "  ✗ Not in bags")
        end
        local count = adpm.items[activeID] and adpm.items[activeID]:GetCount() or 0

        local qual
        local isFleeting = false
        for _, fid in ipairs(def.fleetingIDs or {}) do
            if fid == activeID then isFleeting = true; break end
        end

        if isFleeting then
            qual = colorStr("88ccff", "Fleeting")
        else
            local pos, total = 1, #def.craftedIDs
            for i, cid in ipairs(def.craftedIDs) do
                if cid == activeID then pos = i; break end
            end
            if pos == total then
                qual = colorStr("ffcc00", "Gold")
            else
                qual = colorStr("aaaaaa", "Silver")
            end
        end

        return name .. "  " .. qual .. colorStr("888888", "  x" .. count)
    end

    statusFlaskText:SetText(fmtItem(flaskDef, flaskID))
    statusPotionText:SetText(fmtItem(potionDef, potionID))
end

local function makeRadio(parent, x, y, prefix, key, def, radioTable, dbKey)
    local btn = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", btn, "RIGHT", 4, 0)
    lbl:SetText(def.label)

    local badge = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    badge:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    badge:SetText(colorStr(def.color, "(" .. def.stat .. ")"))

    local topID = def.craftedIDs[#def.craftedIDs]
    local pItem = adpm.items[topID]
    if pItem then
        pItem:WhenLoaded(function()
            lbl:SetText(pItem:GetName())
        end)
    end

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if topID then
            GameTooltip:SetItemByID(topID)
        else
            GameTooltip:SetText(def.label)
        end
        if def.desc then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(def.desc, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self)
        for k, other in pairs(radioTable) do
            other:SetChecked(false)
        end
        btn:SetChecked(true)
        -- CHANGED: ADPMDB -> ADPMCharDB
        ADPMCharDB[dbKey] = key
        adpm.UpdateMacros()
    end)

    -- CHANGED: ADPMDB -> ADPMCharDB
    btn:SetChecked(ADPMCharDB[dbKey] == key)
    radioTable[key] = btn
    return btn
end

local function buildPanel()
    local frame = CreateFrame("Frame")
    frame.name = "Auto DPS Pot Macro"

    local sf = CreateFrame("ScrollFrame", "ADPMScrollFrame", frame, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 0)

    local content = CreateFrame("Frame", "ADPMScrollContent", sf)
    content:SetSize(SCROLL_W, 1)
    sf:SetScrollChild(content)

    local p = content

    local titleText = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    titleText:SetText(colorStr("00ccff", "Auto DPS Pot Macro") .. "  " .. colorStr("555555", "v" .. adpm.VERSION .. " · Midnight"))

    local statusY = -MARGIN - 28
    addDivider(p, statusY)

    local statusLabel = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusLabel:SetPoint("TOPLEFT", MARGIN, statusY - 8)
    statusLabel:SetText(colorStr("00ccff", ">> Current Macros"))

    local flaskLabel = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    flaskLabel:SetPoint("TOPLEFT", MARGIN, statusY - 24)
    flaskLabel:SetText(colorStr("888888", "Flask:"))
    flaskLabel:SetWidth(50)

    statusFlaskText = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusFlaskText:SetPoint("LEFT", flaskLabel, "RIGHT", 4, 0)
    statusFlaskText:SetText(colorStr("888888", "—"))

    local potionLabel = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    potionLabel:SetPoint("TOPLEFT", MARGIN, statusY - 42)
    potionLabel:SetText(colorStr("888888", "Potion:"))
    potionLabel:SetWidth(50)

    statusPotionText = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusPotionText:SetPoint("LEFT", potionLabel, "RIGHT", 4, 0)
    statusPotionText:SetText(colorStr("888888", "—"))

    local flaskDivY = statusY - 66
    addDivider(p, flaskDivY)

    local flaskHeaderY = flaskDivY - 12
    addHeader(p, flaskHeaderY, colorStr("ffcc00", "Flask") .. "  " .. colorStr("888888", "(choose one — lasts 1 hour)"))

    local fy = flaskHeaderY - 22
    for _, def in ipairs(adpm.flaskDefs) do
        makeRadio(p, INDENT, fy, "Flask", def.key, def, flaskRadios, "selectedFlask")
        fy = fy - ROW_H
    end

    do
        local noneBtn = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
        noneBtn:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, fy)
        local noneLbl = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noneLbl:SetPoint("LEFT", noneBtn, "RIGHT", 4, 0)
        noneLbl:SetText(colorStr("888888", "None — disable flask macro"))
        noneBtn:SetScript("OnClick", function()
            for _, other in pairs(flaskRadios) do other:SetChecked(false) end
            noneBtn:SetChecked(true)
            -- CHANGED: ADPMDB -> ADPMCharDB
            ADPMCharDB.selectedFlask = nil
            adpm.UpdateMacros()
        end)
        -- CHANGED: ADPMDB -> ADPMCharDB
        noneBtn:SetChecked(ADPMCharDB.selectedFlask == nil)
        flaskRadios["__none"] = noneBtn
        fy = fy - ROW_H
    end

    local potionDivY = fy - 4
    addDivider(p, potionDivY)

    local potionHeaderY = potionDivY - 12
    addHeader(p, potionHeaderY, colorStr("ffcc00", "Potion") .. "  " .. colorStr("888888", "(choose one — 30s combat pot)"))

    local py = potionHeaderY - 22
    for _, def in ipairs(adpm.potionDefs) do
        makeRadio(p, INDENT, py, "Potion", def.key, def, potionRadios, "selectedPotion")
        py = py - ROW_H
    end

    do
        local noneBtn = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
        noneBtn:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, py)
        local noneLbl = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noneLbl:SetPoint("LEFT", noneBtn, "RIGHT", 4, 0)
        noneLbl:SetText(colorStr("888888", "None — disable potion macro"))
        noneBtn:SetScript("OnClick", function()
            for _, other in pairs(potionRadios) do other:SetChecked(false) end
            noneBtn:SetChecked(true)
            -- CHANGED: ADPMDB -> ADPMCharDB
            ADPMCharDB.selectedPotion = nil
            adpm.UpdateMacros()
        end)
        -- CHANGED: ADPMDB -> ADPMCharDB
        noneBtn:SetChecked(ADPMCharDB.selectedPotion == nil)
        potionRadios["__none"] = noneBtn
        py = py - ROW_H
    end

    local miscDivY = py - 8
    addDivider(p, miscDivY)

    local miscY = miscDivY - 14
    addHeader(p, miscY, colorStr("888888", "Options"))

    local chatCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    chatCB:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, miscY - 22)
    chatCB.Text:SetText("Show chat notification when macros update")
    -- CHANGED: ADPMDB -> ADPMCharDB
    chatCB:SetChecked(ADPMCharDB.showChatStatus)
    chatCB:SetScript("OnClick", function(self)
        -- CHANGED: ADPMDB -> ADPMCharDB
        ADPMCharDB.showChatStatus = self:GetChecked()
    end)

    local minimapCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    minimapCB:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, miscY - 50)
    minimapCB.Text:SetText("Hide minimap button")
    -- CHANGED: ADPMDB -> ADPMCharDB
    minimapCB:SetChecked(ADPMCharDB.minimap.hide)
    minimapCB:SetScript("OnClick", function(self)
        -- CHANGED: ADPMDB -> ADPMCharDB
        ADPMCharDB.minimap.hide = self:GetChecked()
        adpm.SetMinimapButtonVisible(not ADPMCharDB.minimap.hide)
    end)

    local footerDivY = miscY - 76
    addDivider(p, footerDivY)

    local footer = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer:SetPoint("TOPLEFT", MARGIN, footerDivY - 12)
    footer:SetText(colorStr("555555",
        "Macros: " .. adpm.MACRO_FLASK .. "  /  " .. adpm.MACRO_POTION ..
        "   ·   /adpm help for commands"))

    local totalHeight = -(footerDivY - 30)
    content:SetHeight(totalHeight)

    local category = Settings.RegisterCanvasLayoutCategory(frame, "Auto DPS Pot Macro")
    Settings.RegisterAddOnCategory(category)
    adpm.adpmCategoryID = category:GetID()

    adpm.RefreshStatusRow()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        buildPanel()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)