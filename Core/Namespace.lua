-- Core\Namespace.lua
-- Defines the single addon namespace table (adpm).
-- All other files receive this via `local addonName, adpm = ...`
-- Uses CHARACTER SPECIFIC saved variables (ADPMCharDB).

local addonName, adpm = ...

adpm.VERSION      = "1.0.5"
adpm.ADDON_NAME   = addonName
adpm.MACRO_POTION = "ADPMPot"
adpm.MACRO_FLASK  = "ADPMFlask"

-- Runtime state
adpm.activePotionID = nil
adpm.activeFlaskID  = nil
adpm.inCombat       = false
adpm.updatePending  = false
adpm.activeSpecID   = nil   -- current spec ID (number), set on login/spec change

-- Will be populated by Items.lua, Flasks.lua, Potions.lua
adpm.items     = {}   -- [itemID] = PPItem
adpm.flaskDefs = {}   -- ordered array of flask group definitions
adpm.potionDefs = {}  -- ordered array of potion group definitions

-- Default saved-variable structure (applied once on first load per character)
adpm.DB_DEFAULTS = {
    specProfiles   = {},    -- [specID] = { selectedFlask, selectedPotion }
    showChatStatus = true,
    -- LibDBIcon-1.0 uses a 'minimap' table for position/visibility
    minimap = {
        hide = false,       -- button hidden
        minimapPos = 220,   -- angle around minimap
    },
}

--- Returns the profile table for the given specID, creating it if needed.
local function getOrCreateProfile(specID)
    if type(ADPMCharDB.specProfiles) ~= "table" then
        ADPMCharDB.specProfiles = {}
    end
    if not ADPMCharDB.specProfiles[specID] then
        ADPMCharDB.specProfiles[specID] = {
            selectedFlask  = nil,
            selectedPotion = nil,
        }
    end
    return ADPMCharDB.specProfiles[specID]
end

--- Returns the active spec's profile table (never nil).
function adpm.GetActiveProfile()
    local id = adpm.activeSpecID or 0
    return getOrCreateProfile(id)
end

--- Convenience getters/setters that mirror the old ADPMCharDB.selectedFlask API.
function adpm.GetSelectedFlask()
    return adpm.GetActiveProfile().selectedFlask
end

function adpm.GetSelectedPotion()
    return adpm.GetActiveProfile().selectedPotion
end

function adpm.SetSelectedFlask(key)
    adpm.GetActiveProfile().selectedFlask = key
end

function adpm.SetSelectedPotion(key)
    adpm.GetActiveProfile().selectedPotion = key
end

--- Called on login and spec change to cache the current spec ID.
--- Returns true if the spec actually changed.
function adpm.RefreshActiveSpec()
    local specID = GetSpecializationInfo(GetSpecialization()) or 0
    if specID == adpm.activeSpecID then return false end
    adpm.activeSpecID = specID
    return true
end

--- Merges defaults into ADPMCharDB without overwriting existing values.
function adpm.InitDB()
    if not ADPMCharDB then ADPMCharDB = {} end
    for k, v in pairs(adpm.DB_DEFAULTS) do
        if ADPMCharDB[k] == nil then
            -- Deep-copy tables so each char gets its own copy
            if type(v) == "table" then
                local copy = {}
                for dk, dv in pairs(v) do copy[dk] = dv end
                ADPMCharDB[k] = copy
            else
                ADPMCharDB[k] = v
            end
        end
    end
    -- Ensure minimap sub-table exists (for upgrades from old version)
    if type(ADPMCharDB.minimap) ~= "table" then
        local oldHidden = ADPMCharDB.minimapHidden
        local oldAngle  = ADPMCharDB.minimapAngle
        ADPMCharDB.minimap = {
            hide = oldHidden or false,
            minimapPos = oldAngle or 220,
        }
        ADPMCharDB.minimapHidden = nil
        ADPMCharDB.minimapAngle  = nil
    end
    -- Migrate old flat selectedFlask/selectedPotion into spec profile 0
    -- (spec 0 = "unknown", used before the player's spec is detected)
    if ADPMCharDB.selectedFlask ~= nil or ADPMCharDB.selectedPotion ~= nil then
        local profile = getOrCreateProfile(0)
        if profile.selectedFlask  == nil then profile.selectedFlask  = ADPMCharDB.selectedFlask  end
        if profile.selectedPotion == nil then profile.selectedPotion = ADPMCharDB.selectedPotion end
        ADPMCharDB.selectedFlask  = nil
        ADPMCharDB.selectedPotion = nil
    end
    -- Ensure specProfiles table exists (upgrade guard)
    if type(ADPMCharDB.specProfiles) ~= "table" then
        ADPMCharDB.specProfiles = {}
    end
end