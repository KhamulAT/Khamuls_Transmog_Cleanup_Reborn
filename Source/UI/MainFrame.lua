local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("KhamulsTransmogCleanup")

local MainFrame = {}
addon.MainFrame = MainFrame

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 600
local PENDING_RETRY_DELAY = 0.6
local MAX_PENDING_RETRIES = 5

local frame, sellButton, sumText
local refreshTimer, pendingTimer
local pendingRetries = 0

local function Create()
    frame = CreateFrame("Frame", "KhamulsTransmogCleanupFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -14)
    title:SetText(L["ADDON_TITLE"])

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() MainFrame:Hide() end)

    addon.FilterPanel:Create(frame)

    local hideButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    hideButton:SetSize(120, 24)
    hideButton:SetPoint("BOTTOMLEFT", 18, 14)
    hideButton:SetText(L["Hide"])
    hideButton:SetScript("OnClick", function() MainFrame:Hide() end)

    sellButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sellButton:SetSize(180, 24)
    sellButton:SetPoint("BOTTOMRIGHT", -18, 14)
    sellButton:SetText(L["Sell the items!"])
    sellButton:SetScript("OnClick", function()
        addon.Selling:Start(MainFrame.currentItems or {})
    end)

    sumText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sumText:SetPoint("LEFT", hideButton, "RIGHT", 8, 0)
    sumText:SetPoint("RIGHT", sellButton, "LEFT", -8, 0)
    sumText:SetJustifyH("CENTER")
    sumText:SetWordWrap(false)

    -- list spans from below the filter panel + slider down to above the buttons
    local listTop = -(36 + addon.FilterPanel.height + 12)
    addon.ItemList:Create(frame, listTop, 46)
end

function MainFrame:IsShown()
    return frame ~= nil and frame:IsShown()
end

-- Ignored items sink to the bottom; everything else keeps bag/slot order.
local function SortItems(items)
    local ignored = addon.db.global.ignoredItems
    table.sort(items, function(a, b)
        local ignoredA = ignored[a.itemID] and true or false
        local ignoredB = ignored[b.itemID] and true or false
        if ignoredA ~= ignoredB then
            return not ignoredA
        end
        if a.bag ~= b.bag then
            return a.bag < b.bag
        end
        return a.slot < b.slot
    end)
end

-- Re-sorts and re-renders the current dataset without rescanning the bags
-- (used when an item's ignore flag changes).
function MainFrame:ReRender()
    if not self:IsShown() or not self.currentItems then return end
    SortItems(self.currentItems)
    addon.ItemList:SetItems(self.currentItems)
    self:UpdateSellButton()
end

function MainFrame:UpdateSellButton()
    if not frame then return end
    local sellable = addon.Filters.GetSellableItems(self.currentItems or {})
    local safeguard = addon.db.global.filters.safeguard
    if safeguard then
        sellButton:SetText(L["SELL_BUTTON_SAFEGUARD"]:format(addon.SAFEGUARD_LIMIT))
    else
        sellButton:SetText(L["Sell the items!"])
    end
    sellButton:SetEnabled(#sellable > 0 and addon.merchantOpen and not addon.Selling:IsInProgress())

    -- Vendor total: everything that WILL be sold.
    local total = 0
    local willSell = {}
    for _, item in ipairs(sellable) do
        total = total + item.sellPrice * item.count
        willSell[item] = true
    end

    -- Possible auction value: items shown but NOT being sold (ignored or over
    -- threshold) — what you could get at the auction house by keeping them.
    local auctionTotal = 0
    for _, item in ipairs(self.currentItems or {}) do
        if not willSell[item] and item.auctionPrice then
            auctionTotal = auctionTotal + item.auctionPrice * item.count
        end
    end

    local text = L["VENDOR_SUM"]:format(GetMoneyString(total, true))
    if addon.PriceSources:IsConfigured() then
        text = text .. "      " .. L["AUCTION_SUM"]:format(GetMoneyString(auctionTotal, true))
    end
    sumText:SetText(text)
end

function MainFrame:Refresh()
    if not self:IsShown() then return end

    local items, pendingCount = addon.ItemScanner:Scan(function()
        MainFrame:QueueRefresh()
    end)

    local f = addon.db.global.filters
    local filtered = {}
    for _, item in ipairs(items) do
        if addon.Filters.Matches(item, f) then
            filtered[#filtered + 1] = item
        end
    end
    SortItems(filtered)
    self.currentItems = filtered

    addon.ItemList:SetItems(filtered)
    self:UpdateSellButton()

    -- Some data (item cache, CanIMogIt) resolves shortly after the first scan.
    if pendingCount > 0 and pendingRetries < MAX_PENDING_RETRIES then
        pendingRetries = pendingRetries + 1
        if pendingTimer then pendingTimer:Cancel() end
        pendingTimer = C_Timer.NewTimer(PENDING_RETRY_DELAY, function()
            pendingTimer = nil
            MainFrame:Refresh()
        end)
    elseif pendingCount == 0 then
        pendingRetries = 0
    end
end

function MainFrame:QueueRefresh()
    if not self:IsShown() then return end
    if refreshTimer then refreshTimer:Cancel() end
    refreshTimer = C_Timer.NewTimer(0.3, function()
        refreshTimer = nil
        MainFrame:Refresh()
    end)
end

local function Show(anchorToMerchant)
    if not frame then Create() end
    frame:ClearAllPoints()
    -- MERCHANT_SHOW can fire before MerchantFrame is visible, so anchor to it
    -- whenever it exists; the anchor is live and follows the merchant window.
    if anchorToMerchant and MerchantFrame then
        frame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 8, 0)
    else
        frame:SetPoint("CENTER")
    end
    pendingRetries = 0
    frame:Show()
    addon.FilterPanel:Load()
    MainFrame:Refresh()
end

function MainFrame:ShowAtMerchant()
    Show(true)
end

function MainFrame:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        Show(addon.merchantOpen)
    end
end

function MainFrame:Hide()
    if refreshTimer then refreshTimer:Cancel() refreshTimer = nil end
    if pendingTimer then pendingTimer:Cancel() pendingTimer = nil end
    if frame then frame:Hide() end
end
