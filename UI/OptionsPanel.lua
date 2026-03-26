-- UI\OptionsPanel.lua
-- Settings panel registered with the modern Settings API.
-- Layout:
--   ┌─────────────────────────────────────────────────┐
--   │  Auto DPS Pot Macro  (Midnight)                       │
--   │  ─────────────────────────────────────────────  │
--   │  [STATUS ROW]  Flask: xxx   Potion: yyy          │
--   │  ─────────────────────────────────────────────  │
--   │  ● Flasks  (choose one)                          │
--   │    ○ Flask of the Blood Knights  (Haste)         │
--   │    ○ Flask of the Shattered Sun  (Crit)          │
--   │    ...                                           │
--   │  ─────────────────────────────────────────────  │
--   │  ● Potions  (choose one)                         │
--   │    ○ Potion of Recklessness  (...)               │
--   │    ...                                           │
--   │  ─────────────────────────────────────────────  │
--   │  [ ] Show chat notification on macro update      │
--   │  [ ] Hide minimap button                         │
--   └─────────────────────────────────────────────────┘

local addonName, adpm = ...

-- Layout constants
local PANEL_W    = 600
local PANEL_H    = 580
local MARGIN     = 18
local ROW_H      = 28
local INDENT     = 36
local HALF_W     = (PANEL_W - MARGIN * 2) / 2 - 8

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
    t:SetSize(PANEL_W - MARGIN * 2, 1)
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

--- Small descriptive text
local function addSubText(parent, y, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, y)
    fs:SetText(text)
    fs:SetTextColor(0.65, 0.65, 0.65)
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

        -- Determine quality label by position in the tier list.
        -- Last entry in craftedIDs = highest quality (Gold).
        -- First entry = lowest quality (Silver).
        -- Any ID found in fleetingIDs = Fleeting.
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

    -- Label (loaded async)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", btn, "RIGHT", 4, 0)
    lbl:SetText(def.label)   -- default until async load

    -- Stat badge
    local badge = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    badge:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    badge:SetText(colorStr(def.color, "(" .. def.stat .. ")"))

    -- Async name refresh
    local topID = def.craftedIDs[#def.craftedIDs]
    local pItem = adpm.items[topID]
    if pItem then
        pItem:WhenLoaded(function()
            lbl:SetText(pItem:GetName())
        end)
    end

    -- Tooltip
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

    -- Click: radio-button exclusivity
    btn:SetScript("OnClick", function(self)
        -- Uncheck all others in the same group
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
    local frame = CreateFrame("Frame")
    frame.name = "Auto DPS Pot Macro"

    -- ── Title ────────────────────────────────────────────────────────────────
    local titleText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    titleText:SetText(colorStr("00ccff", "Auto DPS Pot Macro") .. "  " .. colorStr("555555", "v" .. adpm.VERSION .. " · Midnight"))

    -- ── Status row ────────────────────────────────────────────────────────────
    local statusY = -MARGIN - 28
    addDivider(frame, statusY)

    local statusLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusLabel:SetPoint("TOPLEFT", MARGIN, statusY - 8)
    statusLabel:SetText(colorStr("00ccff", ">> Current Macros"))

    local flaskLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    flaskLabel:SetPoint("TOPLEFT", MARGIN, statusY - 24)
    flaskLabel:SetText(colorStr("888888", "Flask:"))
    flaskLabel:SetWidth(50)

    statusFlaskText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusFlaskText:SetPoint("LEFT", flaskLabel, "RIGHT", 4, 0)
    statusFlaskText:SetText(colorStr("888888", "—"))

    local potionLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    potionLabel:SetPoint("TOPLEFT", MARGIN, statusY - 42)
    potionLabel:SetText(colorStr("888888", "Potion:"))
    potionLabel:SetWidth(50)

    statusPotionText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusPotionText:SetPoint("LEFT", potionLabel, "RIGHT", 4, 0)
    statusPotionText:SetText(colorStr("888888", "—"))

    -- ── Flask section ─────────────────────────────────────────────────────────
    local flaskDivY = statusY - 66
    addDivider(frame, flaskDivY)

    local flaskHeaderY = flaskDivY - 12
    addHeader(frame, flaskHeaderY, colorStr("ffcc00", "Flask") .. "  " .. colorStr("888888", "(choose one — lasts 1 hour)"))

    local fy = flaskHeaderY - 22
    for _, def in ipairs(adpm.flaskDefs) do
        makeRadio(frame, INDENT, fy, "Flask", def.key, def, flaskRadios, "selectedFlask")
        fy = fy - ROW_H
    end

    -- None option for flasks
    do
        local noneBtn = CreateFrame("CheckButton", nil, frame, "UIRadioButtonTemplate")
        noneBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", INDENT, fy)
        local noneLbl = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
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
    addDivider(frame, potionDivY)

    local potionHeaderY = potionDivY - 12
    addHeader(frame, potionHeaderY, colorStr("ffcc00", "Potion") .. "  " .. colorStr("888888", "(choose one — 30s combat pot)"))

    local py = potionHeaderY - 22
    for _, def in ipairs(adpm.potionDefs) do
        makeRadio(frame, INDENT, py, "Potion", def.key, def, potionRadios, "selectedPotion")
        py = py - ROW_H
    end

    -- None option for potions
    do
        local noneBtn = CreateFrame("CheckButton", nil, frame, "UIRadioButtonTemplate")
        noneBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", INDENT, py)
        local noneLbl = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
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
    addDivider(frame, miscDivY)

    local miscY = miscDivY - 14
    addHeader(frame, miscY, colorStr("888888", "Options"))

    -- Chat notification toggle
    local chatCB = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    chatCB:SetPoint("TOPLEFT", frame, "TOPLEFT", INDENT, miscY - 22)
    chatCB.Text:SetText("Show chat notification when macros update")
    chatCB:SetChecked(ADPMDB.showChatStatus)
    chatCB:SetScript("OnClick", function(self)
        ADPMDB.showChatStatus = self:GetChecked()
    end)

    -- Minimap toggle
    local minimapCB = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
	minimapCB:SetPoint("TOPLEFT", frame, "TOPLEFT", INDENT, miscY - 50)
	minimapCB.Text:SetText("Hide minimap button")
	minimapCB:SetChecked(ADPMDB.minimap.hide)
	minimapCB:SetScript("OnClick", function(self)
    ADPMDB.minimap.hide = self:GetChecked()
    adpm.SetMinimapButtonVisible(not ADPMDB.minimap.hide)
	end)

    -- ── Footer ────────────────────────────────────────────────────────────────
    addDivider(frame, miscY - 76)
    local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer:SetPoint("TOPLEFT", MARGIN, miscY - 88)
    footer:SetText(colorStr("555555",
        "Macros: " .. adpm.MACRO_FLASK .. "  /  " .. adpm.MACRO_POTION ..
        "   ·   /adpm help for commands"))

    -- ── Register ──────────────────────────────────────────────────────────────
    local category = Settings.RegisterCanvasLayoutCategory(frame, "Auto DPS Pot Macro")
    Settings.RegisterAddOnCategory(category)
    adpm.adpmCategoryID = category:GetID()

    -- Populate status row immediately
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
