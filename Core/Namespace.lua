-- Core\Namespace.lua
-- Defines the single addon namespace table (adpm).
-- All other files receive this via `local addonName, adpm = ...`
-- Nothing is written to _G except ADPMDB (SavedVariables).

local addonName, adpm = ...

adpm.VERSION      = "1.0.0"
adpm.ADDON_NAME   = addonName
adpm.MACRO_POTION = "ADPMPot"
adpm.MACRO_FLASK  = "ADPMFlask"

-- Runtime state
adpm.activePotionID = nil
adpm.activeFlaskID  = nil
adpm.inCombat       = false
adpm.updatePending  = false

-- Will be populated by Items.lua, Flasks.lua, Potions.lua
adpm.items     = {}   -- [itemID] = PPItem
adpm.flaskDefs = {}   -- ordered array of flask group definitions
adpm.potionDefs = {}  -- ordered array of potion group definitions

-- Default saved-variable structure (applied once on first load)
adpm.DB_DEFAULTS = {
    selectedFlask  = nil,   -- settingsKey string or nil for "none"
    selectedPotion = nil,
    showChatStatus = true,
    -- LibDBIcon-1.0 uses a 'minimap' table for position/visibility
    minimap = {
        hide = false,       -- button hidden
        minimapPos = 220,   -- angle around minimap
    },
}

--- Merges defaults into ADPMDB without overwriting existing values.
function adpm.InitDB()
    if not ADPMDB then ADPMDB = {} end
    for k, v in pairs(adpm.DB_DEFAULTS) do
        if ADPMDB[k] == nil then
            ADPMDB[k] = v
        end
    end
    -- Ensure minimap sub-table exists (for upgrades from old version)
    if type(ADPMDB.minimap) ~= "table" then
        -- Migrate old single values if present
        local oldHidden = ADPMDB.minimapHidden
        local oldAngle = ADPMDB.minimapAngle
        ADPMDB.minimap = {
            hide = oldHidden or false,
            minimapPos = oldAngle or 220,
        }
        ADPMDB.minimapHidden = nil
        ADPMDB.minimapAngle = nil
    end
end