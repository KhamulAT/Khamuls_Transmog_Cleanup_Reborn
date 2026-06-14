local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("KhamulsTransmogCleanup")

local ItemScanner = {}
addon.ItemScanner = ItemScanner

local categoryTexts
local function GetCategoryText(category, quality)
    if not categoryTexts then
        categoryTexts = {
            consumables = L["Consumable"],
            tradeGoods = L["Trade goods"],
            junk = L["Junk"],
            other = L["Other"],
        }
    end
    if category == "junkOther" then
        return quality == 0 and categoryTexts.junk or categoryTexts.other
    end
    return categoryTexts[category]
end

-- Item class IDs are stable across every WoW version; the Enum.ItemClass field
-- names are not reliable across retail/classic, so match the numbers directly.
local CLASS_CONSUMABLE = 0
local CLASS_WEAPON = 2
local CLASS_GEM = 3
local CLASS_ARMOR = 4
local CLASS_REAGENT = 5
local CLASS_TRADEGOODS = 7

local function GetCategory(classID)
    if classID == CLASS_WEAPON or classID == CLASS_ARMOR then
        return "equipment"
    elseif classID == CLASS_CONSUMABLE then
        return "consumables"
    -- Trade Goods covers crafting materials broadly: gems and reagents read as
    -- crafting mats to players, so they fold into the same category.
    elseif classID == CLASS_TRADEGOODS or classID == CLASS_GEM or classID == CLASS_REAGENT then
        return "tradeGoods"
    end
    return "junkOther"
end

-- Scans bags 0-4 and returns the list of vendorable items plus the number of
-- entries whose data is not ready yet (uncached item info or pending CIMI).
-- loadCallback is invoked (once per uncached item) when its data arrives.
function ItemScanner:Scan(loadCallback)
    local items = {}
    local pendingCount = 0
    local priceConfigured = addon.PriceSources:IsConfigured()
    local S = addon.MogStatus

    -- Backpack + the four regular bags, plus the retail reagent bag (container
    -- index 5 = Enum.BagIndex.ReagentBag), where crafting materials auto-sort.
    -- Gated on retail: on classic, index 5 is a bank bag, not the reagent bag.
    local bagIDs = {}
    for bag = 0, NUM_BAG_SLOTS do
        bagIDs[#bagIDs + 1] = bag
    end
    if addon.Compat.IsRetail then
        bagIDs[#bagIDs + 1] = 5
    end

    for _, bag in ipairs(bagIDs) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and not info.hasNoValue and not info.isLocked then
                local link = info.hyperlink
                local name, _, quality, _, _, _, _, _, _, icon, sellPrice, classID, _, bindType, expacID =
                    addon.Compat.GetItemInfo(link)

                if not name then
                    pendingCount = pendingCount + 1
                    if loadCallback then
                        local item = Item:CreateFromBagAndSlot(bag, slot)
                        if item and not item:IsItemEmpty() then
                            item:ContinueOnItemLoad(loadCallback)
                        end
                    end
                elseif sellPrice and sellPrice > 0 then
                    local category = GetCategory(classID)
                    local mogStatus, statusText
                    local isSetToken = false
                    if category == "equipment" then
                        mogStatus, statusText = addon.TransmogStatus:Get(link, bag, slot)
                        if mogStatus == S.PENDING then
                            pendingCount = pendingCount + 1
                        end
                    else
                        mogStatus = S.NOT_TRANSMOG
                        statusText = GetCategoryText(category, quality)
                        -- Class-restricted non-equipment = tier set token
                        isSetToken = addon.Tooltip.HasClassRestriction(bag, slot)
                    end

                    items[#items + 1] = {
                        bag = bag,
                        slot = slot,
                        itemLink = link,
                        itemID = info.itemID,
                        count = info.stackCount or 1,
                        quality = quality,
                        ilvl = category == "equipment"
                            and (addon.Compat.GetDetailedItemLevelInfo(link) or 0) or nil,
                        bindKey = addon.Tooltip.GetBindInfo(bag, slot, bindType),
                        sellPrice = sellPrice,
                        category = category,
                        expacID = expacID,
                        isSetToken = isSetToken,
                        mogStatus = mogStatus,
                        statusText = statusText,
                        auctionPrice = priceConfigured and addon.PriceSources:GetPrice(link) or nil,
                        name = name,
                        icon = icon,
                    }
                end
            end
        end
    end

    return items, pendingCount
end
