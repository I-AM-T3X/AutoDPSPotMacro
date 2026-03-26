-- Core\Namespace.lua
-- Defines the single addon namespace table (adpm).
-- All other files receive this via `local addonName, adpm = ...`
-- Uses CHARACTER SPECIFIC saved variables (ADPMCharDB).

local addonName, adpm = ...

adpm.VERSION      = "1.0.1"
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

-- Default saved-variable structure (applied once on first load per character)
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

--- Merges defaults into ADPMCharDB without overwriting existing values.
function adpm.InitDB()
    if not ADPMCharDB then ADPMCharDB = {} end
    for k, v in pairs(adpm.DB_DEFAULTS) do
        if ADPMCharDB[k] == nil then
            ADPMCharDB[k] = v
        end
    end
    -- Ensure minimap sub-table exists (for upgrades from old version)
    if type(ADPMCharDB.minimap) ~= "table" then
        -- Migrate old single values if present
        local oldHidden = ADPMCharDB.minimapHidden
        local oldAngle = ADPMCharDB.minimapAngle
        ADPMCharDB.minimap = {
            hide = oldHidden or false,
            minimapPos = oldAngle or 220,
        }
        ADPMCharDB.minimapHidden = nil
        ADPMCharDB.minimapAngle = nil
    end
end