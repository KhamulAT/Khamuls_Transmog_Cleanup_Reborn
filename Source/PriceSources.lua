local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("KhamulsTransmogCleanup")

local PriceSources = {}
addon.PriceSources = PriceSources

local CALLER_ID = "KhamulsTransmogCleanup"
-- All money-valued AuctionDB sources TSM registers. DBRegionSaleRate and
-- DBRegionSoldPerDay are plain numbers, not prices, and are left out.
local TSM_SOURCES = {
    "DBMarket",
    "DBMinBuyout",
    "DBRecent",
    "DBHistorical",
    "DBRegionMarketAvg",
    "DBRegionHistorical",
    "DBRegionSaleAvg",
}

function PriceSources:GetAvailable()
    local list = { { value = "none", label = L["None"] } }
    if addon.Compat.IsAddOnLoaded("Auctionator") and Auctionator and Auctionator.API and Auctionator.API.v1 then
        list[#list + 1] = { value = "Auctionator", label = "Auctionator" }
    end
    if addon.Compat.IsAddOnLoaded("TradeSkillMaster") and TSM_API then
        for _, source in ipairs(TSM_SOURCES) do
            list[#list + 1] = { value = "TSM:" .. source, label = "TSM: " .. source }
        end
    end
    return list
end

function PriceSources:HasAnySource()
    return #self:GetAvailable() > 1
end

-- Returns the configured source value, or nil when none is configured or the
-- configured companion addon is no longer available (stale saved value).
function PriceSources:GetConfigured()
    local value = addon.db.global.priceSource
    if not value or value == "none" then return nil end
    for _, source in ipairs(self:GetAvailable()) do
        if source.value == value then
            return value
        end
    end
    return nil
end

function PriceSources:IsConfigured()
    return self:GetConfigured() ~= nil
end

-- Returns the auction price in copper, or nil when no data is available.
function PriceSources:GetPrice(itemLink)
    local value = self:GetConfigured()
    if not value then return nil end

    if value == "Auctionator" then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, CALLER_ID, itemLink)
        if ok then return price end
        return nil
    end

    local tsmSource = value:match("^TSM:(.+)$")
    if tsmSource and TSM_API then
        local ok, itemString = pcall(TSM_API.ToItemString, itemLink)
        if ok and itemString then
            local okPrice, price = pcall(TSM_API.GetCustomPriceValue, tsmSource, itemString)
            if okPrice then return price end
        end
    end
    return nil
end
