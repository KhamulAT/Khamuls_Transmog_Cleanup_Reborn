local _, addon = ...

local Tooltip = {}
addon.Tooltip = Tooltip

-- Bind lines appear in the first few tooltip lines; checked in priority order
-- because a soulbound line must win over the item's static bind type.
local bindChecks
local function GetBindChecks()
    if not bindChecks then
        bindChecks = {}
        local function add(text, key)
            if text then bindChecks[#bindChecks + 1] = { text = text, key = key } end
        end
        add(ITEM_SOULBOUND, "bop")
        -- Warband (same split CanIMogIt uses): account-bound = warbound,
        -- the legacy Battle.net-bound strings = BoA.
        add(ITEM_ACCOUNTBOUND, "warbound")
        add(ITEM_ACCOUNTBOUND_UNTIL_EQUIP, "warbound")
        add(ITEM_BIND_TO_ACCOUNT, "warbound")
        add(ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP, "warbound")
        add(ITEM_BNETACCOUNTBOUND, "boa")
        add(ITEM_BIND_TO_BNETACCOUNT, "boa")
        add(ITEM_BIND_ON_EQUIP, "boe")
        add(ITEM_BIND_ON_USE, "onUse")
    end
    return bindChecks
end

local BIND_SCAN_LINES = 8
local FULL_SCAN_LINES = 30
local scanner

local function GetTooltipLines(bag, slot, maxLines)
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local data = C_TooltipInfo.GetBagItem(bag, slot)
        if not data or not data.lines then return nil end
        local lines = {}
        for i = 1, math.min(#data.lines, maxLines) do
            lines[#lines + 1] = data.lines[i].leftText
        end
        return lines
    end

    if not scanner then
        scanner = CreateFrame("GameTooltip", "KhamulsTransmogCleanupScanTooltip", nil, "GameTooltipTemplate")
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)
    local lines = {}
    for i = 1, math.min(scanner:NumLines(), maxLines) do
        local fontString = _G["KhamulsTransmogCleanupScanTooltipTextLeft" .. i]
        local text = fontString and fontString:GetText()
        if text then lines[#lines + 1] = text end
    end
    scanner:Hide()
    return lines
end

-- Returns "bop", "boe", "boa", "onUse" or nil for the item's CURRENT bind
-- state (a BoE that has been equipped reports soulbound). bindType is the
-- 14th GetItemInfo return, used as fallback when no tooltip line matches.
function Tooltip.GetBindInfo(bag, slot, bindType)
    local lines = GetTooltipLines(bag, slot, BIND_SCAN_LINES)
    if lines then
        local checks = GetBindChecks()
        for i = 1, #lines do
            local text = lines[i]
            for j = 1, #checks do
                if text == checks[j].text then
                    return checks[j].key
                end
            end
        end
    end

    if bindType == 1 then
        return "bop"
    elseif bindType == 2 then
        return "boe"
    elseif bindType == 3 then
        return "onUse"
    elseif bindType == 7 then
        -- Enum.ItemBind.ToWoWAccount (warband)
        return "warbound"
    elseif bindType == 8 or bindType == 9 then
        -- Enum.ItemBind.ToBnetAccount(UntilEquipped)
        return "boa"
    end
    return nil
end

local classesPattern

-- True when the item's tooltip carries a "Classes: ..." restriction line.
-- For non-equipment items this identifies class set tokens.
function Tooltip.HasClassRestriction(bag, slot)
    if not classesPattern then
        -- ITEM_CLASSES_ALLOWED = "Classes: %s" -> match any class list
        classesPattern = "^" .. ITEM_CLASSES_ALLOWED:gsub("%%s", ".+") .. "$"
    end
    local lines = GetTooltipLines(bag, slot, FULL_SCAN_LINES)
    if not lines then return false end
    for i = 1, #lines do
        if lines[i] and lines[i]:find(classesPattern) then
            return true
        end
    end
    return false
end
