local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("KhamulsTransmogCleanup")

local ItemList = {}
addon.ItemList = ItemList

local ROW_HEIGHT = 22
local IGNORE_X = 0
local ITEM_X, ITEM_W = 26, 240
local ILVL_X, ILVL_W = 268, 32
local SALE_X, SALE_W = 302, 22
local STATUS_X, STATUS_W = 326, 140
local VENDOR_X, VENDOR_W = 468, 70
local AUCTION_X, AUCTION_W = 540, 70

local RED = "|cffff3333"
local GREY = "|cff9d9d9d"

local WILL_SELL_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14|t"
local WONT_SELL_ICON = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t"

local statusColors = {
    LEARNED = "|cff1eff00",
    CANT_LEARN = "|cffcccccc",
    OTHER_CHAR = "|cffffd100",
    NOT_TRANSMOG = GREY,
    LEARNABLE = "|cffff8000",
    PENDING = GREY,
}

local scrollFrame, content, headerAuction
local rows = {}

local function OnRowEnter(row)
    if not row.data then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(row.data.bag, row.data.slot)
    GameTooltip:Show()
end

local function OnRowClick(row)
    if row.data and IsModifiedClick() then
        HandleModifiedItemClick(row.data.itemLink)
    end
end

local function ApplyIgnoredStyle(row, ignored)
    local alpha = ignored and 0.4 or 1
    row.item:SetAlpha(alpha)
    row.ilvl:SetAlpha(alpha)
    row.status:SetAlpha(alpha)
    row.vendor:SetAlpha(alpha)
    row.auction:SetAlpha(alpha)
end

local function UpdateSaleIcon(row, ignored)
    local willSell = not ignored and not row.overThreshold
    row.sale:SetText(willSell and WILL_SELL_ICON or WONT_SELL_ICON)
end

local function OnIgnoreClick(check)
    local row = check:GetParent()
    if not row.data then return end
    local ignored = check:GetChecked() and true or false
    addon.db.global.ignoredItems[row.data.itemID] = ignored or nil
    -- Re-render so the toggled item moves to/from the ignored block at the bottom.
    addon.MainFrame:ReRender()
end

local function MakeCell(row, x, width, justify)
    local cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cell:SetPoint("LEFT", x, 0)
    cell:SetWidth(width)
    cell:SetJustifyH(justify or "LEFT")
    cell:SetWordWrap(false)
    return cell
end

local function GetRow(index)
    local row = rows[index]
    if not row then
        row = CreateFrame("Button", nil, content)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.08)

        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(20, 20)
        row.check:SetPoint("LEFT", IGNORE_X, 0)
        row.check:SetScript("OnClick", OnIgnoreClick)
        row.check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["IGNORE_TOOLTIP"])
            GameTooltip:Show()
        end)
        row.check:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.item = MakeCell(row, ITEM_X, ITEM_W)
        row.ilvl = MakeCell(row, ILVL_X, ILVL_W, "CENTER")
        row.sale = MakeCell(row, SALE_X, SALE_W, "CENTER")
        row.status = MakeCell(row, STATUS_X, STATUS_W)
        row.vendor = MakeCell(row, VENDOR_X, VENDOR_W, "RIGHT")
        row.auction = MakeCell(row, AUCTION_X, AUCTION_W, "RIGHT")

        row:SetScript("OnEnter", OnRowEnter)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", OnRowClick)

        rows[index] = row
    end
    return row
end

local function MakeHeaderCell(parent, text, x, width, justify)
    local cell = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cell:SetPoint("LEFT", x + 4, 0)
    cell:SetWidth(width)
    cell:SetJustifyH(justify or "LEFT")
    cell:SetText(text)
    return cell
end

-- anchorTo: the frame the list is anchored between (filter panel above, buttons below).
function ItemList:Create(parent, topOffset, bottomOffset)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", 18, topOffset)
    header:SetPoint("TOPRIGHT", -40, topOffset)
    header:SetHeight(16)
    MakeHeaderCell(header, L["Item"], ITEM_X, ITEM_W)
    MakeHeaderCell(header, L["ilvl"], ILVL_X, ILVL_W, "CENTER")
    MakeHeaderCell(header, L["Status"], STATUS_X, STATUS_W)
    MakeHeaderCell(header, L["Vendor"], VENDOR_X, VENDOR_W, "RIGHT")
    headerAuction = MakeHeaderCell(header, L["Auction"], AUCTION_X, AUCTION_W, "RIGHT")

    scrollFrame = CreateFrame("ScrollFrame", "KhamulsTransmogCleanupScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, bottomOffset)

    content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)
end

function ItemList:SetItems(items)
    local f = addon.db.global.filters
    local ignoredItems = addon.db.global.ignoredItems
    local priceConfigured = addon.PriceSources:IsConfigured()
    headerAuction:SetShown(priceConfigured)

    for index, item in ipairs(items) do
        local row = GetRow(index)
        row.data = item

        local itemText = item.itemLink
        if item.count > 1 then
            itemText = itemText .. " x" .. item.count
        end
        row.item:SetText(itemText)

        row.ilvl:SetText(item.ilvl and tostring(item.ilvl) or "-")

        local overThreshold = addon.Filters.IsOverThreshold(item, f)
        row.overThreshold = overThreshold
        if overThreshold then
            row.status:SetText(RED .. L["Above threshold"] .. "|r")
        else
            local color = statusColors[item.mogStatus] or GREY
            if item.category ~= "equipment" then color = GREY end
            row.status:SetText(color .. (item.statusText or "") .. "|r")
        end

        row.vendor:SetText(GetMoneyString(item.sellPrice * item.count, true))

        if priceConfigured then
            if item.auctionPrice then
                local text = GetMoneyString(item.auctionPrice, true)
                if overThreshold then
                    text = RED .. text .. "|r"
                end
                row.auction:SetText(text)
            else
                row.auction:SetText(GREY .. "-" .. "|r")
            end
        else
            row.auction:SetText("")
        end

        local ignored = ignoredItems[item.itemID] and true or false
        row.check:SetChecked(ignored)
        ApplyIgnoredStyle(row, ignored)
        UpdateSaleIcon(row, ignored)
        row:Show()
    end

    for index = #items + 1, #rows do
        rows[index].data = nil
        rows[index]:Hide()
    end

    content:SetHeight(math.max(#items * ROW_HEIGHT, 1))
end
