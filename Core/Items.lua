-- Core\Items.lua
-- Defines the PPItem class used by Flasks.lua and Potions.lua.

local addonName, adpm = ...

--- @class PPItem
local PPItem = {}
PPItem.__index = PPItem

--- @param id number  WoW item ID
--- @return PPItem
function PPItem.new(id)
    local self = setmetatable({}, PPItem)
    self.id = id
    return self
end

function PPItem:GetID()    return self.id end
function PPItem:GetName()  return C_Item.GetItemNameByID(self.id) or ("Unknown:" .. self.id) end
--- Scans all bags for an exact item ID match using item links.
--- In Midnight, crafted quality variants (Silver/Gold) share a base itemID —
--- C_Container.GetContainerItemInfo returns the same itemID for both.
--- We instead parse the item link which encodes the exact quality variant ID.
--- Item links look like: |cffffff00|Hitem:241323:...|h[Name]|h|r
--- The first number after "item:" is the exact item ID including quality tier.
function PPItem:GetCount()
    local total = 0
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link then
                local linkID = tonumber(link:match("item:(%d+)"))
                if linkID == self.id then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    total = total + (info and info.stackCount or 1)
                end
            end
        end
    end
    return total
end

function PPItem:IsOwned() return self:GetCount() > 0 end

--- Returns the item's icon texture (or a fallback question mark).
function PPItem:GetIcon()
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(self.id)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

--- Fires callback once the item data is available client-side.
function PPItem:WhenLoaded(callback)
    local item = Item:CreateFromItemID(self.id)
    item:ContinueOnItemLoad(callback)
end

-- Expose class on the namespace
adpm.PPItem = PPItem

--- Registers a PPItem for the given ID if not already registered.
--- @param id number
--- @return PPItem
function adpm.RegisterItem(id)
    if not adpm.items[id] then
        adpm.items[id] = PPItem.new(id)
    end
    return adpm.items[id]
end
