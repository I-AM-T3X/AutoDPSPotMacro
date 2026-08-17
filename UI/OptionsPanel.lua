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
local statusFlaskIcon
local statusPotionIcon
local specHeaderText   -- FontString showing current spec name

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

--- A fancier "glow" divider that fades in from the left, peaks at center, fades out.
--- Used to give the General page header a bit more presence than a flat gray bar.
local function addAccentDivider(parent, y, r, g, b)
    r, g, b = r or 0, g or 0.8, b or 1
    local width = SCROLL_W - MARGIN * 2
    local half  = width / 2

    local left = parent:CreateTexture(nil, "ARTWORK")
    left:SetColorTexture(1, 1, 1, 1)
    left:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.7))
    left:SetSize(half, 2)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, y)

    local right = parent:CreateTexture(nil, "ARTWORK")
    right:SetColorTexture(1, 1, 1, 1)
    right:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.7), CreateColor(r, g, b, 0))
    right:SetSize(half, 2)
    right:SetPoint("LEFT", left, "RIGHT", 0, 0)

    return left, right
end

local function addHeader(parent, y, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, y)
    fs:SetText(text)
    return fs
end

--- Wraps a canvas frame in a standard scroll frame + sized content child.
--- Returns the content frame to build into.
local function makeScrollable(frame)
    local sf = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 0)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(SCROLL_W, 1)
    sf:SetScrollChild(content)
    return content
end

--- Returns a human-readable spec name for the current spec, plus its icon.
local function getSpecLabel()
    local specIndex = GetSpecialization()
    if not specIndex then return "No Spec", nil end
    local _, name, _, icon = GetSpecializationInfo(specIndex)
    return name or "Unknown Spec", icon
end

--- Updates the spec header FontString to show the current spec.
function adpm.RebuildSpecHeader()
    if not specHeaderText then return end
    local specName, specIcon = getSpecLabel()
    local iconStr = specIcon and ("|T" .. specIcon .. ":16:16:0:0:64:64:4:60:4:60|t ") or ""
    specHeaderText:SetText(
        colorStr("00ccff", "Auto DPS Pot Macro") ..
        "  " .. colorStr("888888", "v" .. adpm.VERSION .. " · Midnight") ..
        "   " .. iconStr .. colorStr("ffcc00", "[ " .. specName .. " ]")
    )
end

function adpm.RefreshStatusRow()
    if not statusFlaskText then return end

    local flaskDef  = adpm.GetSelectedFlask()  and adpm.GetFlaskDef(adpm.GetSelectedFlask())
    local potionDef = adpm.GetSelectedPotion() and adpm.GetPotionDef(adpm.GetSelectedPotion())

    local flaskID  = adpm.activeFlaskID
    local potionID = adpm.activePotionID

    local function fmtItem(def, activeID)
        if not def then
            return colorStr("aaaaaa", "None selected")
        end
        local name = colorStr(def.color, def.label)
        if not activeID then
            return name .. colorStr("ff4444", "  [Not in bags]")
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

        return name .. "  " .. qual .. colorStr("aaaaaa", "  x" .. count)
    end

    --- Points an icon texture at the active item (or the top-tier item, dimmed,
    --- if nothing is selected/owned yet), so the status card always shows art.
    local function setIcon(tex, def, activeID)
        if not tex then return end
        local iconID = activeID
        if not iconID and def then
            iconID = def.craftedIDs[#def.craftedIDs]
        end
        local pItem = iconID and adpm.items[iconID]
        if pItem then
            tex:SetTexture(pItem:GetIcon())
            tex:Show()
        else
            tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            tex:Show()
        end
        tex:SetDesaturated(not activeID)
        tex:SetAlpha(activeID and 1 or 0.35)
    end

    statusFlaskText:SetText(fmtItem(flaskDef, flaskID))
    statusPotionText:SetText(fmtItem(potionDef, potionID))
    setIcon(statusFlaskIcon, flaskDef, flaskID)
    setIcon(statusPotionIcon, potionDef, potionID)
end

--- Syncs all radio buttons to reflect the active spec's profile.
--- Called after a spec switch so the panel shows the correct selection.
function adpm.SyncRadiosToProfile()
    local selFlask  = adpm.GetSelectedFlask()
    local selPotion = adpm.GetSelectedPotion()

    for k, btn in pairs(flaskRadios) do
        btn:SetChecked(k == (selFlask or "__none"))
    end
    for k, btn in pairs(potionRadios) do
        btn:SetChecked(k == (selPotion or "__none"))
    end

    adpm.RefreshStatusRow()
end

local function makeRadio(parent, x, y, prefix, key, def, radioTable, setter, getter)
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
        setter(key)
        adpm.UpdateMacros()
    end)

    btn:SetChecked(getter() == key)
    radioTable[key] = btn
    return btn
end

--- Creates a small bordered icon frame (gold trim) and returns both the
--- frame and the inner texture so callers can update the texture later.
local function makeBorderedIcon(parent, size, r, g, b, a)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(size, size)
    f:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    f:SetBackdropBorderColor(r or 1, g or 0.82, b or 0, a or 0.9)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    return f, tex
end

-- ─── Dropdown input for a fixed numeric range (multiples of 5, 0-100) ──────
local function makeThresholdDropdown(parent, x, y, label, getValue, setValue)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetWidth(70)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)

    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", lbl, "TOPRIGHT", -16, 4) -- UIDropDownMenuTemplate has built-in left padding
    UIDropDownMenu_SetWidth(dd, 60)

    local function refreshText()
        UIDropDownMenu_SetText(dd, tostring(getValue()))
    end

    UIDropDownMenu_Initialize(dd, function(self, level)
        for v = 0, 100, 5 do
            local info = UIDropDownMenu_CreateInfo()
            info.text = tostring(v)
            info.value = v
            info.checked = (getValue() == v)
            info.func = function()
                setValue(v)
                refreshText()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    refreshText()
    return dd
end

-- ─── Dropdown for a fixed list of named string choices (e.g. trigger mode) ──
local function makeChoiceDropdown(parent, x, y, label, labelWidth, ddWidth, options, getValue, setValue)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetWidth(labelWidth)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)

    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", lbl, "TOPRIGHT", -16, 4)
    UIDropDownMenu_SetWidth(dd, ddWidth)

    local function textFor(value)
        for _, opt in ipairs(options) do
            if opt.value == value then return opt.text end
        end
        return tostring(value)
    end

    local function refreshText()
        UIDropDownMenu_SetText(dd, textFor(getValue()))
    end

    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, opt in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.checked = (getValue() == opt.value)
            info.func = function()
                setValue(opt.value)
                refreshText()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    refreshText()
    return dd
end

-- ─── General page ───────────────────────────────────────────────────────────
-- Overview: title, current spec, live macro status, footer with macro names,
-- Options, and Restock -- all one scrollable page rather than splitting
-- every small settings group into its own tab.
local function buildGeneralPanel(frame)
    local p = makeScrollable(frame)
    local ICON_SIZE = 40

    -- Title icon (addon's own icon, gold-bordered)
    local iconFrame, iconTex = makeBorderedIcon(p, ICON_SIZE, 1, 0.82, 0, 0.9)
    iconFrame:SetPoint("TOPLEFT", p, "TOPLEFT", MARGIN, -MARGIN)
    iconTex:SetTexture("Interface\\Icons\\INV_Alchemy_Potion_05")

    specHeaderText = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    specHeaderText:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 10, -2)
    specHeaderText:SetText(
        colorStr("00ccff", "Auto DPS Pot Macro") ..
        "  " .. colorStr("888888", "v" .. adpm.VERSION .. " · Midnight")
    )

    local specNoteText = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    specNoteText:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 10, -28)
    specNoteText:SetText(colorStr("aaaaaa", "Settings save per specialization and switch automatically on spec change."))

    local dividerY = -MARGIN - ICON_SIZE - 10
    addAccentDivider(p, dividerY)

    -- ── Current Macros card ──────────────────────────────────────────────────
    local cardTop = dividerY - 10
    local card = CreateFrame("Frame", nil, p, "BackdropTemplate")
    card:SetPoint("TOPLEFT", p, "TOPLEFT", MARGIN, cardTop)
    card:SetPoint("TOPRIGHT", p, "TOPRIGHT", -MARGIN, cardTop)
    card:SetHeight(88)
    card:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    card:SetBackdropColor(0.04, 0.07, 0.10, 0.65)
    card:SetBackdropBorderColor(0, 0.8, 1, 0.4)

    local statusLabel = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    statusLabel:SetText(colorStr("00ccff", ">> Current Macros"))

    local ROW_ICON = 22

    local flaskIconFrame, flaskIconTex = makeBorderedIcon(card, ROW_ICON, 0.6, 0.6, 0.6, 0.8)
    flaskIconFrame:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -32)
    statusFlaskIcon = flaskIconTex

    local flaskLabel = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    flaskLabel:SetPoint("LEFT", flaskIconFrame, "RIGHT", 8, 0)
    flaskLabel:SetText(colorStr("aaaaaa", "Flask:"))
    flaskLabel:SetWidth(42)

    statusFlaskText = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusFlaskText:SetPoint("LEFT", flaskLabel, "RIGHT", 4, 0)
    statusFlaskText:SetText(colorStr("aaaaaa", "—"))

    local potionIconFrame, potionIconTex = makeBorderedIcon(card, ROW_ICON, 0.6, 0.6, 0.6, 0.8)
    potionIconFrame:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -60)
    statusPotionIcon = potionIconTex

    local potionLabel = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    potionLabel:SetPoint("LEFT", potionIconFrame, "RIGHT", 8, 0)
    potionLabel:SetText(colorStr("aaaaaa", "Potion:"))
    potionLabel:SetWidth(42)

    statusPotionText = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusPotionText:SetPoint("LEFT", potionLabel, "RIGHT", 4, 0)
    statusPotionText:SetText(colorStr("aaaaaa", "—"))

    local noteY = cardTop - 88 - 16
    addDivider(p, noteY)

    local noteText = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    noteText:SetPoint("TOPLEFT", MARGIN, noteY - 12)
    noteText:SetWidth(SCROLL_W - MARGIN * 2)
    noteText:SetJustifyH("LEFT")
    noteText:SetWordWrap(true)
    noteText:SetText(colorStr("aaaaaa",
        "Use the Flask and Potion pages on the left to choose what these macros should cast. " ..
        "See the Changelog page for recent updates."))

    local footerDivY = noteY - 50
    addDivider(p, footerDivY)

    local footer = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer:SetPoint("TOPLEFT", MARGIN, footerDivY - 12)
    footer:SetText(colorStr("888888",
        "Macros: " .. adpm.MACRO_FLASK .. "  /  " .. adpm.MACRO_POTION ..
        "   ·   /adpm help for commands"))

    local optionsDivY = footerDivY - 34
    addDivider(p, optionsDivY)

    addHeader(p, optionsDivY - 12, colorStr("aaaaaa", "Options"))

    adpm.EnsureRestockDefaults()

    local chatCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    chatCB:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, optionsDivY - 34)
    chatCB.Text:SetText("Show chat notification when macros update")
    chatCB:SetChecked(ADPMCharDB.showChatStatus)
    chatCB:SetScript("OnClick", function(self)
        ADPMCharDB.showChatStatus = self:GetChecked()
    end)

    local minimapCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    minimapCB:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, optionsDivY - 58)
    minimapCB.Text:SetText("Hide minimap button")
    minimapCB:SetChecked(ADPMCharDB.minimap.hide)
    minimapCB:SetScript("OnClick", function(self)
        ADPMCharDB.minimap.hide = self:GetChecked()
        adpm.SetMinimapButtonVisible(not ADPMCharDB.minimap.hide)
    end)

    local restockEnableCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    restockEnableCB:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, optionsDivY - 82)
    restockEnableCB.Text:SetText("Enable restock tracking")
    restockEnableCB:SetChecked(ADPMCharDB.restock.enabled)
    restockEnableCB:SetScript("OnClick", function(self)
        ADPMCharDB.restock.enabled = self:GetChecked()
    end)

    local warnCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    warnCB:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, optionsDivY - 106)
    warnCB.Text:SetText("Warn me entering a dungeon or raid while low")
    warnCB:SetChecked(ADPMCharDB.restock.warnOnInstanceEnter)
    warnCB:SetScript("OnClick", function(self)
        ADPMCharDB.restock.warnOnInstanceEnter = self:GetChecked()
    end)

    -- ── Restock ──────────────────────────────────────────────────────────────
    local restockDivY = optionsDivY - 106 - 32
    addDivider(p, restockDivY)
    addHeader(p, restockDivY - 12, colorStr("aaaaaa", "Restock") .. "  " .. colorStr("888888", "(tracks your currently selected Flask + Potion)"))

    local restockNoteY = restockDivY - 30
    local restockNote = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    restockNote:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, restockNoteY)
    restockNote:SetWidth(SCROLL_W - MARGIN * 2 - INDENT)
    restockNote:SetJustifyH("LEFT")
    restockNote:SetWordWrap(true)
    restockNote:SetSpacing(2)
    restockNote:SetText(colorStr("aaaaaa",
        "At the Auction House, low items get a shopping panel with a real Buy button " ..
        "(this spends gold automatically -- double-check the quantity before clicking). " ..
        "A threshold of 0 for whichever mode is active below disables tracking for that " ..
        "item. Max sets how many it buys up to."))

    -- Gap below restockNote is based on its ACTUAL measured height, not a
    -- guessed line count -- guessing here is exactly what caused earlier
    -- versions of this section to overlap once the paragraph wrapped to more
    -- lines than assumed.
    local triggerY = restockNoteY - restockNote:GetStringHeight() - 16
    makeChoiceDropdown(p, INDENT, triggerY, "Restock when below:", 140, 90,
        {
            { value = "min", text = "Min" },
            { value = "max", text = "Max" },
        },
        function() return ADPMCharDB.restock.triggerMode end,
        function(v) ADPMCharDB.restock.triggerMode = v end)

    local triggerNoteY = triggerY - 28 -- dropdown widget's own height
    local triggerNote = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    triggerNote:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, triggerNoteY)
    triggerNote:SetWidth(SCROLL_W - MARGIN * 2 - INDENT)
    triggerNote:SetJustifyH("LEFT")
    triggerNote:SetWordWrap(true)
    triggerNote:SetSpacing(2)
    triggerNote:SetText(colorStr("aaaaaa",
        "Min = only warn when critically low. Max = warn any time you're not fully stocked."))

    local restockRowY = triggerNoteY - triggerNote:GetStringHeight() - 20
    makeThresholdDropdown(p, INDENT, restockRowY, "Flask Min:",
        function() return ADPMCharDB.restock.flaskMin end,
        function(n) ADPMCharDB.restock.flaskMin = n end)
    makeThresholdDropdown(p, INDENT + 170, restockRowY, "Flask Max:",
        function() return ADPMCharDB.restock.flaskMax end,
        function(n) ADPMCharDB.restock.flaskMax = n end)

    local restockRowY2 = restockRowY - 44
    makeThresholdDropdown(p, INDENT, restockRowY2, "Potion Min:",
        function() return ADPMCharDB.restock.potionMin end,
        function(n) ADPMCharDB.restock.potionMin = n end)
    makeThresholdDropdown(p, INDENT + 170, restockRowY2, "Potion Max:",
        function() return ADPMCharDB.restock.potionMax end,
        function(n) ADPMCharDB.restock.potionMax = n end)

    p:SetHeight(MARGIN + math.abs(restockRowY2) + 40)
end

-- ─── Flask page ─────────────────────────────────────────────────────────────
local function buildFlaskPanel(frame)
    local p = makeScrollable(frame)

    addHeader(p, -MARGIN, colorStr("ffcc00", "Flask") .. "  " .. colorStr("aaaaaa", "(choose one — lasts 1 hour)"))

    local fy = -MARGIN - 22
    for _, def in ipairs(adpm.flaskDefs) do
        makeRadio(p, INDENT, fy, "Flask", def.key, def, flaskRadios, adpm.SetSelectedFlask, adpm.GetSelectedFlask)
        fy = fy - ROW_H
    end

    do
        local noneBtn = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
        noneBtn:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, fy)
        local noneLbl = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noneLbl:SetPoint("LEFT", noneBtn, "RIGHT", 4, 0)
        noneLbl:SetText(colorStr("aaaaaa", "None — disable flask macro"))
        noneBtn:SetScript("OnClick", function()
            for _, other in pairs(flaskRadios) do other:SetChecked(false) end
            noneBtn:SetChecked(true)
            adpm.SetSelectedFlask(nil)
            adpm.UpdateMacros()
        end)
        noneBtn:SetChecked(adpm.GetSelectedFlask() == nil)
        flaskRadios["__none"] = noneBtn
        fy = fy - ROW_H
    end

    p:SetHeight(-(fy - 16))
end

-- ─── Potion page ────────────────────────────────────────────────────────────
local function buildPotionPanel(frame)
    local p = makeScrollable(frame)

    addHeader(p, -MARGIN, colorStr("ffcc00", "Potion") .. "  " .. colorStr("aaaaaa", "(choose one — 30s combat pot)"))

    local py = -MARGIN - 22
    for _, def in ipairs(adpm.potionDefs) do
        makeRadio(p, INDENT, py, "Potion", def.key, def, potionRadios, adpm.SetSelectedPotion, adpm.GetSelectedPotion)
        py = py - ROW_H
    end

    do
        local noneBtn = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
        noneBtn:SetPoint("TOPLEFT", p, "TOPLEFT", INDENT, py)
        local noneLbl = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noneLbl:SetPoint("LEFT", noneBtn, "RIGHT", 4, 0)
        noneLbl:SetText(colorStr("aaaaaa", "None — disable potion macro"))
        noneBtn:SetScript("OnClick", function()
            for _, other in pairs(potionRadios) do other:SetChecked(false) end
            noneBtn:SetChecked(true)
            adpm.SetSelectedPotion(nil)
            adpm.UpdateMacros()
        end)
        noneBtn:SetChecked(adpm.GetSelectedPotion() == nil)
        potionRadios["__none"] = noneBtn
        py = py - ROW_H
    end

    p:SetHeight(-(py - 16))
end

-- ─── Changelog page ─────────────────────────────────────────────────────────
local function buildChangelogPanel(frame)
    local p = makeScrollable(frame)

    addHeader(p, -MARGIN, colorStr("ffcc00", "Changelog"))

    local listContent = CreateFrame("Frame", nil, p)
    listContent:SetPoint("TOPLEFT", p, "TOPLEFT", MARGIN, -MARGIN - 26)
    listContent:SetWidth(SCROLL_W - MARGIN * 2)
    local listHeight = adpm.BuildChangelogList(listContent, SCROLL_W - MARGIN * 2)

    p:SetHeight(MARGIN + 26 + listHeight + 16)
end

-- ─── Registration ───────────────────────────────────────────────────────────
local function buildPanel()
    local mainFrame = CreateFrame("Frame")
    mainFrame.name = "Auto DPS Pot Macro"
    buildGeneralPanel(mainFrame)

    local category = Settings.RegisterCanvasLayoutCategory(mainFrame, "Auto DPS Pot Macro")
    Settings.RegisterAddOnCategory(category)
    adpm.adpmCategoryID = category:GetID()

    local flaskFrame = CreateFrame("Frame")
    flaskFrame.name = "Flask"
    buildFlaskPanel(flaskFrame)
    Settings.RegisterCanvasLayoutSubcategory(category, flaskFrame, "Flask")

    local potionFrame = CreateFrame("Frame")
    potionFrame.name = "Potion"
    buildPotionPanel(potionFrame)
    Settings.RegisterCanvasLayoutSubcategory(category, potionFrame, "Potion")

    local changelogFrame = CreateFrame("Frame")
    changelogFrame.name = "Changelog"
    buildChangelogPanel(changelogFrame)
    local changelogCategory = Settings.RegisterCanvasLayoutSubcategory(category, changelogFrame, "Changelog")
    adpm.adpmChangelogCategoryID = changelogCategory:GetID()

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
