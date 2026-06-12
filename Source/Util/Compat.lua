local _, addon = ...

-- Resolves API namespace drift between Retail and MoP Classic once,
-- so the rest of the addon never branches on client flavor.
local Compat = {}
addon.Compat = Compat

Compat.IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

Compat.GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
Compat.GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
Compat.GetDetailedItemLevelInfo = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
Compat.IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
Compat.GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
