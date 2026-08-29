local _, addon = ...

addon.SAFEGUARD_LIMIT = 12   -- max items per safeguarded sale; fits the 12 buyback slots
-- Slider max, inclusive cap: current max item level per client
-- (retail post-12.0 squish: 344, MoP Classic: 582).
addon.MAX_ITEM_LEVEL = addon.Compat.IsRetail and 344 or 582
-- The cap in force before maxItemLevelCap was recorded; assumed for installs
-- saved by an earlier version (see MigrateMaxItemLevel).
local LEGACY_MAX_ITEM_LEVEL = addon.Compat.IsRetail and 298 or 582

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

-- AceDB copies scalar defaults into SavedVariables on the first run and never
-- refreshes them, so raising MAX_ITEM_LEVEL for a new patch would otherwise
-- leave existing users filtering at the previous ceiling, hiding every item of
-- the new season. Follow the cap upward for anyone parked at the old maximum;
-- a deliberately lower value is left alone.
local function MigrateMaxItemLevel(filters)
    local savedCap = filters.maxItemLevelCap or LEGACY_MAX_ITEM_LEVEL
    if savedCap < addon.MAX_ITEM_LEVEL and (filters.maxItemLevel or 0) >= savedCap then
        filters.maxItemLevel = addon.MAX_ITEM_LEVEL
    end
    filters.maxItemLevelCap = addon.MAX_ITEM_LEVEL
end

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("KhamulsTransmogCleanupDB", defaults, true)
    addon.db = self.db
    MigrateMaxItemLevel(self.db.global.filters)
    self:RegisterChatCommand("ktc", function()
        addon.MainFrame:Toggle()
    end)
end

function Addon:OnEnable()
    -- OnEnable runs at PLAYER_LOGIN, after all OptionalDeps have loaded.
    -- Events go first: the settings panel merely reports on optional addons, so
    -- a failure there must not leave the merchant hooks unregistered.
    self:RegisterEvent("MERCHANT_SHOW")
    self:RegisterEvent("MERCHANT_CLOSED")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    addon.Options.Register()
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
