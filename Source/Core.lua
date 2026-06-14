local _, addon = ...

addon.SAFEGUARD_LIMIT = 12   -- max items per safeguarded sale; fits the 12 buyback slots
-- Slider max, inclusive cap: current max item level per client
-- (retail post-12.0 squish: 298, MoP Classic: 582).
addon.MAX_ITEM_LEVEL = addon.Compat.IsRetail and 298 or 582

local Addon = LibStub("AceAddon-3.0"):NewAddon("KhamulsTransmogCleanup", "AceEvent-3.0", "AceConsole-3.0")
addon.Addon = Addon

local defaults = {
    global = {
        filters = {
            qualities = {
                [0] = true,  -- Poor
                [1] = true,  -- Common
                [2] = true,  -- Uncommon
                [3] = true,  -- Rare
                [4] = false, -- Epic
                [5] = false, -- Legendary
            },
            bindTypes = {
                boe = true,
                bop = true,
                boa = false,
                warbound = false,
                onUse = true,
            },
            transmogStatus = {
                learned = true,
                cantBeLearned = true,
                learnableByOther = false,
            },
            categories = {
                nonTransmogEquipment = false,
                consumables = false,
                tradeGoods = false,
                junkOther = false,
            },
            -- [expacID] = true excludes items of that expansion (retail only)
            excludeExpansions = {
                [9] = false,  -- Dragonflight
                [10] = false, -- The War Within
                [11] = false, -- Midnight
            },
            -- Class set tokens may still hold unlearned appearances for other
            -- classes (not detectable via API), so exclude them by default.
            excludeSetTokens = true,
            safeguard = true,
            useThreshold = false,
            thresholdGold = 100,
            thresholdIgnoreUnlearned = false,
            verbose = false,
            maxItemLevel = addon.MAX_ITEM_LEVEL,
        },
        ignoredItems = {},      -- [itemID] = true
        priceSource = "none",   -- "none" | "Auctionator" | "TSM:<source>"
    },
}

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("KhamulsTransmogCleanupDB", defaults, true)
    addon.db = self.db
    self:RegisterChatCommand("ktc", function()
        addon.MainFrame:Toggle()
    end)
end

function Addon:OnEnable()
    -- OnEnable runs at PLAYER_LOGIN, after all OptionalDeps have loaded.
    addon.Options.Register()
    self:RegisterEvent("MERCHANT_SHOW")
    self:RegisterEvent("MERCHANT_CLOSED")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
end

-- Tracked via events: MERCHANT_SHOW fires before MerchantFrame is visible,
-- so MerchantFrame:IsShown() is not reliable at that point.
addon.merchantOpen = false

function Addon:MERCHANT_SHOW()
    addon.merchantOpen = true
    addon.MainFrame:ShowAtMerchant()
end

function Addon:MERCHANT_CLOSED()
    addon.merchantOpen = false
    addon.Selling:Abort()
    addon.MainFrame:Hide()
end

function Addon:BAG_UPDATE_DELAYED()
    if addon.Selling:IsInProgress() then return end
    addon.MainFrame:QueueRefresh()
end
