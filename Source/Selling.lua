local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("KhamulsTransmogCleanup")

local Selling = {}
addon.Selling = Selling

local SELL_INTERVAL = 0.2

local ticker, queue, queueIndex
local totalCopper, soldCount, hasMore

function Selling:IsInProgress()
    return ticker ~= nil
end

local function Report()
    if soldCount > 0 then
        addon.Addon:Print(L["SOLD_SUMMARY"]:format(soldCount, GetMoneyString(totalCopper, true)))
        if hasMore then
            addon.Addon:Print(L["SOLD_MORE_REMAINING"])
        end
    end
end

local function Finish()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    Report()
    queue = nil
    addon.MainFrame:QueueRefresh()
end

local function SellNext()
    queueIndex = queueIndex + 1
    local entry = queue and queue[queueIndex]
    if not entry then
        Finish()
        return
    end

    -- Re-validate the slot right before selling: bags can shift. On any
    -- mismatch skip the entry — never re-resolve, never sell a wrong item.
    local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
    if info and info.itemID == entry.itemID and not info.isLocked then
        C_Container.UseContainerItem(entry.bag, entry.slot)
        local copper = entry.sellPrice * (info.stackCount or entry.count)
        totalCopper = totalCopper + copper
        soldCount = soldCount + 1
        if addon.db.global.filters.verbose then
            addon.Addon:Print(L["SOLD_ITEM"]:format(entry.itemLink, GetMoneyString(copper, true)))
        end
    end
end

-- items: the current (unfiltered-for-sale) dataset shown in the list.
function Selling:Start(items)
    if self:IsInProgress() then return end
    if not addon.merchantOpen then return end

    queue = addon.Filters.GetSellableItems(items)
    if #queue == 0 then
        queue = nil
        return
    end

    -- Cheapest first: if anything goes wrong, the least value is at risk.
    table.sort(queue, function(a, b)
        return a.sellPrice * a.count < b.sellPrice * b.count
    end)

    hasMore = false
    if addon.db.global.filters.safeguard and #queue > addon.SAFEGUARD_LIMIT then
        hasMore = true
        for i = #queue, addon.SAFEGUARD_LIMIT + 1, -1 do
            queue[i] = nil
        end
    end

    queueIndex = 0
    totalCopper = 0
    soldCount = 0
    ticker = C_Timer.NewTicker(SELL_INTERVAL, SellNext)
    addon.MainFrame:UpdateSellButton()
end

-- Called when the merchant closes; selling without a merchant is impossible.
function Selling:Abort()
    if not self:IsInProgress() then return end
    ticker:Cancel()
    ticker = nil
    Report()
    queue = nil
end
