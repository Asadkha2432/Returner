local ADDON_NAME = ...

local function meta(k)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, k)
    end
    return GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, k) or nil
end
local ADDON_VERSION = meta("Version") or "?"

local DEFAULTS = {
    threshold      = 7,    -- minimum days away to auto-popup
    enabled        = true, -- master toggle for the auto-popup
    lastSeen       = nil,  -- last login Unix epoch (per-account)
    seenItemsUntil = 0,    -- Unix epoch: items strictly newer than this are "unread"
}

local CATEGORY_COLORS = {
    patch   = "|cffffd200",  -- gold
    event   = "|cff80ff80",  -- green
    hotfix  = "|cffff8060",  -- orange
    news    = "|cffa0c0ff",  -- soft blue
    esports = "|cffd080ff",  -- purple
}

local CATEGORY_LABELS = {
    patch   = "PATCH",
    event   = "EVENT",
    hotfix  = "HOTFIX",
    news    = "NEWS",
    esports = "ESPORTS",
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function pluralize(n, singular, plural)
    return n .. " " .. (n == 1 and singular or plural)
end

local function formatRelative(daysAway)
    if daysAway < 1 then return "today" end
    if daysAway == 1 then return "1 day ago" end
    if daysAway < 30 then return daysAway .. " days ago" end
    if daysAway < 365 then
        local months = math.floor(daysAway / 30)
        return pluralize(months, "month ago", "months ago")
    end
    local years = math.floor(daysAway / 365)
    return pluralize(years, "year ago", "years ago")
end

local function formatDate(ts)
    return date("%b %d, %Y", ts)
end

local function categorizeColor(cat)
    return CATEGORY_COLORS[cat] or "|cffffffff"
end

local function categoryTag(cat)
    return (categorizeColor(cat)) .. (CATEGORY_LABELS[cat] or "NEWS") .. "|r"
end

local function getItemsSince(sinceTs)
    local out = {}
    if not Returner_Data or not Returner_Data.items then return out end
    for _, it in ipairs(Returner_Data.items) do
        if (it.timestamp or 0) > sinceTs then
            table.insert(out, it)
        end
    end
    table.sort(out, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    return out
end

----------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------
local panel
local function buildPanel()
    if panel then return panel end

    panel = CreateFrame("Frame", "ReturnerPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(540, 540)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()

    if panel.TitleContainer and panel.TitleContainer.TitleText then
        panel.TitleContainer.TitleText:SetText("Returner")
    elseif panel.TitleText then
        panel.TitleText:SetText("Returner")
    end

    -- Header (Welcome line)
    panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.header:SetPoint("TOPLEFT", 18, -34)
    panel.header:SetPoint("TOPRIGHT", -18, -34)
    panel.header:SetJustifyH("LEFT")

    panel.subheader = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.subheader:SetPoint("TOPLEFT", panel.header, "BOTTOMLEFT", 0, -4)
    panel.subheader:SetPoint("TOPRIGHT", panel.header, "BOTTOMRIGHT", 0, -4)
    panel.subheader:SetJustifyH("LEFT")

    -- Scroll area for items
    panel.scroll = CreateFrame("ScrollFrame", "ReturnerPanelScroll", panel, "UIPanelScrollFrameTemplate")
    panel.scroll:SetPoint("TOPLEFT", 12, -78)
    panel.scroll:SetPoint("BOTTOMRIGHT", -34, 50)

    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(1, 1)
    panel.scroll:SetScrollChild(panel.content)

    -- Footer: version + dismiss button
    panel.versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.versionText:SetPoint("BOTTOMRIGHT", -14, 16)
    panel.versionText:SetText("v" .. ADDON_VERSION)

    panel.markRead = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.markRead:SetSize(140, 22)
    panel.markRead:SetPoint("BOTTOMLEFT", 14, 14)
    panel.markRead:SetText("Mark all as read")
    panel.markRead:SetScript("OnClick", function()
        ReturnerDB.seenItemsUntil = time()
        panel:Hide()
        print("|cffffd200[Returner]|r Caught up. See you on the next return.")
    end)

    panel.dataInfo = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.dataInfo:SetPoint("BOTTOM", 0, 18)

    return panel
end

local function renderItems(items)
    -- Clear previous children
    if panel.content.children then
        for _, c in ipairs(panel.content.children) do c:Hide(); c:SetParent(nil) end
    end
    panel.content.children = {}

    local y = 0
    local rowWidth = panel.scroll:GetWidth() - 8

    if #items == 0 then
        local empty = panel.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("TOPLEFT", 8, -10)
        empty:SetText("|cff808080Nothing new since your last login.|r\n\nCheck back later, or run |cffffd200/rt|r anytime.")
        empty:SetJustifyH("LEFT")
        empty:SetWidth(rowWidth - 16)
        table.insert(panel.content.children, empty)
        panel.content:SetHeight(60)
        return
    end

    for _, it in ipairs(items) do
        local card = CreateFrame("Frame", nil, panel.content, "BackdropTemplate")
        card:SetSize(rowWidth, 1)
        card:SetPoint("TOPLEFT", 4, -y)
        if card.SetBackdrop then
            card:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            card:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
            card:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        end

        local tag = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tag:SetPoint("TOPLEFT", 10, -8)
        tag:SetText(categoryTag(it.category) .. "  |cff808080" .. formatDate(it.timestamp or 0) .. "|r")

        local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 10, -22)
        title:SetPoint("RIGHT", -10, 0)
        title:SetJustifyH("LEFT")
        title:SetText(it.title or "(untitled)")
        title:SetWordWrap(true)

        local body
        if it.body and it.body ~= "" then
            body = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
            body:SetPoint("RIGHT", -10, 0)
            body:SetJustifyH("LEFT")
            body:SetText(it.body)
            body:SetWordWrap(true)
        end

        local url
        if it.url and it.url ~= "" then
            url = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
            url:SetSize(rowWidth - 40, 18)
            url:SetAutoFocus(false)
            url:SetText(it.url)
            url:SetCursorPosition(0)
            url:SetScript("OnEscapePressed", url.ClearFocus)
            url:SetScript("OnEnterPressed", url.ClearFocus)
            local anchor = body or title
            url:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -6)
        end

        -- Compute card height
        title:SetWidth(rowWidth - 24)
        local h = 8 + 14 + title:GetStringHeight() + 6
        if body then
            body:SetWidth(rowWidth - 24)
            h = h + body:GetStringHeight() + 6
        end
        if url then h = h + 18 + 6 end
        h = h + 10
        card:SetHeight(h)
        y = y + h + 8
        table.insert(panel.content.children, card)
    end

    panel.content:SetHeight(y)
end

local function showPanel(daysAway, lastSeen, now)
    buildPanel()
    if daysAway and daysAway > 0 then
        panel.header:SetText(string.format("Welcome back. You were away for %s.", formatRelative(daysAway)))
    else
        panel.header:SetText("Returner")
    end

    if lastSeen and lastSeen > 0 then
        panel.subheader:SetText(string.format("Last seen: %s", formatDate(lastSeen)))
    else
        panel.subheader:SetText("First time running Returner.")
    end

    local cutoff = ReturnerDB.seenItemsUntil or 0
    local items = getItemsSince(cutoff)
    renderItems(items)

    if Returner_Data and Returner_Data.metadata then
        local m = Returner_Data.metadata
        panel.dataInfo:SetText(string.format("|cff606060Data: %s, %d items, generated %s|r",
            tostring(m.source or "?"),
            m.count or (Returner_Data.items and #Returner_Data.items or 0),
            tostring(m.generated_at or "?")))
    end

    panel:Show()
end

----------------------------------------------------------------------
-- Login flow
----------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    ReturnerDB = ReturnerDB or {}
    for k, v in pairs(DEFAULTS) do
        if ReturnerDB[k] == nil then ReturnerDB[k] = v end
    end

    local now = time()
    local last = ReturnerDB.lastSeen
    local daysAway = last and math.floor((now - last) / 86400) or 0
    local newItems = getItemsSince(ReturnerDB.seenItemsUntil or 0)

    if ReturnerDB.enabled and last and daysAway >= ReturnerDB.threshold and #newItems > 0 then
        C_Timer.After(2, function()
            showPanel(daysAway, last, now)
        end)
    end

    ReturnerDB.lastSeen = now
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_RETURNER1 = "/returner"
SLASH_RETURNER2 = "/rt"
SlashCmdList["RETURNER"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd or ""

    if cmd == "" or cmd == "show" then
        local now = time()
        local last = ReturnerDB.lastSeen or now
        local days = math.floor((now - last) / 86400)
        showPanel(days, last, now)
    elseif cmd == "threshold" then
        local n = tonumber(arg)
        if n and n >= 0 then
            ReturnerDB.threshold = n
            print(string.format("|cffffd200[Returner]|r threshold set to %d days", n))
        else
            print("|cffffd200[Returner]|r usage: /rt threshold <days>")
        end
    elseif cmd == "off" or cmd == "disable" then
        ReturnerDB.enabled = false
        print("|cffffd200[Returner]|r auto-popup disabled. Use /rt to open manually.")
    elseif cmd == "on" or cmd == "enable" then
        ReturnerDB.enabled = true
        print("|cffffd200[Returner]|r auto-popup enabled.")
    elseif cmd == "reset" then
        ReturnerDB.seenItemsUntil = 0
        print("|cffffd200[Returner]|r read state cleared. Next /rt will show all items.")
    elseif cmd == "status" then
        local last = ReturnerDB.lastSeen
        print(string.format("|cffffd200[Returner]|r threshold=%dd, enabled=%s, last seen=%s, seenUntil=%s",
            ReturnerDB.threshold,
            tostring(ReturnerDB.enabled),
            last and formatDate(last) or "never",
            (ReturnerDB.seenItemsUntil and ReturnerDB.seenItemsUntil > 0) and formatDate(ReturnerDB.seenItemsUntil) or "0"))
    elseif cmd == "simulate" then
        local n = tonumber(arg)
        if n and n >= 0 then
            local lastSeen = time() - (n * 86400)
            ReturnerDB.lastSeen = lastSeen
            ReturnerDB.seenItemsUntil = 0
            print(string.format("|cffffd200[Returner]|r simulating %d days away (lastSeen rewound).", n))
            showPanel(n, lastSeen, time())
        else
            print("|cffffd200[Returner]|r usage: /rt simulate <days>")
        end
    else
        print("|cffffd200[Returner]|r commands: /rt | /rt threshold N | /rt on | /rt off | /rt reset | /rt status | /rt simulate N")
    end
end
