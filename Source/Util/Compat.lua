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
-- The addon-query APIs raise a Lua error when handed a name that is not
-- installed at all (as opposed to installed-but-disabled), so every lookup of
-- an OptionalDeps entry goes through these guards: a companion addon the user
-- chose not to install must never be able to break this one.

-- True only when the named addon is installed and loaded.
function Compat.IsOptionalAddOnLoaded(name)
    local ok, loaded = pcall(Compat.IsAddOnLoaded, name)
    return (ok and loaded) and true or false
end

-- Version string of a loaded companion addon, or nil when it is unavailable.
function Compat.GetOptionalAddOnVersion(name)
    if not Compat.IsOptionalAddOnLoaded(name) then return nil end
    local ok, version = pcall(Compat.GetAddOnMetadata, name, "Version")
    return (ok and version) or "?"
end
