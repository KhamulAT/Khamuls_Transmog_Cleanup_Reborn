local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("KhamulsTransmogCleanup")

addon.MogStatus = {
    LEARNED = "LEARNED",
    LEARNABLE = "LEARNABLE",       -- this character can still learn it: never listed/sold
    CANT_LEARN = "CANT_LEARN",     -- nobody can learn it anymore (e.g. soulbound, wrong class)
    OTHER_CHAR = "OTHER_CHAR",     -- another character could learn it
    NOT_TRANSMOG = "NOT_TRANSMOG",
    PENDING = "PENDING",
}
local S = addon.MogStatus

local TransmogStatus = {}
addon.TransmogStatus = TransmogStatus

local statusTexts -- built lazily so locale lookups happen after locales loaded
local function GetStatusText(status)
    if not statusTexts then
        statusTexts = {
            [S.LEARNED] = L["Learned"],
            -- Retail teaches the transmog when the item is sold.
            [S.LEARNABLE] = addon.Compat.IsRetail
                and L["Will be learned on sale"] or L["Learnable by you"],
            [S.CANT_LEARN] = L["Can't be learned"],
            [S.OTHER_CHAR] = L["Learnable by another character"],
            [S.NOT_TRANSMOG] = L["Not transmoggable"],
            [S.PENDING] = L["Loading..."],
        }
    end
    return statusTexts[status]
end

local provider

local function DetectProvider()
    if CanIMogIt and CanIMogIt.IsTransmogable then
        return "CIMI"
    elseif C_TransmogCollection then
        return "Native"
    end
    return "Null"
end

function TransmogStatus:GetProvider()
    if not provider then
        provider = DetectProvider()
    end
    return provider
end

-- Whether transmog status can be determined at all (column 3 checkboxes).
function TransmogStatus:SupportsStatus()
    return self:GetProvider() ~= "Null"
end

-- "Learnable by another character" needs account-wide knowledge → CanIMogIt only.
function TransmogStatus:SupportsOtherChar()
    return self:GetProvider() == "CIMI"
end

-- CanIMogIt provider. Built on CIMI's primitives instead of GetTooltipText,
-- because the tooltip constants do not distinguish "unknown but learnable"
-- from "unknown and unlearnable" — the primitives do.
local function GetViaCanIMogIt(itemLink, bag, slot)
    local ok, transmogable = pcall(CanIMogIt.IsTransmogable, CanIMogIt, itemLink)
    if not ok then return S.PENDING end
    if not transmogable then return S.NOT_TRANSMOG end

    local okItem, knowsFromItem = pcall(CanIMogIt.PlayerKnowsTransmogFromItem, CanIMogIt, itemLink)
    if not okItem or knowsFromItem == nil then return S.PENDING end
    if knowsFromItem then return S.LEARNED end

    local okAny, knowsAny = pcall(CanIMogIt.PlayerKnowsTransmog, CanIMogIt, itemLink)
    if not okAny or knowsAny == nil then return S.PENDING end
    if knowsAny then return S.LEARNED end

    local okLearn, canLearn = pcall(CanIMogIt.CharacterCanLearnTransmog, CanIMogIt, itemLink)
    if not okLearn or canLearn == nil then return S.PENDING end
    if canLearn then return S.LEARNABLE end

    -- This character can't learn it. Soulbound means no other character ever can.
    local okBound, soulbound = pcall(CanIMogIt.IsItemSoulbound, CanIMogIt, itemLink, bag, slot)
    if okBound and soulbound then
        return S.CANT_LEARN
    end
    return S.OTHER_CHAR
end

local function PlayerHasAppearance(itemLink, sourceID)
    if C_TransmogCollection.PlayerHasTransmogByItemInfo then
        return C_TransmogCollection.PlayerHasTransmogByItemInfo(itemLink)
    end
    if sourceID and C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
        return C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID)
    end
    if C_TransmogCollection.PlayerHasTransmog then
        local itemID = addon.Compat.GetItemInfoInstant(itemLink)
        if itemID then
            return C_TransmogCollection.PlayerHasTransmog(itemID)
        end
    end
    return false
end

-- Native provider (MoP Classic, or retail without CanIMogIt).
local function GetViaNativeAPI(itemLink)
    local ok, _, sourceID = pcall(C_TransmogCollection.GetItemInfo, itemLink)
    if not ok or not sourceID then
        return S.NOT_TRANSMOG
    end

    local okHas, has = pcall(PlayerHasAppearance, itemLink, sourceID)
    if okHas and has then
        return S.LEARNED
    end

    if C_TransmogCollection.PlayerCanCollectSource then
        local okCollect, _, canCollect = pcall(C_TransmogCollection.PlayerCanCollectSource, sourceID)
        if okCollect then
            if canCollect then
                return S.LEARNABLE
            end
            return S.CANT_LEARN
        end
    end
    -- Learnability unknown: stay protective and treat it as still learnable.
    return S.LEARNABLE
end

-- Returns status, localized status text. PENDING means data not ready yet.
function TransmogStatus:Get(itemLink, bag, slot)
    local prov = self:GetProvider()
    local status
    if prov == "CIMI" then
        status = GetViaCanIMogIt(itemLink, bag, slot)
    elseif prov == "Native" then
        status = GetViaNativeAPI(itemLink)
    else
        status = S.NOT_TRANSMOG
    end
    return status, GetStatusText(status)
end
