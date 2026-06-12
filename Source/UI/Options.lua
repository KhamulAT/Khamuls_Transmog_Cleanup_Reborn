local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("KhamulsTransmogCleanup")

local Options = {}
addon.Options = Options

local registered = false

local COMPANION_ADDONS = { "CanIMogIt", "Auctionator", "TradeSkillMaster" }

-- Element mixin for KhamulsTransmogCleanupOptionsTextTemplate (compact text row).
KhamulsTransmogCleanupOptionsTextMixin = {}

function KhamulsTransmogCleanupOptionsTextMixin:Init(initializer)
    local data = initializer:GetData()
    self.Text:SetText(data.text)
end

function KhamulsTransmogCleanupOptionsTextMixin:Release()
end

function Options.Register()
    if registered then return end
    registered = true

    local category, layout = Settings.RegisterVerticalLayoutCategory(L["ADDON_TITLE"])

    local function AddHeader(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function AddText(text)
        layout:AddInitializer(Settings.CreateElementInitializer(
            "KhamulsTransmogCleanupOptionsTextTemplate", { text = text }))
    end

    AddHeader(L["Setup Price Source"])
    if addon.PriceSources:HasAnySource() then
        local setting = Settings.RegisterAddOnSetting(
            category, "KTCR_PriceSource", "priceSource", addon.db.global,
            Settings.VarType.String, L["Price source"], "none")
        setting:SetValueChangedCallback(function()
            if addon.MainFrame:IsShown() then
                addon.FilterPanel:Load()
                addon.MainFrame:Refresh()
            end
        end)
        Settings.CreateDropdown(category, setting, function()
            local container = Settings.CreateControlTextContainer()
            for _, source in ipairs(addon.PriceSources:GetAvailable()) do
                container:Add(source.value, source.label)
            end
            return container:GetData()
        end, L["PRICE_SOURCE_TOOLTIP"])
    else
        AddText(L["NO_PRICE_ADDON_INFO"])
    end

    AddHeader(L["Compatible Addons"])
    for _, name in ipairs(COMPANION_ADDONS) do
        local version
        if addon.Compat.IsAddOnLoaded(name) then
            version = addon.Compat.GetAddOnMetadata(name, "Version") or "?"
        else
            version = L["Not installed"]
        end
        AddText(name .. ": " .. version)
    end

    AddHeader(L["Disclosure"])
    AddText(L["AI_DISCLOSURE_1"])
    AddText(L["AI_DISCLOSURE_2"])

    Settings.RegisterAddOnCategory(category)
end
