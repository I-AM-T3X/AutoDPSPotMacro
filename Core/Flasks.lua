-- Core\Flasks.lua
-- Midnight flask definitions.
-- Quality tiers per flask: { Silver ID, Gold ID }  (index 1 = lowest, last = highest)
-- Fleeting versions come from the Cauldron of Sin'dorei Flasks placed by Alchemists.
--
-- Item IDs (verified via Wowhead live / beta):
--   Flask of Thalassian Resistance  (Versatility)    Gold 241320  Silver 241321  Fleeting: 245926, 245927
--   Flask of the Magisters          (Mastery)         Gold 241322  Silver 241323  Fleeting: 245932, 245933
--   Flask of the Blood Knights      (Haste)           Gold 241324  Silver 241325  Fleeting: 245930, 245931
--   Flask of the Shattered Sun      (Critical Strike) Gold 241326  Silver 241327  Fleeting: 245928, 245929
--
-- Priority order applied when choosing which ID to put in the macro:
--   Gold (crafted) > Silver (crafted) > Gold (fleeting) > Silver (fleeting)

local addonName, adpm = ...

-- Each definition is an ordered entry; order here controls display order in the UI.
-- Fields:
--   key       string  saved-variable identifier (stable across updates)
--   label     string  displayed name in UI
--   stat      string  primary stat granted (shown in UI)
--   tiers     array   {craftedIDs={Silver,Gold}, fleetingIDs={Silver,Gold}}
--                     NOTE: In Midnight, Gold has the LOWER item ID number.
--                     craftedIDs are checked before fleetingIDs.

adpm.flaskDefs = {
    {
        key       = "FlaskBloodKnights",
        label     = "Flask of the Blood Knights",
        stat      = "Haste",
        color     = "3399ff",
        craftedIDs  = { 241325, 241324 },
        fleetingIDs = { 245930, 245931 },
    },
    {
        key       = "FlaskShatteredSun",
        label     = "Flask of the Shattered Sun",
        stat      = "Critical Strike",
        color     = "ff4444",
        craftedIDs  = { 241327, 241326 },
        fleetingIDs = { 245928, 245929 },
    },
    {
        key       = "FlaskMagisters",
        label     = "Flask of the Magisters",
        stat      = "Mastery",
        color     = "aa44ff",
        craftedIDs  = { 241323, 241322 },
        fleetingIDs = { 245932, 245933 },
    },
    {
        key       = "FlaskThalassianResistance",
        label     = "Flask of Thalassian Resistance",
        stat      = "Versatility",
        color     = "44ff88",
        craftedIDs  = { 241321, 241320 },
        fleetingIDs = { 245926, 245927 },
    },
}

-- Register every ID as a PPItem
for _, def in ipairs(adpm.flaskDefs) do
    for _, id in ipairs(def.craftedIDs)  do adpm.RegisterItem(id) end
    for _, id in ipairs(def.fleetingIDs) do adpm.RegisterItem(id) end
end

--- Returns the best available flask item ID for the currently selected flask type,
--- or nil if none is owned or none is selected.
--- Priority: Gold crafted > Silver crafted > Gold fleeting > Silver fleeting
function adpm.GetBestFlaskID()
    local selectedKey = ADPMDB.selectedFlask
    if not selectedKey then return nil end

    for _, def in ipairs(adpm.flaskDefs) do
        if def.key == selectedKey then
            -- Check crafted tiers highest-to-lowest first
            for i = #def.craftedIDs, 1, -1 do
                local item = adpm.items[def.craftedIDs[i]]
                if item and item:IsOwned() then return item:GetID() end
            end
            -- Then fleeting highest-to-lowest
            for i = #def.fleetingIDs, 1, -1 do
                local item = adpm.items[def.fleetingIDs[i]]
                if item and item:IsOwned() then return item:GetID() end
            end
            return nil  -- selected type found but none owned
        end
    end
    return nil
end

--- Returns the flask def table for a given key, or nil.
function adpm.GetFlaskDef(key)
    for _, def in ipairs(adpm.flaskDefs) do
        if def.key == key then return def end
    end
    return nil
end
