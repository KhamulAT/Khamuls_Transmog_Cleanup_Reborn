local L = LibStub("AceLocale-3.0"):NewLocale("KhamulsTransmogCleanup", "enUS", true)
if not L then return end

L["ADDON_TITLE"] = "Khamul's Transmog Cleanup Reborn"

-- Filter panel
L["Quality"] = true
L["Binding"] = true
L["Transmog status"] = true
L["Transmog settings"] = true
L["Categories"] = true
L["Excludes"] = true
L["Auction settings"] = true
L["Options"] = true
L["BoE"] = true
L["BoP"] = true
L["BoA"] = true
L["Warbound"] = true
L["On Use"] = true
L["Learned"] = true
L["Can't be learned"] = true
L["Learnable by another character"] = true
L["Non-transmog equipment"] = true
L["Consumables"] = true
L["Trade goods"] = true
L["Junk & other"] = true
L["Selling"] = true
L["Enable safeguard sale"] = true
L["Don't sell above auction profit"] = true
L["Except unlearned transmog"] = true
L["Verbose"] = true
L["Exclude XPac"] = true
L["Exclude items from XPac"] = true
L["Other excludes"] = true
L["Set tokens"] = true
L["MAX_ITEM_LEVEL_LABEL"] = "Max item level: %s"
L["REQUIRES_TRANSMOG_API"] = "Transmog status is not available on this client."
L["REQUIRES_CIMI"] = "Requires the CanIMogIt addon."

-- Item list
L["Item"] = true
L["ilvl"] = true
L["Status"] = true
L["Vendor"] = true
L["Auction"] = true
L["IGNORE_TOOLTIP"] = "Ignore this item - it will never be sold."

-- Statuses
L["Learnable by you"] = true
L["Will be learned on sale"] = true
L["Not transmoggable"] = true
L["Loading..."] = true
L["Consumable"] = true
L["Junk"] = true
L["Other"] = true
L["Above threshold"] = true

-- Buttons
L["Hide"] = true
L["Sell the items!"] = true
L["SELL_BUTTON_SAFEGUARD"] = "Sell the items! (max %d)"
L["VENDOR_SUM"] = "Total: %s"
L["AUCTION_SUM"] = "Auction: %s"

-- Selling
L["SOLD_ITEM"] = "Sold %s for %s."
L["SOLD_SUMMARY"] = "Sold %d item(s) for %s."
L["SOLD_MORE_REMAINING"] = "Safeguard: more items remain - check the buyback tab, then click again for the next batch."
L["SAFEGUARD_DISABLE_WARNING"] = "All %d item(s) marked to be sold will be sold at once when you click \"Sell the items!\". If more than 12 items are sold, those beyond the 12 buyback slots cannot be bought back if sold by mistake.\n\nDisable the safeguard sale?"

-- Options
L["None"] = true
L["Price source"] = true
L["PRICE_SOURCE_TOOLTIP"] = "Select which addon provides the auction price column and the sale threshold."
L["NO_PRICE_ADDON_INFO"] = "Install and enable Auctionator or TradeSkillMaster to use auction price features."
L["Setup Price Source"] = true
L["Compatible Addons"] = true
L["Disclosure"] = true
L["Not installed"] = true
L["AI_DISCLOSURE_1"] = "This addon was created partially with the help of agentic AI coding tools."
L["AI_DISCLOSURE_2"] = "All functionality and code were reviewed and controlled."
