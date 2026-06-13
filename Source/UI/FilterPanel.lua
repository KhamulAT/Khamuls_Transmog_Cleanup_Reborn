local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("KhamulsTransmogCleanup")

local FilterPanel = {}
addon.FilterPanel = FilterPanel

local COLUMN_WIDTH = 110
-- Rows are tall enough for a two-line wrapped label.
local ROW_HEIGHT = 27
local HEADER_HEIGHT = 16
local PANEL_HEIGHT = HEADER_HEIGHT + 6 * ROW_HEIGHT
local SLIDER_HEIGHT = 34

FilterPanel.height = PANEL_HEIGHT + SLIDER_HEIGHT

local panel
local widgets = {} -- { widget, getter } pairs, synced in Load()
local isLoading = false
local safeguardCheck

local function Filters()
    return addon.db.global.filters
end

-- Confirm before disabling the safeguard: an unsafeguarded sale empties the
-- whole list at once, and anything past the 12 buyback slots is unrecoverable.
StaticPopupDialogs["KHAMULS_TRANSMOG_CLEANUP_DISABLE_SAFEGUARD"] = {
    text = L["SAFEGUARD_DISABLE_WARNING"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        Filters().safeguard = false
        addon.MainFrame:Refresh()
    end,
    OnCancel = function()
        -- Cancelled (or dismissed): keep the safeguard on and re-check the box.
        if safeguardCheck then
            safeguardCheck:SetChecked(true)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

local function GetCheckLabel(check)
    local label = check.Text or check.text
    if not label then
        label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        check.Text = label
    end
    return label
end

local function MakeCheck(labelText, x, y, getter, setter)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("TOPLEFT", x, y)
    local label = GetCheckLabel(check)
    label:SetText(labelText)
    label:SetFontObject("GameFontHighlightSmall")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    label:SetMaxLines(2)
    label:SetWidth(COLUMN_WIDTH - 24)
    check:SetScript("OnClick", function(self)
        if isLoading then return end
        setter(self:GetChecked() and true or false)
        addon.MainFrame:Refresh()
    end)
    widgets[#widgets + 1] = { widget = check, getter = getter }
    return check
end

local function MakeHeader(text, x, y)
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", x, y or 0)
    header:SetText(text)
    return header
end

local function SetCheckEnabled(check, enabled, disabledTooltip)
    check:SetEnabled(enabled)
    local label = GetCheckLabel(check)
    label:SetFontObject(enabled and "GameFontHighlightSmall" or "GameFontDisableSmall")
    if not enabled and disabledTooltip then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(disabledTooltip)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        check:SetScript("OnEnter", nil)
        check:SetScript("OnLeave", nil)
    end
end

local function QualityLabel(quality)
    local color = ITEM_QUALITY_COLORS[quality]
    local name = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
    if color and color.hex then
        return color.hex .. name .. "|r"
    end
    return name
end

local slider, sliderValueText, sliderTimer

local function CreateSlider(parent)
    slider = CreateFrame("Slider", "KhamulsTransmogCleanupIlvlSlider", parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 8, -14)
    slider:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", -8, -14)
    slider:SetMinMaxValues(1, addon.MAX_ITEM_LEVEL)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    local low = slider.Low or _G[slider:GetName() .. "Low"]
    local high = slider.High or _G[slider:GetName() .. "High"]
    local text = slider.Text or _G[slider:GetName() .. "Text"]
    if low then low:SetText("1") end
    if high then high:SetText(tostring(addon.MAX_ITEM_LEVEL)) end
    sliderValueText = text

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        if sliderValueText then
            sliderValueText:SetText(L["MAX_ITEM_LEVEL_LABEL"]:format(value))
        end
        if isLoading then return end
        Filters().maxItemLevel = value
        if sliderTimer then sliderTimer:Cancel() end
        sliderTimer = C_Timer.NewTimer(0.2, function()
            sliderTimer = nil
            addon.MainFrame:Refresh()
        end)
    end)
end

function FilterPanel:Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", 18, -36)
    panel:SetPoint("TOPRIGHT", -18, -36)
    panel:SetHeight(PANEL_HEIGHT)

    -- Retail has no transmog status column (selling teaches the transmog),
    -- so the remaining columns pack to the left.
    local hasStatusColumn = not addon.Compat.IsRetail
    local col1, col2 = 0, COLUMN_WIDTH
    local colStatus = COLUMN_WIDTH * 2
    local nextCol = hasStatusColumn and 3 or 2
    local colExcludes = COLUMN_WIDTH * nextCol
    local colCategories = COLUMN_WIDTH * (nextCol + 1)
    local colSelling = COLUMN_WIDTH * (nextCol + 2)

    MakeHeader(L["Quality"], col1)
    MakeHeader(L["Binding"], col2)
    if hasStatusColumn then
        MakeHeader(L["Transmog status"], colStatus)
    end
    MakeHeader(L["Categories"], colCategories)
    MakeHeader(L["Selling"], colSelling)

    local y = -HEADER_HEIGHT

    -- Column 1: item qualities
    for quality = 0, 5 do
        MakeCheck(QualityLabel(quality), col1, y - quality * ROW_HEIGHT,
            function() return Filters().qualities[quality] end,
            function(value) Filters().qualities[quality] = value end)
    end

    -- Column 2: bind types
    local bindRows = {
        { key = "boe", label = L["BoE"] },
        { key = "bop", label = L["BoP"] },
        { key = "boa", label = L["BoA"] },
        { key = "warbound", label = L["Warbound"] },
        { key = "onUse", label = L["On Use"] },
    }
    for i, row in ipairs(bindRows) do
        local key = row.key
        MakeCheck(row.label, col2, y - (i - 1) * ROW_HEIGHT,
            function() return Filters().bindTypes[key] end,
            function(value) Filters().bindTypes[key] = value end)
    end

    -- Transmog status column (Mists only)
    if hasStatusColumn then
        local statusRows = {
            { key = "learned", label = L["Learned"] },
            { key = "cantBeLearned", label = L["Can't be learned"] },
            { key = "learnableByOther", label = L["Learnable by another character"] },
        }
        self.statusChecks = {}
        for i, row in ipairs(statusRows) do
            local key = row.key
            self.statusChecks[key] = MakeCheck(row.label, colStatus, y - (i - 1) * ROW_HEIGHT,
                function() return Filters().transmogStatus[key] end,
                function(value) Filters().transmogStatus[key] = value end)
        end
    end

    -- Excludes column. The expansion block is retail only (expacID is
    -- unreliable on classic); "other excludes" applies to both clients.
    local otherTop = y
    if addon.Compat.IsRetail then
        MakeHeader(L["Exclude XPac"], colExcludes)
        local expansions = { 11, 10, 9 } -- Midnight, The War Within, Dragonflight
        for i, expacID in ipairs(expansions) do
            local label = _G["EXPANSION_NAME" .. expacID] or tostring(expacID)
            MakeCheck(label, colExcludes, y - (i - 1) * ROW_HEIGHT,
                function() return Filters().excludeExpansions[expacID] end,
                function(value) Filters().excludeExpansions[expacID] = value end)
        end
        otherTop = y - 3 * ROW_HEIGHT - 2
        MakeHeader(L["Other excludes"], colExcludes, otherTop)
        otherTop = otherTop - HEADER_HEIGHT
    else
        MakeHeader(L["Other excludes"], colExcludes)
    end
    MakeCheck(L["Set tokens"], colExcludes, otherTop,
        function() return Filters().excludeSetTokens end,
        function(value) Filters().excludeSetTokens = value end)

    -- Categories column
    local categoryRows = {
        { key = "nonTransmogEquipment", label = L["Non-transmog equipment"] },
        { key = "consumables", label = L["Consumables"] },
        { key = "tradeGoods", label = L["Trade goods"] },
        { key = "junkOther", label = L["Junk & other"] },
    }
    for i, row in ipairs(categoryRows) do
        local key = row.key
        MakeCheck(row.label, colCategories, y - (i - 1) * ROW_HEIGHT,
            function() return Filters().categories[key] end,
            function(value) Filters().categories[key] = value end)
    end

    -- Selling column
    safeguardCheck = MakeCheck(L["Enable safeguard sale"], colSelling, y,
        function() return Filters().safeguard end,
        function(value) Filters().safeguard = value end)
    safeguardCheck:SetScript("OnClick", function(self)
        if isLoading then return end
        if self:GetChecked() then
            Filters().safeguard = true
            addon.MainFrame:Refresh()
        else
            -- Disabling: warn first; the db change is applied only on confirm.
            local sellable = addon.Filters.GetSellableItems(addon.MainFrame.currentItems or {})
            StaticPopup_Show("KHAMULS_TRANSMOG_CLEANUP_DISABLE_SAFEGUARD", #sellable)
        end
    end)

    self.thresholdCheck = MakeCheck(L["Don't sell above auction profit"], colSelling, y - 1 * ROW_HEIGHT,
        function() return Filters().useThreshold end,
        function(value) Filters().useThreshold = value end)

    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(60, 18)
    box:SetPoint("TOPLEFT", colSelling + 28, y - 2 * ROW_HEIGHT - 2)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(7)
    local goldSuffix = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    goldSuffix:SetPoint("LEFT", box, "RIGHT", 4, 0)
    goldSuffix:SetText(GOLD_AMOUNT_SYMBOL or "g")
    local function CommitThreshold(self)
        local value = self:GetNumber() or 0
        Filters().thresholdGold = value
        self:SetText(tostring(value))
        self:ClearFocus()
        addon.MainFrame:Refresh()
    end
    box:SetScript("OnEnterPressed", CommitThreshold)
    box:SetScript("OnEditFocusLost", function(self)
        if isLoading then return end
        CommitThreshold(self)
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.thresholdBox = box
    self.thresholdSuffix = goldSuffix

    MakeCheck(L["Verbose"], colSelling, y - 3 * ROW_HEIGHT,
        function() return Filters().verbose end,
        function(value) Filters().verbose = value end)

    CreateSlider(parent)
end

-- Syncs every widget from the db; called on every show and after options changes.
function FilterPanel:Load()
    if not panel then return end
    isLoading = true

    for _, entry in ipairs(widgets) do
        entry.widget:SetChecked(entry.getter() and true or false)
    end

    if self.statusChecks then -- Mists only; retail has no status column
        local supportsStatus = addon.TransmogStatus:SupportsStatus()
        local supportsOther = addon.TransmogStatus:SupportsOtherChar()
        SetCheckEnabled(self.statusChecks.learned, supportsStatus, L["REQUIRES_TRANSMOG_API"])
        SetCheckEnabled(self.statusChecks.cantBeLearned, supportsStatus, L["REQUIRES_TRANSMOG_API"])
        SetCheckEnabled(self.statusChecks.learnableByOther, supportsOther, L["REQUIRES_CIMI"])
    end

    local priceConfigured = addon.PriceSources:IsConfigured()
    self.thresholdCheck:SetShown(priceConfigured)
    self.thresholdBox:SetShown(priceConfigured)
    self.thresholdSuffix:SetShown(priceConfigured)
    self.thresholdBox:SetText(tostring(Filters().thresholdGold or 0))

    local maxItemLevel = math.min(Filters().maxItemLevel or addon.MAX_ITEM_LEVEL, addon.MAX_ITEM_LEVEL)
    slider:SetValue(maxItemLevel)
    if sliderValueText then
        sliderValueText:SetText(L["MAX_ITEM_LEVEL_LABEL"]:format(maxItemLevel))
    end

    isLoading = false
end
