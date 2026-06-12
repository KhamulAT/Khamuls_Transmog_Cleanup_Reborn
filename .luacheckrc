std = "lua51"
max_line_length = false
self = false

exclude_files = {
    "Libs/",
    "Referenced_Extensions/",
    "Release_Archive/",
    "bin/",
}

globals = {
    "KhamulsTransmogCleanupOptionsTextMixin",
}

read_globals = {
    -- Libraries / companion addons
    "LibStub",
    "CanIMogIt",
    "Auctionator",
    "TSM_API",

    -- WoW API namespaces
    "C_AddOns",
    "C_Container",
    "C_Item",
    "C_Timer",
    "C_TooltipInfo",
    "C_TransmogCollection",
    "Enum",
    "Settings",

    -- WoW API functions
    "CreateFrame",
    "CreateSettingsListSectionHeaderInitializer",
    "GetAddOnMetadata",
    "GetDetailedItemLevelInfo",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetMoneyString",
    "HandleModifiedItemClick",
    "IsAddOnLoaded",
    "IsModifiedClick",
    "Item",

    -- Frames / globals
    "GameTooltip",
    "MerchantFrame",
    "UIParent",

    -- Constants
    "GOLD_AMOUNT_SYMBOL",
    "ITEM_ACCOUNTBOUND",
    "ITEM_ACCOUNTBOUND_UNTIL_EQUIP",
    "ITEM_BIND_ON_EQUIP",
    "ITEM_BIND_ON_USE",
    "ITEM_BIND_TO_ACCOUNT",
    "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP",
    "ITEM_BIND_TO_BNETACCOUNT",
    "ITEM_BNETACCOUNTBOUND",
    "ITEM_CLASSES_ALLOWED",
    "ITEM_QUALITY_COLORS",
    "ITEM_SOULBOUND",
    "NUM_BAG_SLOTS",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
}
