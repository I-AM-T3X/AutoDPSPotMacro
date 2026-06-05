-- UI\Changelog.lua
-- Shows a changelog popup once per version (account-wide, via ADPMDB).
-- To add notes for a future version, add an entry to CHANGELOG below.

local addonName, adpm = ...

-- ─── Changelog data ───────────────────────────────────────────────────────────
-- Add newest entry at the TOP. Each entry: { version, lines[] }
local CHANGELOG = {
    {
        version = "1.0.5",
        lines = {
            { text = "Per-specialization profiles",                                          tag = "new" },
            { text = "Flask and potion selections now save separately for each spec.",       tag = nil  },
            { text = "Swapping specs automatically switches your macros.",                   tag = nil  },
            { text = "Fix: Minimap toggle slash command now works correctly.",               tag = "fix" },
        },
    },
    {
        version = "1.0.4",
        lines = {
            { text = "Combat-safe fallback macros",                                          tag = "new" },
            { text = "Macros now include all owned quality tiers as fallbacks.",             tag = nil  },
            { text = "If you run out of Gold pots mid-pull, Silver kicks in automatically.", tag = nil  },
        },
    },
}

-- ─── Colours ──────────────────────────────────────────────────────────────────
local C_TITLE   = "00ccff"
local C_VERSION = "ffcc00"
local C_NEW     = "44ff88"
local C_FIX     = "ff9944"
local C_BODY    = "dddddd"
local C_DIM     = "888888"

local function col(hex, t) return "|cff"..hex..t.."|r" end

-- ─── Layout constants ─────────────────────────────────────────────────────────
local FRAME_W  = 440
local FRAME_H  = 360
local PAD      = 16
local CONTENT_W = FRAME_W - PAD * 2 - 20  -- 20 for scrollbar

-- ─── Frame (built once) ───────────────────────────────────────────────────────
local popup

local function buildPopup()
    -- Root: use the high-quality ButtonFrameTemplate which gives us the
    -- Dragonflight/Midnight styled stone border + proper opaque background.
    popup = CreateFrame("Frame", "ADPMChangelogFrame", UIParent, "ButtonFrameTemplate")
    popup:SetSize(FRAME_W, FRAME_H)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop",  popup.StopMovingOrSizing)
    popup:Hide()

    -- Set the portrait icon using SetPortraitToTexture if available,
    -- otherwise manually texture the portrait frame.
    if popup.PortraitContainer then
        local portrait = _G[popup:GetName() .. "Portrait"]
        if portrait then
            portrait:SetTexture("Interface\\Icons\\INV_Alchemy_Potion_05")
        else
            -- Fallback: create a texture directly in the container
            local tex = popup.PortraitContainer:CreateTexture(nil, "ARTWORK")
            tex:SetTexture("Interface\\Icons\\INV_Alchemy_Potion_05")
            tex:SetPoint("CENTER", popup.PortraitContainer, "CENTER", 0, 0)
            tex:SetSize(60, 60)
        end
    end
    popup.TitleContainer.TitleText:SetText(col(C_TITLE, "Auto DPS Pot Macro") .. "  —  What's New")

    -- Wire the built-in X button to dismiss + save seen version
    popup.CloseButton:SetScript("OnClick", function()
        if not ADPMDB then ADPMDB = {} end
        ADPMDB.lastSeenVersion = adpm.VERSION
        popup:Hide()
    end)

    -- ── Scroll frame ──────────────────────────────────────────────────────────
    local sf = CreateFrame("ScrollFrame", "ADPMChangelogScroll", popup, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     popup.Inset, "TOPLEFT",     8,    -8)
    sf:SetPoint("BOTTOMRIGHT", popup.Inset, "BOTTOMRIGHT", -(8+20), 8)

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(CONTENT_W)
    sf:SetScrollChild(content)

    -- ── Populate ──────────────────────────────────────────────────────────────
    local y = -4
    for i, entry in ipairs(CHANGELOG) do
        -- Version header
        local vfs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        vfs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        vfs:SetText(col(C_VERSION, "Version " .. entry.version))
        y = y - 24

        for _, line in ipairs(entry.lines) do
            local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetWidth(CONTENT_W - 8)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)

            local prefix = ""
            if line.tag == "new" then
                prefix = col(C_NEW,  "[New] ")
            elseif line.tag == "fix" then
                prefix = col(C_FIX,  "[Fix] ")
            end

            fs:SetText(prefix .. col(C_BODY, line.text))
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", line.tag and 0 or 12, y)

            -- measure height after setting text+width
            fs:SetSpacing(2)
            y = y - fs:GetStringHeight() - 6
        end

        -- Divider between versions (skip after last)
        if i < #CHANGELOG then
            y = y - 6
            local div = content:CreateTexture(nil, "ARTWORK")
            div:SetColorTexture(0.4, 0.35, 0.1, 0.6)   -- subtle gold rule
            div:SetSize(CONTENT_W, 1)
            div:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            y = y - 14
        end
    end

    content:SetHeight(math.abs(y) + 16)

    -- ── Bottom buttons ────────────────────────────────────────────────────────
    -- Sit in the grey footer strip below popup.Inset, centered on the frame.
    local gotItBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    gotItBtn:SetSize(120, 26)
    gotItBtn:SetPoint("CENTER", popup, "BOTTOM", 64, 14)    gotItBtn:SetText("Got it!")
    gotItBtn:SetScript("OnClick", function()
        if not ADPMDB then ADPMDB = {} end
        ADPMDB.lastSeenVersion = adpm.VERSION
        popup:Hide()
    end)

    local optBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    optBtn:SetSize(120, 26)
    optBtn:SetPoint("CENTER", popup, "BOTTOM", -64, 14)
    optBtn:SetText("Open Options")
    optBtn:SetScript("OnClick", function()
        if not ADPMDB then ADPMDB = {} end
        ADPMDB.lastSeenVersion = adpm.VERSION
        popup:Hide()
        Settings.OpenToCategory(adpm.adpmCategoryID)
    end)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

function adpm.ShowChangelogIfNew()
    if not ADPMDB then ADPMDB = {} end
    if ADPMDB.lastSeenVersion == adpm.VERSION then return end
    if not popup then buildPopup() end
    popup:Show()
end

function adpm.ShowChangelog()
    if not popup then buildPopup() end
    popup:Show()
end
