-- Core\Restock.lua
-- Lets the user set min/max stock targets for their CURRENTLY SELECTED Flask and Potion.
-- - Warns with a popup when entering a dungeon/raid below the minimum.
-- - At the Auction House, shows a shopping panel with live prices and real
--   one-click Buy buttons for whichever tracked item is low (see the big
--   comment above the Auction House section below for how/why that works).

local addonName, adpm = ...

--- Makes sure ADPMCharDB.restock exists with sane defaults. Safe to call repeatedly.
function adpm.EnsureRestockDefaults()
    ADPMCharDB.restock = ADPMCharDB.restock or {}
    local r = ADPMCharDB.restock
    if r.enabled == nil then r.enabled = false end
    r.flaskMin  = r.flaskMin  or 0
    r.flaskMax  = r.flaskMax  or 0
    r.potionMin = r.potionMin or 0
    r.potionMax = r.potionMax or 0
    -- "min": alert once you're critically low (below Min).
    -- "max": alert any time you're not fully stocked (below Max) -- keeps
    -- you topped off rather than waiting until you're nearly out.
    r.triggerMode = r.triggerMode or "min"
    -- Separate from the master "enabled" switch: lets you keep the AH
    -- shopping panel without the dungeon/raid entry popup, if that's all
    -- you want turned off.
    if r.warnOnInstanceEnter == nil then r.warnOnInstanceEnter = true end
end

--- Sums the count of every owned crafted/fleeting item for a flask or potion def.
local function sumOwnedCount(def)
    if not def then return 0 end
    local total = 0
    for _, id in ipairs(def.craftedIDs or {}) do
        local item = adpm.items[id]
        if item then total = total + item:GetCount() end
    end
    for _, id in ipairs(def.fleetingIDs or {}) do
        local item = adpm.items[id]
        if item then total = total + item:GetCount() end
    end
    return total
end

--- Whether a count counts as "low" under the current trigger mode: below Min
--- (the conservative default) or below Max (aggressive, keeps you topped off).
--- A threshold of 0 means "not tracking this item" regardless of mode.
local function isBelowTrigger(count, min, max, mode)
    if mode == "max" then
        return max > 0 and count < max
    end
    return min > 0 and count < min
end

--- Returns a status table describing current stock vs thresholds for whatever
--- flask/potion is currently selected. Only "low" flags are true when restock
--- tracking is enabled AND the relevant threshold is set AND an item is
--- actually selected.
function adpm.GetRestockStatus()
    adpm.EnsureRestockDefaults()
    local r = ADPMCharDB.restock

    local flaskDef  = adpm.GetSelectedFlask()  and adpm.GetFlaskDef(adpm.GetSelectedFlask())
    local potionDef = adpm.GetSelectedPotion() and adpm.GetPotionDef(adpm.GetSelectedPotion())

    local flaskCount  = sumOwnedCount(flaskDef)
    local potionCount = sumOwnedCount(potionDef)

    return {
        enabled     = r.enabled,
        triggerMode = r.triggerMode,
        flaskDef    = flaskDef,
        flaskCount  = flaskCount,
        flaskMin    = r.flaskMin,
        flaskMax    = r.flaskMax,
        flaskLow    = r.enabled and flaskDef  ~= nil and isBelowTrigger(flaskCount,  r.flaskMin,  r.flaskMax,  r.triggerMode),
        potionDef   = potionDef,
        potionCount = potionCount,
        potionMin   = r.potionMin,
        potionMax   = r.potionMax,
        potionLow   = r.enabled and potionDef ~= nil and isBelowTrigger(potionCount, r.potionMin, r.potionMax, r.triggerMode),
    }
end

-- ─── Instance-entry popup ───────────────────────────────────────────────────
StaticPopupDialogs["ADPM_RESTOCK_LOW"] = {
    text          = "%s",
    button1       = OKAY or "Okay",
    timeout       = 0,
    whileDead     = true,
    hideOnEscape  = true,
    showAlert     = true,
    preferredIndex = 3,
}

local function buildLowStockMessage(status)
    local thresholdLabel = status.triggerMode == "max" and "max" or "min"
    local lines = {}
    if status.flaskLow then
        local threshold = status.triggerMode == "max" and status.flaskMax or status.flaskMin
        table.insert(lines, string.format(
            "|cffff4444Low on %s|r  (%d / %s %d)",
            status.flaskDef.label, status.flaskCount, thresholdLabel, threshold))
    end
    if status.potionLow then
        local threshold = status.triggerMode == "max" and status.potionMax or status.potionMin
        table.insert(lines, string.format(
            "|cffff4444Low on %s|r  (%d / %s %d)",
            status.potionDef.label, status.potionCount, thresholdLabel, threshold))
    end
    return table.concat(lines, "\n")
end

--- Checks stock and, if anything tracked is below its minimum, pops a warning.
--- Meant to be called shortly after entering a dungeon/raid instance.
function adpm.CheckRestockOnInstanceEnter()
    adpm.EnsureRestockDefaults()
    if not ADPMCharDB.restock.warnOnInstanceEnter then return end

    local status = adpm.GetRestockStatus()
    if not status.enabled then return end
    if not (status.flaskLow or status.potionLow) then return end

    StaticPopup_Show("ADPM_RESTOCK_LOW", buildLowStockMessage(status))
end

-- ─── Auction House assist ───────────────────────────────────────────────────
-- Floats a small shopping panel while the AH is open, for whichever tracked
-- item(s) are below their minimum: icon, Have, editable Qty, live unit price,
-- and a real Buy button per row.
--
-- The Buy buttons are plain buttons. C_AuctionHouse.StartCommoditiesPurchase
-- and ConfirmCommoditiesPurchase just need to be called from inside a real
-- OnClick handler -- that's what makes the click "hardware-triggered" as far
-- as WoW's protected-function rules care. No secure/protected button template
-- is required for that. Confirm fires once AUCTION_HOUSE_THROTTLED_SYSTEM_READY
-- comes in, since that's the actual signal the client uses to say the pending
-- transaction is ready to finalize.
--
-- "Purchase All" still can't clear two different items in a single click: the
-- Start -> wait-for-ready -> Confirm cycle has to fully resolve before a
-- second Start call is allowed, and that resolution happens inside an event
-- callback rather than inside the original click -- so a second item's Start
-- would need to originate from a click that never happened. The button buys
-- whichever item is next and simply relabels itself for the one after that.

local commodityPriceOf = {} -- itemID -> unitPrice in copper, or false once we've
                             -- confirmed nothing is listed

-- We only ever have two possible items to price (the selected Flask and
-- Potion), so rather than a general job queue, one "which item are we
-- currently waiting on" slot is enough. A request is only ever sent when
-- nothing else is outstanding; the natural retrigger from a rebuild after
-- every price result (see finishPriceLookup below) is what lets the second
-- item's request go out once the first one resolves.
local priceLookupItemID = nil

local function startPriceLookup(itemID)
    if not itemID then return end
    if commodityPriceOf[itemID] ~= nil then return end -- already resolved
    if priceLookupItemID then return end                -- something else outstanding
    if not (C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady
        and C_AuctionHouse.IsThrottledMessageSystemReady()) then
        return -- the throttle-ready event below will nudge this along
    end

    priceLookupItemID = itemID
    C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), {}, false)

    -- If nothing ever comes back (dropped packet, whatever), don't leave the
    -- slot stuck forever -- free it so a later rebuild can try again.
    C_Timer.After(5, function()
        if priceLookupItemID == itemID then
            priceLookupItemID = nil
        end
    end)
end

local function finishPriceLookup(itemID)
    if priceLookupItemID == itemID then
        priceLookupItemID = nil
    end

    local cheapest
    for i = 1, (C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0) do
        local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if result and result.unitPrice and (not cheapest or result.unitPrice < cheapest) then
            cheapest = result.unitPrice
        end
    end
    commodityPriceOf[itemID] = cheapest or false

    -- Rebuilding here is what lets the OTHER tracked item's price go out next,
    -- since startPriceLookup only sends when the slot above is free. It can't
    -- loop back on itself: this item is now cached, so a fresh call for it
    -- is a no-op.
    adpm.CheckRestockAtAH()
end

--- The item this addon will actually try to buy for a def -- the lowest
--- crafted tier. Fleeting versions come from an Alchemist's cauldron rather
--- than being sold individually, so they aren't a sensible AH purchase target.
local function cheapestBuyableID(def)
    return def and def.craftedIDs and def.craftedIDs[1]
end

local function shortfallQty(count, min, max)
    local target = (max and max > 0) and max or min
    local need = (target or 0) - count
    return need < 1 and 1 or need
end

-- ─── Purchasing ──────────────────────────────────────────────────────────────
-- Only ever call this from inside a button's OnClick -- the underlying API
-- needs the call to trace back to a real click, and won't do anything useful
-- triggered from a timer or any other code path.
local confirmWaiter -- one frame, reused for every purchase rather than created fresh each time
local buyInFlight = false -- the AH allows exactly one open commodity transaction;
                           -- this also blocks a double-click from starting a second

-- Auction House commodity purchases deliver to the MAILBOX, not bags -- the
-- owned-item count this addon reads will NOT reflect a purchase until the
-- player actually collects that mail, which typically doesn't happen during
-- the same AH visit. A timer-based "wait for the count to catch up" approach
-- doesn't work here: the count simply isn't going to change while the AH is
-- still open, so once bought, an item is excluded from the shopping list for
-- the rest of this AH session (cleared when the AH closes) rather than on any
-- guessed delay -- otherwise Purchase All would happily re-buy it again once
-- a timer expired, since "low" would still be true by every count we can see.
local purchasedThisSession = {} -- itemID -> true once bought this AH visit

local function buyCommodity(itemID, quantity)
    if buyInFlight then return end
    if not (itemID and quantity and quantity > 0) then return end
    if not (C_AuctionHouse and C_AuctionHouse.StartCommoditiesPurchase) then return end

    C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity)
    buyInFlight = true

    confirmWaiter = confirmWaiter or CreateFrame("Frame")
    confirmWaiter:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    confirmWaiter:SetScript("OnEvent", function(self)
        C_AuctionHouse.ConfirmCommoditiesPurchase(itemID, quantity)
        self:UnregisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
        buyInFlight = false
        purchasedThisSession[itemID] = true
        -- Not waiting on bag data here -- purchasedThisSession is what keeps
        -- this item out of the list from now on. This just lets the panel
        -- (Total cost, remaining rows) redraw with it gone.
        C_Timer.After(1, adpm.CheckRestockAtAH)
    end)
end

-- ─── Panel ───────────────────────────────────────────────────────────────────
local ahPanel

--- A small flat button matching this addon's own visual style (dark backdrop,
--- thin colored border) instead of Blizzard's default red stone button --
--- consistent with how buttons are built elsewhere in this addon rather than
--- reusing UIPanelButtonTemplate's stock skin.
local function makeFlatButton(parent, width, height, label, r, g, b)
    r, g, b = r or 1, g or 0.4, b or 0.4

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(r * 0.18, g * 0.08, b * 0.08, 0.9)
    btn:SetBackdropBorderColor(r, g, b, 0.9)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(r * 0.32, g * 0.14, b * 0.14, 0.95)
        self:SetBackdropBorderColor(math.min(r + 0.2, 1), math.min(g + 0.2, 1), math.min(b + 0.2, 1), 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(r * 0.18, g * 0.08, b * 0.08, 0.9)
        self:SetBackdropBorderColor(r, g, b, 0.9)
    end)

    -- Overrides the default so existing call sites (SetText/SetEnabled) keep
    -- working unchanged even though this isn't a stock-templated button.
    btn.SetText = function(self, txt) self.text:SetText(txt) end
    btn.SetEnabled = function(self, enabled)
        if enabled then
            self:Enable()
            self.text:SetTextColor(1, 1, 1)
        else
            self:Disable()
            self.text:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    if label then btn:SetText(label) end
    return btn
end

--- Thin gold-tinted frame around an icon texture, matching the bordered-icon
--- look used on the General settings page.
local function addIconBorder(icon)
    local border = icon:GetParent():CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Common\\WhiteIconFrame")
    border:SetSize(icon:GetWidth() + 6, icon:GetHeight() + 6)
    border:SetPoint("CENTER", icon, "CENTER", 0, 0)
    border:SetVertexColor(1, 0.82, 0, 0.9)
    return border
end

local function addRowDivider(parent, x, y, width)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetSize(width, 1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return line
end

-- Shared layout constants so the divider lines, rows, and panel width all
-- agree on the same content area instead of using independently-guessed
-- numbers that can drift out of alignment with each other.
local PANEL_W  = 230
local MARGIN   = 14
local ROW_W    = PANEL_W - MARGIN * 2 -- 202
local ROW_H    = 100

local function newShoppingRow(parent)
    local row = {}
    row.frame = CreateFrame("Frame", nil, parent)
    row.frame:SetSize(ROW_W, ROW_H)

    row.icon = row.frame:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 2, -2)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    addIconBorder(row.icon)

    -- Name/Have/Price stack purely downward from each other (TOPLEFT ->
    -- BOTTOMLEFT chaining), so if the name wraps to a second line everything
    -- below it shifts down automatically instead of using a fixed y-offset
    -- that assumed a single line and silently collided when it wrapped.
    row.name = row.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
    row.name:SetWidth(150) -- plenty of room: nothing else shares this space anymore
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(true)

    row.haveText = row.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.haveText:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)

    row.priceText = row.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.priceText:SetPoint("TOPLEFT", row.haveText, "BOTTOMLEFT", 0, -3)

    -- Qty + Buy live on their own row pinned to the BOTTOM of the row frame,
    -- entirely separate from the icon/name/price block above -- so a long or
    -- wrapped item name can never crowd the button again.
    row.qtyLabel = row.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.qtyLabel:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 2, 2)
    row.qtyLabel:SetText("|cffaaaaaaQty:|r")

    row.qtyBox = CreateFrame("EditBox", nil, row.frame, "InputBoxTemplate")
    row.qtyBox:SetSize(40, 18)
    row.qtyBox:SetPoint("LEFT", row.qtyLabel, "RIGHT", 4, 0)
    row.qtyBox:SetAutoFocus(false)
    row.qtyBox:SetNumeric(true)
    row.qtyBox:SetMaxLetters(4)
    row.qtyBox:SetJustifyH("CENTER")

    row.buyBtn = makeFlatButton(row.frame, 64, 22, "Buy")
    row.buyBtn:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMRIGHT", 0, 0)

    return row
end

local function buildAHPanel()
    if ahPanel then return ahPanel end

    -- No longer anchored to AuctionHouseFrame's edge at all -- if the AH
    -- window is large/centered with no side margin (or another addon has
    -- already claimed whatever margin exists), docking beside it just isn't
    -- reliable. This floats independently on UIParent instead, remembers
    -- wherever the player drags it to, and doesn't depend on the AH window's
    -- size or position at all.
    local f = CreateFrame("Frame", "ADPMRestockPanel", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG") -- above most normal addon UI, so it isn't
                                -- rendered underneath something else's panel
    f:SetClampedToScreen(true) -- can't be dragged (or default-positioned) off-screen
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ADPMCharDB.restock = ADPMCharDB.restock or {}
        ADPMCharDB.restock.panelPoint = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    adpm.EnsureRestockDefaults()
    local saved = ADPMCharDB.restock.panelPoint
    if saved then
        f:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    else
        -- First-ever appearance: park it in a screen corner well clear of
        -- the AH window itself, rather than guessing at AH-relative space
        -- that may not exist. The player can drag it wherever suits them
        -- from here on; that choice is what gets remembered above.
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -220)
    end

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.94)
    f:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    f:Hide()

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", MARGIN, -10)
    f.title:SetText("|cffffcc00Restock|r  |cffaaaaaa(drag to move)|r")

    -- Every vertical offset below is computed explicitly from the one before
    -- it, rather than guessed independently, so nothing can silently drift
    -- out of alignment with anything else the way the old fixed offsets did.
    local headerDivY = -28
    addRowDivider(f, MARGIN, headerDivY, ROW_W)

    local row1Y = headerDivY - 8
    f.rows = { newShoppingRow(f), newShoppingRow(f) }
    f.rows[1].frame:SetPoint("TOPLEFT", f, "TOPLEFT", MARGIN, row1Y)

    local rowDivY = row1Y - ROW_H - 6
    addRowDivider(f, MARGIN, rowDivY, ROW_W)

    local row2Y = rowDivY - 8
    f.rows[2].frame:SetPoint("TOPLEFT", f, "TOPLEFT", MARGIN, row2Y)

    local totalDivY = row2Y - ROW_H - 6
    addRowDivider(f, MARGIN, totalDivY, ROW_W)

    local totalY = totalDivY - 10
    f.totalText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.totalText:SetPoint("TOPLEFT", f, "TOPLEFT", MARGIN, totalY)

    local purchaseAllY = totalY - 22
    f.purchaseAllBtn = makeFlatButton(f, ROW_W, 24, nil, 1, 0.82, 0)
    f.purchaseAllBtn:SetPoint("TOPLEFT", f, "TOPLEFT", MARGIN, purchaseAllY)

    f:SetSize(PANEL_W, math.abs(purchaseAllY) + 24 + MARGIN)

    ahPanel = f
    return f
end

--- Rebuilds the panel from current restock status: which rows show, their
--- Have/Qty/Price, and the Buy buttons (row-level and Purchase All, which
--- always targets whichever tracked item is still low first).
function adpm.CheckRestockAtAH()
    local status = adpm.GetRestockStatus()
    if not status.enabled or not (status.flaskLow or status.potionLow) then
        if ahPanel then ahPanel:Hide() end
        return
    end

    local f = buildAHPanel()
    if not f then return end

    local function wasAlreadyPurchased(def)
        local itemID = cheapestBuyableID(def)
        return itemID and purchasedThisSession[itemID]
    end

    local shoppingList = {}
    if status.flaskLow and not wasAlreadyPurchased(status.flaskDef) then
        table.insert(shoppingList, {
            def = status.flaskDef, count = status.flaskCount,
            min = status.flaskMin, max = status.flaskMax, kind = "Flask",
        })
    end
    if status.potionLow and not wasAlreadyPurchased(status.potionDef) then
        table.insert(shoppingList, {
            def = status.potionDef, count = status.potionCount,
            min = status.potionMin, max = status.potionMax, kind = "Potion",
        })
    end

    local totalCopper, gotAnyPrice = 0, false

    for i, row in ipairs(f.rows) do
        local entry = shoppingList[i]
        if not entry then
            row.frame:Hide()
        else
            row.frame:Show()
            local itemID = cheapestBuyableID(entry.def)
            local suggestedQty = shortfallQty(entry.count, entry.min, entry.max)

            local pItem = itemID and adpm.items[itemID]
            if pItem then row.icon:SetTexture(pItem:GetIcon()) end
            row.name:SetText(entry.def.label)
            local thresholdLabel = status.triggerMode == "max" and "Max" or "Min"
            local threshold = status.triggerMode == "max" and entry.max or entry.min
            row.haveText:SetText(string.format("|cffaaaaaaHave:|r %d  |cffaaaaaa%s:|r %d", entry.count, thresholdLabel, threshold))

            -- Reset the qty box to the suggested value only when this row is
            -- showing a different item, or the player hasn't typed into it
            -- yet -- once they have, a background price tick shouldn't erase
            -- what they entered.
            if row.lastItemID ~= itemID then
                row.lastItemID = itemID
                row.userEdited = false
                row.qtyBox:SetText(tostring(suggestedQty))
            elseif not row.userEdited then
                row.qtyBox:SetText(tostring(suggestedQty))
            end
            row.qtyBox:SetScript("OnEditFocusGained", function() row.userEdited = true end)
            row.qtyBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

            local qtyForTotal = tonumber(row.qtyBox:GetText()) or suggestedQty
            startPriceLookup(itemID)
            local unitPrice = commodityPriceOf[itemID]
            if unitPrice then
                row.priceText:SetText(GetCoinTextureString(unitPrice) .. " ea")
                totalCopper = totalCopper + (unitPrice * qtyForTotal)
                gotAnyPrice = true
            else
                row.priceText:SetText("|cffaaaaaaprice loading...|r")
            end

            local rowBox, rowItemID = row.qtyBox, itemID
            row.buyBtn:SetScript("OnClick", function()
                -- Read the box's text at the moment of the click itself, not
                -- a value captured back when the panel last rebuilt -- what's
                -- on screen right now is exactly what gets purchased.
                buyCommodity(rowItemID, tonumber(rowBox:GetText()))
            end)
        end
    end

    if #shoppingList == 0 then
        f:Hide()
        return
    end

    if gotAnyPrice then
        f.totalText:SetText("Total: " .. GetCoinTextureString(totalCopper))
    else
        f.totalText:SetText("|cffaaaaaaTotal: pricing...|r")
    end

    -- Purchase All targets the first entry still on the list. Once that
    -- purchase's confirm handler fires, CheckRestockAtAH runs again and the
    -- list shrinks, so this naturally re-arms for whatever's left. It reads
    -- the same box as that row's own Buy button, so the two can never
    -- disagree about what quantity a click will buy.
    local firstEntry = shoppingList[1]
    local firstItemID = cheapestBuyableID(firstEntry.def)
    local firstRowBox = f.rows[1].qtyBox
    f.purchaseAllBtn:SetText(#shoppingList > 1
        and ("Buy " .. firstEntry.kind .. " (1 of " .. #shoppingList .. ")")
        or ("Buy " .. firstEntry.kind))
    f.purchaseAllBtn:SetScript("OnClick", function()
        buyCommodity(firstItemID, tonumber(firstRowBox:GetText()))
    end)

    f:Show()
end

function adpm.HideRestockAHPanel()
    if ahPanel then ahPanel:Hide() end
    wipe(commodityPriceOf)
    priceLookupItemID = nil
    wipe(purchasedThisSession)
end

--- Diagnostic only: reports the AH panel's internal state without touching
--- it, for /adpm ahtest to print to chat.
function adpm.DebugRestockAHState()
    local info = {
        auctionHouseFrameExists = AuctionHouseFrame ~= nil,
        panelExists = ahPanel ~= nil,
        panelShown  = ahPanel ~= nil and ahPanel:IsShown() or false,
        panelParent = ahPanel and ahPanel:GetParent() and ahPanel:GetParent():GetName() or "n/a",
        screenWidth  = GetScreenWidth and math.floor(GetScreenWidth()) or -1,
        screenHeight = GetScreenHeight and math.floor(GetScreenHeight()) or -1,
    }

    if ahPanel then
        info.strata = ahPanel:GetFrameStrata()
        info.level  = ahPanel:GetFrameLevel()
        -- These are in the same UI-coordinate space as GetScreenWidth/Height
        -- above -- if left/right fall outside [0, screenWidth] (or top/bottom
        -- outside [0, screenHeight]), the panel is genuinely off-screen
        -- regardless of what :IsShown() says.
        info.left   = ahPanel:GetLeft()   and math.floor(ahPanel:GetLeft())
        info.right  = ahPanel:GetRight()  and math.floor(ahPanel:GetRight())
        info.top    = ahPanel:GetTop()    and math.floor(ahPanel:GetTop())
        info.bottom = ahPanel:GetBottom() and math.floor(ahPanel:GetBottom())
    end

    if AuctionHouseFrame then
        info.ahStrata = AuctionHouseFrame:GetFrameStrata()
        info.ahRight  = AuctionHouseFrame:GetRight() and math.floor(AuctionHouseFrame:GetRight())
    end

    return info
end

-- ─── Event wiring (self-contained) ──────────────────────────────────────────
local wasInInstance = false

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evtFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
evtFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
evtFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
evtFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")

evtFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "AUCTION_HOUSE_SHOW" then
        adpm.CheckRestockAtAH()
        -- AuctionHouseFrame can occasionally not be fully ready the instant
        -- this event fires (e.g. very first AH open of a session); retry
        -- once shortly after as a safety net.
        C_Timer.After(0.5, adpm.CheckRestockAtAH)
        return
    end
    if event == "AUCTION_HOUSE_CLOSED" then
        adpm.HideRestockAHPanel()
        return
    end
    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        finishPriceLookup(arg1)
        return
    end
    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        -- Nudges a stalled price lookup along; buyCommodity's own confirmWaiter
        -- frame listens for this same event separately for the purchase side.
        adpm.CheckRestockAtAH()
        return
    end

    -- ZONE_CHANGED_NEW_AREA / PLAYER_ENTERING_WORLD: detect *entering* a dungeon/raid
    -- (transition from "not in one" to "in one"), not every subzone change inside it.
    local inInstance, instanceType = IsInInstance()
    local isDungeonOrRaid = inInstance and (instanceType == "party" or instanceType == "raid")

    if isDungeonOrRaid and not wasInInstance then
        -- Give bag/item data a moment to settle after the loading screen.
        C_Timer.After(1.5, adpm.CheckRestockOnInstanceEnter)
    end
    wasInInstance = isDungeonOrRaid
end)
