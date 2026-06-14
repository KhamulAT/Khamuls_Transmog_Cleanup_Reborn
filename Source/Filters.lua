local _, addon = ...

local Filters = {}
addon.Filters = Filters

local COPPER_PER_GOLD = 10000

-- Pure list-filter predicate: decides whether an item appears in the list.
-- Ignore flag and price threshold do NOT hide rows; they only block the sale.
function Filters.Matches(item, f)
    local S = addon.MogStatus

    -- Never show rows whose data has not resolved yet.
    if item.mogStatus == S.PENDING then
        return false
    end

    -- Mists only: never offer appearances this character can still learn.
    -- On retail, selling an item teaches its transmog, so unlearned items
    -- are listed ("will be learned on sale").
    if not addon.Compat.IsRetail and item.mogStatus == S.LEARNABLE then
        return false
    end

    if not f.qualities[item.quality] then
        return false
    end

    if item.bindKey and not f.bindTypes[item.bindKey] then
        return false
    end

    -- Inclusive cap: an item exactly at the slider value is still sold.
    if item.ilvl and item.ilvl > f.maxItemLevel then
        return false
    end

    if item.expacID and f.excludeExpansions and f.excludeExpansions[item.expacID] then
        return false
    end

    if f.excludeSetTokens and item.isSetToken then
        return false
    end

    if item.category == "equipment" then
        if item.mogStatus == S.NOT_TRANSMOG then
            return f.categories.nonTransmogEquipment
        end
        -- Retail has no transmog status filter (selling teaches the transmog).
        if addon.Compat.IsRetail then
            return true
        end
        if item.mogStatus == S.LEARNED then
            return f.transmogStatus.learned
        elseif item.mogStatus == S.CANT_LEARN then
            return f.transmogStatus.cantBeLearned
        elseif item.mogStatus == S.OTHER_CHAR then
            return f.transmogStatus.learnableByOther
        end
        return false
    end
    return f.categories[item.category] or false
end

function Filters.IsOverThreshold(item, f)
    -- Optionally exempt unlearned transmog so its appearance is captured on sale
    -- regardless of auction value.
    if f.thresholdIgnoreUnlearned and item.mogStatus == addon.MogStatus.LEARNABLE then
        return false
    end
    return f.useThreshold
        and addon.PriceSources:IsConfigured()
        and item.auctionPrice ~= nil
        and item.auctionPrice * item.count > f.thresholdGold * COPPER_PER_GOLD
end

-- Single chokepoint deciding what may actually be sold.
function Filters.GetSellableItems(items)
    local f = addon.db.global.filters
    local ignored = addon.db.global.ignoredItems
    local sellable = {}
    for _, item in ipairs(items) do
        if Filters.Matches(item, f)
            and not ignored[item.itemID]
            and not Filters.IsOverThreshold(item, f)
            and item.sellPrice and item.sellPrice > 0 then
            sellable[#sellable + 1] = item
        end
    end
    return sellable
end
