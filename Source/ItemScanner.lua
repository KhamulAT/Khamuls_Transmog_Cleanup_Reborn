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

local function GetCategory(classID)
    if classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor then
        return "equipment"
    elseif classID == Enum.ItemClass.Consumable then
        return "consumables"
    elseif classID == Enum.ItemClass.Tradegoods then
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

    for bag = 0, NUM_BAG_SLOTS do
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
