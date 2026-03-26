-- Core\Flasks.lua
-- Midnight flask definitions.
-- Quality tiers per flask: { Silver ID, Gold ID }  (index 1 = lowest, last = highest)
-- Fleeting versions come from the Cauldron of Sin'dorei Flasks placed by Alchemists.

local addonName, adpm = ...

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

for _, def in ipairs(adpm.flaskDefs) do
    for _, id in ipairs(def.craftedIDs)  do adpm.RegisterItem(id) end
    for _, id in ipairs(def.fleetingIDs) do adpm.RegisterItem(id) end
end

function adpm.GetBestFlaskID()
    -- CHANGED: ADPMDB -> ADPMCharDB
    local selectedKey = ADPMCharDB.selectedFlask
    if not selectedKey then return nil end

    for _, def in ipairs(adpm.flaskDefs) do
        if def.key == selectedKey then
            for i = #def.fleetingIDs, 1, -1 do
                local item = adpm.items[def.fleetingIDs[i]]
                if item and item:IsOwned() then return item:GetID() end
            end
            for i = #def.craftedIDs, 1, -1 do
                local item = adpm.items[def.craftedIDs[i]]
                if item and item:IsOwned() then return item:GetID() end
            end
            return nil
        end
    end
    return nil
end

function adpm.GetFlaskDef(key)
    for _, def in ipairs(adpm.flaskDefs) do
        if def.key == key then return def end
    end
    return nil
end