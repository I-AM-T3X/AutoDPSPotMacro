-- Core\Potions.lua
-- Midnight combat potion definitions.
-- Quality tiers per potion: { Silver ID, Gold ID }
-- Fleeting versions come from the Voidlight Potion Cauldron placed by Alchemists.
--
-- Item IDs (verified via Wowhead live / beta):
--   Light's Potential          (Primary Stat, 30s)               Silver 241308  Gold 241309  Fleeting: 245897, 245898
--   Potion of Recklessness     (Highest sec +, lowest sec -, 30s) Silver 241288  Gold 241289  Fleeting: 245903, 245902
--   Draught of Rampant Abandon (Primary Stat 30s + void zone)    Silver 241292  Gold 241293  Fleeting: 245911, 245910
--   Potion of Zealotry         (Stacking ST holy damage)         Silver 241296  Gold 241297  Fleeting: 245900, 245901
--   Lightfused Mana Potion     (Mana restore, healers)           Silver 241301  Gold 241300  Fleeting: 245917, 245916

local addonName, adpm = ...

adpm.potionDefs = {
    {
        key         = "PotionRecklessness",
        label       = "Potion of Recklessness",
        stat        = "Highest secondary + / Lowest secondary - ",
        color       = "ff8800",
        desc        = "Best general DPS pot. Trades lowest secondary for a large boost to highest.",
        craftedIDs  = { 241289, 241288 },
        fleetingIDs = { 245903, 245902 },
    },
    {
        key         = "PotionDraught",
        label       = "Draught of Rampant Abandon",
        stat        = "Primary Stat (30s) — spawns void zone",
        color       = "9933ff",
        desc        = "Strong primary stat pot. Occasionally summons a silenced void zone under you.",
        craftedIDs  = { 241293, 241292 },
        fleetingIDs = { 245911, 245910 },
    },
    {
        key         = "PotionLightsPotential",
        label       = "Light's Potential",
        stat        = "Primary Stat (30s)",
        color       = "ffffaa",
        desc        = "Safe primary stat pot. No downside.",
        craftedIDs  = { 241309, 241308 },
        fleetingIDs = { 245897, 245898 },
    },
    {
        key         = "PotionZealotry",
        label       = "Potion of Zealotry",
        stat        = "Stacking single-target holy damage",
        color       = "ffdd44",
        desc        = "Best for single-target fights. Resets stacks on target change.",
        craftedIDs  = { 241297, 241296 },
        fleetingIDs = { 245900, 245901 },
    },
    {
        key         = "PotionManaMana",
        label       = "Lightfused Mana Potion",
        stat        = "Mana restore",
        color       = "00aaff",
        desc        = "Restores mana. For healers and mana-dependent casters.",
        craftedIDs  = { 241301, 241300 },
        fleetingIDs = { 245917, 245916 },
    },
}

-- Register every ID
for _, def in ipairs(adpm.potionDefs) do
    for _, id in ipairs(def.craftedIDs)  do adpm.RegisterItem(id) end
    for _, id in ipairs(def.fleetingIDs) do adpm.RegisterItem(id) end
end

--- Returns the best available potion item ID for the currently selected potion type,
--- or nil if none is owned or none is selected.
--- Priority: Gold (fleeting) > Silver (fleeting) > Gold (crafted) > Silver (crafted)
function adpm.GetBestPotionID()
    local selectedKey = ADPMDB.selectedPotion
    if not selectedKey then return nil end

    for _, def in ipairs(adpm.potionDefs) do
        if def.key == selectedKey then
            -- Check fleeting tiers highest-to-lowest first
            for i = #def.fleetingIDs, 1, -1 do
                local item = adpm.items[def.fleetingIDs[i]]
                if item and item:IsOwned() then return item:GetID() end
            end
            -- Then crafted tiers highest-to-lowest
            for i = #def.craftedIDs, 1, -1 do
                local item = adpm.items[def.craftedIDs[i]]
                if item and item:IsOwned() then return item:GetID() end
            end
            return nil
        end
    end
    return nil
end

--- Returns the potion def table for a given key, or nil.
function adpm.GetPotionDef(key)
    for _, def in ipairs(adpm.potionDefs) do
        if def.key == key then return def end
    end
    return nil
end
