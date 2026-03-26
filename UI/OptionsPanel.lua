-- UI\OptionsPanel.lua
-- Settings panel registered with the modern Settings API.
-- Uses a ScrollFrame so content never overflows regardless of how many
-- flasks / potions are added in future.

local addonName, adpm = ...

-- Layout constants
local PANEL_W    = 600
local SCROLL_W   = PANEL_W - 20   -- account for scrollbar
local MARGIN     = 18
local ROW_H      = 28
local INDENT     = 36

-- Radio button refs so we can set/unset them programmatically
local flaskRadios  = {}   -- [settingsKey] = CheckButton
local potionRadios = {}

-- Status text refs
local statusFlaskText
local statusPotionText

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function colorStr(hex, text)
    return "|cff" .. hex .. text .. "|r"
end

--- Thin horizontal divider line
local function addDivider(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    t:SetSize(SCROLL_W - MARGIN * 2, 1)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, y)
    return t
end

--- Bold section header
local function addHeader(parent, y, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, y)
    fs:SetText(text)
    return fs
end

-- ─── Status row ───────────────────────────────────────────────────────────────

--- Called by MacroEngine after every update to refresh the live status row.
function adpm.RefreshStatusRow()
    if not statusFlaskText then return end

    local flaskDef  = ADPMDB.selectedFlask  and adpm.GetFlaskDef(ADPMDB.selectedFlask)
    local potionDef = ADPMDB.selectedPotion and adpm.GetPotionDef(ADPMDB.selectedPotion)

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

-- ─── Radio button builder ─────────────────────────────────────────────────────

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
        ADPMDB[dbKey] = key
        adpm.UpdateMacros()
    end)

    btn:SetChecked(ADPMDB[dbKey] == key)
    radioTable[key] = btn
    return btn
end

-- ─── Panel builder ────────────────────────────────────────────────────────────

local function buildPanel()
    -- Outer frame registered with the Settings API
    local frame = CreateFrame("Frame")
    frame.name = "Auto DPS Pot Macro"

    -- ── ScrollFrame ───────────────────────────────────────────────────────────
    local sf = CreateFrame("ScrollFrame", "ADPMScrollFrame", frame, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 0)

    -- The scrollable content child
    local content = CreateFrame("Frame", "ADPMScrollContent", sf)
    content:SetSize(SCROLL_W, 1)   -- height will grow as we add content
    sf:SetScrollChild(content)

    -- Convenience: all layout below targets `content` instead of `frame`
    local p = content

    -- ── Title ─────────────────────────────────────────────────────────────────
    local titleText = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    titleText:SetText(colorStr("00ccff", "Auto DPS Pot Macro") .. "  " .. colorStr("555555", "v" .. adpm.VERSION .. " · Midnight"))

    -- ── Status row ────────────────────────────────────────────────────────────
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

    -- ── Flask section ─────────────────────────────────────────────────────────
    local flaskDivY = statusY - 66
    addDivider(p, flaskDivY)

    local flaskHeaderY = flaskDivY - 12
    addHeader(p, flaskHeaderY, colorStr("ffcc00", "Flask") .. "  " .. colorStr("888888", "(choose one — lasts 1 hour)"))

    local fy = flaskHeaderY - 22
    for _, def in ipairs(adpm.flaskDefs) do
        makeRadio(p, INDENT, fy, "Flask", def.key, def, flaskRadios, "selectedFlask")
        fy = fy - ROW_H
    end

    -- None option for flasks
    do
        local noneBtn = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
        noneBtn:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, fy)
        local noneLbl = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noneLbl:SetPoint("LEFT", noneBtn, "RIGHT", 4, 0)
        noneLbl:SetText(colorStr("888888", "None — disable flask macro"))
        noneBtn:SetScript("OnClick", function()
            for _, other in pairs(flaskRadios) do other:SetChecked(false) end
            noneBtn:SetChecked(true)
            ADPMDB.selectedFlask = nil
            adpm.UpdateMacros()
        end)
        noneBtn:SetChecked(ADPMDB.selectedFlask == nil)
        flaskRadios["__none"] = noneBtn
        fy = fy - ROW_H
    end

    -- ── Potion section ────────────────────────────────────────────────────────
    local potionDivY = fy - 4
    addDivider(p, potionDivY)

    local potionHeaderY = potionDivY - 12
    addHeader(p, potionHeaderY, colorStr("ffcc00", "Potion") .. "  " .. colorStr("888888", "(choose one — 30s combat pot)"))

    local py = potionHeaderY - 22
    for _, def in ipairs(adpm.potionDefs) do
        makeRadio(p, INDENT, py, "Potion", def.key, def, potionRadios, "selectedPotion")
        py = py - ROW_H
    end

    -- None option for potions
    do
        local noneBtn = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
        noneBtn:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, py)
        local noneLbl = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noneLbl:SetPoint("LEFT", noneBtn, "RIGHT", 4, 0)
        noneLbl:SetText(colorStr("888888", "None — disable potion macro"))
        noneBtn:SetScript("OnClick", function()
            for _, other in pairs(potionRadios) do other:SetChecked(false) end
            noneBtn:SetChecked(true)
            ADPMDB.selectedPotion = nil
            adpm.UpdateMacros()
        end)
        noneBtn:SetChecked(ADPMDB.selectedPotion == nil)
        potionRadios["__none"] = noneBtn
        py = py - ROW_H
    end

    -- ── Misc settings ─────────────────────────────────────────────────────────
    local miscDivY = py - 8
    addDivider(p, miscDivY)

    local miscY = miscDivY - 14
    addHeader(p, miscY, colorStr("888888", "Options"))

    local chatCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    chatCB:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, miscY - 22)
    chatCB.Text:SetText("Show chat notification when macros update")
    chatCB:SetChecked(ADPMDB.showChatStatus)
    chatCB:SetScript("OnClick", function(self)
        ADPMDB.showChatStatus = self:GetChecked()
    end)

    local minimapCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    minimapCB:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, miscY - 50)
    minimapCB.Text:SetText("Hide minimap button")
    minimapCB:SetChecked(ADPMDB.minimap.hide)
    minimapCB:SetScript("OnClick", function(self)
        ADPMDB.minimap.hide = self:GetChecked()
        adpm.SetMinimapButtonVisible(not ADPMDB.minimap.hide)
    end)

    -- ── Footer ────────────────────────────────────────────────────────────────
    local footerDivY = miscY - 76
    addDivider(p, footerDivY)

    local footer = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer:SetPoint("TOPLEFT", MARGIN, footerDivY - 12)
    footer:SetText(colorStr("555555",
        "Macros: " .. adpm.MACRO_FLASK .. "  /  " .. adpm.MACRO_POTION ..
        "   ·   /adpm help for commands"))

    -- Set the scroll content height to fit everything
    local totalHeight = -(footerDivY - 30)
    content:SetHeight(totalHeight)

    -- ── Register ──────────────────────────────────────────────────────────────
    local category = Settings.RegisterCanvasLayoutCategory(frame, "Auto DPS Pot Macro")
    Settings.RegisterAddOnCategory(category)
    adpm.adpmCategoryID = category:GetID()

    adpm.RefreshStatusRow()
end

-- Build once the addon is ready
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        buildPanel()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
