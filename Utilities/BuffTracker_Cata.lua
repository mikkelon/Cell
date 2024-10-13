local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local I = Cell.iFuncs
local P = Cell.pixelPerfectFuncs
local LCG = LibStub("LibCustomGlow-1.0")
-- local LGI = LibStub:GetLibrary("LibGroupInfo")
local A = Cell.animations

local UnitIsConnected = UnitIsConnected
local UnitIsVisible = UnitIsVisible
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitGUID = UnitGUID
local UnitClassBase = UnitClassBase
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid

-------------------------------------------------
-- buffs
-------------------------------------------------
local buffs = {
    -- 21562: Power Word: Fortitude
    ["PWF"] = {id=21562, glowColor={F:GetClassColor("PRIEST")}, provider="PRIEST", level=14},

    -- 27683: Shadow Protection
    ["SP"] = {id=27683, glowColor={F:GetClassColor("PRIEST")}, provider="PRIEST", level=52},

    -- 1459: Arcane Brilliance
    ["AB"] = {id=1459, id2=79058, glowColor={F:GetClassColor("MAGE")}, provider="MAGE", level=58},

    -- 6673: Battle Shout
    ["BS"] = {id=6673, glowColor={F:GetClassColor("WARRIOR")}, provider="WARRIOR", level=20},

    -- 469: Commanding Shout
    ["CS"] = {id=469, glowColor={F:GetClassColor("WARRIOR")}, provider="WARRIOR", level=68},

    -- 1126: Mark of the Wild
    ["MotW"] = {id=1126, glowColor={F:GetClassColor("DRUID")}, provider="DRUID", level=30},

    -- 20217: Blessing of Kings
    ["BoK"] = {id=20217, glowColor={F:GetClassColor("PALADIN")}, provider="PALADIN", level=22},

    -- 19740: Blessing of Might
    ["BoM"] = {id=19740, glowColor={F:GetClassColor("PALADIN")}, provider="PALADIN", level=56},
}

do
    for _, t in pairs(buffs) do
        local name, icon = F:GetSpellInfo(t["id"])
        t["name"] = name
        t["icon"] = icon

        if t["id2"] then
            t["name2"] = F:GetSpellInfo(t["id2"])
        end
    end
end

local order = {"PWF", "AB", "MotW", "BoK", "BoM", "BS", "CS", "SP"}

-------------------------------------------------
-- required buffs
-------------------------------------------------
local requiredBuffs = {
    ["WARRIOR"] = {["PWF"]=true, ["MotW"]=true, ["BoK"]=true, ["BoM"]=true, ["BS"]=true, ["CS"]=true, ["SP"]=true},
    ["PALADIN"] = {["PWF"]=true, ["AB"]=true, ["MotW"]=true, ["BoK"]=true, ["BoM"]=true, ["BS"]=true, ["CS"]=true, ["SP"]=true},
    ["HUNTER"] = {["PWF"]=true, ["MotW"]=true, ["BoK"]=true, ["BoM"]=true, ["BS"]=true, ["CS"]=true, ["SP"]=true},
    ["ROGUE"] = {["PWF"]=true, ["MotW"]=true, ["BoK"]=true, ["BoM"]=true, ["BS"]=true, ["CS"]=true, ["SP"]=true},
    ["PRIEST"] = {["PWF"]=true, ["AB"]=true, ["MotW"]=true, ["BoK"]=true, ["CS"]=true, ["SP"]=true},
    ["DEATHKNIGHT"] = {["PWF"]=true, ["MotW"]=true, ["BoK"]=true, ["BoM"]=true, ["BS"]=true, ["CS"]=true, ["SP"]=true},
    ["SHAMAN"] = {["PWF"]=true, ["AB"]=true, ["MotW"]=true, ["BoK"]=true, ["BoM"]=true, ["BS"]=true, ["CS"]=true, ["SP"]=true},
    ["MAGE"] = {["PWF"]=true, ["AB"]=true, ["MotW"]=true, ["BoK"]=true, ["CS"]=true, ["SP"]=true},
    ["WARLOCK"] = {["PWF"]=true, ["AB"]=true, ["MotW"]=true, ["BoK"]=true, ["CS"]=true, ["SP"]=true},
    ["DRUID"] = {["PWF"]=true, ["AB"]=true, ["MotW"]=true, ["BoK"]=true, ["BoM"]=true, ["BS"]=true, ["CS"]=true, ["SP"]=true},
}

-------------------------------------------------
-- vars
-------------------------------------------------
local enabled
local myUnit = ""
local hasBuffProvider

local available = {
    ["PWF"] = false,
    ["AB"] = false,
    ["MotW"] = false,
    ["BoK"] = false,
    ["BoM"] = false,
    ["BS"] = false,
    ["CS"] = false,
    ["SP"] = false,
}

local unaffected = {
    ["PWF"] = {},
    ["AB"] = {},
    ["MotW"] = {},
    ["BoK"] = {},
    ["BoM"] = {},
    ["BS"] = {},
    ["CS"] = {},
    ["SP"] = {},
}

local function Reset(which)
    if not which or which == "available" then
        for k, v in pairs(available) do
            available[k] = false
        end
        hasBuffProvider = false
    end

    if not which or which == "unaffected" then
        for k, v in pairs(unaffected) do
            wipe(unaffected[k])
        end
    end
end

function F:GetUnaffectedString(spell)
    local list = unaffected[spell]
    local buff = buffs[spell]["name"]

    local players = {}
    for unit in pairs(list) do
        local name = UnitName(unit)
        tinsert(players, name)
    end

    if #players == 0 then
        return
    elseif #players <= 10 then
        return L["Missing Buff"].." ("..buff.."): "..table.concat(players, ", ")
    else
        return L["Missing Buff"].." ("..buff.."): "..L["many"]
    end
end

-------------------------------------------------
-- frame
-------------------------------------------------
local buffTrackerFrame = CreateFrame("Frame", "CellBuffTrackerFrame", Cell.frames.mainFrame, "BackdropTemplate")
Cell.frames.buffTrackerFrame = buffTrackerFrame
P:Size(buffTrackerFrame, 102, 50)
PixelUtil.SetPoint(buffTrackerFrame, "BOTTOMLEFT", UIParent, "CENTER", 1, 1)
buffTrackerFrame:SetClampedToScreen(true)
buffTrackerFrame:SetMovable(true)
buffTrackerFrame:RegisterForDrag("LeftButton")
buffTrackerFrame:SetScript("OnDragStart", function()
    buffTrackerFrame:StartMoving()
    buffTrackerFrame:SetUserPlaced(false)
end)
buffTrackerFrame:SetScript("OnDragStop", function()
    buffTrackerFrame:StopMovingOrSizing()
    P:SavePosition(buffTrackerFrame, CellDB["tools"]["buffTracker"][4])
end)

-------------------------------------------------
-- mover
-------------------------------------------------
buffTrackerFrame.moverText = buffTrackerFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
buffTrackerFrame.moverText:SetPoint("TOP", 0, -3)
buffTrackerFrame.moverText:SetText(L["Mover"])
buffTrackerFrame.moverText:Hide()

local fakeIconsFrame = CreateFrame("Frame", nil, buffTrackerFrame)
P:Point(fakeIconsFrame, "BOTTOMRIGHT", buffTrackerFrame)
P:Point(fakeIconsFrame, "TOPLEFT", buffTrackerFrame, "TOPLEFT", 0, -18)
fakeIconsFrame:EnableMouse(true)
fakeIconsFrame:SetFrameLevel(buffTrackerFrame:GetFrameLevel()+10)
fakeIconsFrame:Hide()

local fakeIcons = {}
local function CreateFakeIcon(spellIcon)
    local bg = fakeIconsFrame:CreateTexture(nil, "BORDER")
    bg:SetColorTexture(0, 0, 0, 1)
    P:Size(bg, 32, 32)

    local icon = fakeIconsFrame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(spellIcon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    P:Point(icon, "TOPLEFT", bg, "TOPLEFT", 1, -1)
    P:Point(icon, "BOTTOMRIGHT", bg, "BOTTOMRIGHT", -1, 1)

    function bg:UpdatePixelPerfect()
        P:Resize(bg)
        P:Repoint(bg)
        P:Repoint(icon)
    end

    return bg
end

do
    for _, k in ipairs(order) do
        tinsert(fakeIcons, CreateFakeIcon(buffs[k]["icon"]))
    end
end

local function ShowMover(show)
    if show then
        if not CellDB["tools"]["buffTracker"][1] then return end
        buffTrackerFrame:EnableMouse(true)
        buffTrackerFrame.moverText:Show()
        Cell:StylizeFrame(buffTrackerFrame, {0, 1, 0, 0.4}, {0, 0, 0, 0})
        fakeIconsFrame:Show()
        buffTrackerFrame:SetAlpha(1)
    else
        buffTrackerFrame:EnableMouse(false)
        buffTrackerFrame.moverText:Hide()
        Cell:StylizeFrame(buffTrackerFrame, {0, 0, 0, 0}, {0, 0, 0, 0})
        fakeIconsFrame:Hide()
        buffTrackerFrame:SetAlpha(CellDB["tools"]["fadeOut"] and 0 or 1)
    end
end
Cell:RegisterCallback("ShowMover", "BuffTracker_ShowMover", ShowMover)

-------------------------------------------------
-- buttons
-------------------------------------------------
local sendChannel
local function UpdateSendChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        sendChannel = "INSTANCE_CHAT"
    elseif IsInRaid() then
        sendChannel = "RAID"
    else
        sendChannel = "PARTY"
    end
end

local function CreateBuffButton(parent, size, spell, icon, index)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    if parent then b:SetFrameLevel(parent:GetFrameLevel()+1) end
    P:Size(b, size[1], size[2])

    b:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P:Scale(1)})
    b:SetBackdropBorderColor(0, 0, 0, 1)

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "LeftButtonDown", "RightButtonDown") -- NOTE: ActionButtonUseKeyDown will affect this
    b:SetAttribute("type1", "macro")
    b:SetAttribute("macrotext1", "/cast [@player] "..spell)
    b:HookScript("OnClick", function(self, button, down)
        if button == "RightButton" and (down == GetCVarBool("ActionButtonUseKeyDown")) then
            local msg = F:GetUnaffectedString(index)
            if msg then
                UpdateSendChannel()
                SendChatMessage(msg, sendChannel)
            end
        end
    end)

    b.texture = b:CreateTexture(nil, "OVERLAY")
    P:Point(b.texture, "TOPLEFT", b, "TOPLEFT", 1, -1)
    P:Point(b.texture, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.texture:SetTexture(icon)
    b.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.count = b:CreateFontString(nil, "OVERLAY")
    P:Point(b.count, "TOPLEFT", b.texture, "TOPLEFT", 2, -2)
    b.count:SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
    b.count:SetShadowColor(0, 0, 0)
    b.count:SetShadowOffset(0, 0)
    b.count:SetTextColor(1, 0, 0)

    b:SetScript("OnLeave", function()
        CellTooltip:Hide()
    end)

    function b:SetTooltips(list)
        b:SetScript("OnEnter", function()
            if F:Getn(list) ~= 0 then
                CellTooltip:SetOwner(b, "ANCHOR_TOPLEFT", 0, 3)
                CellTooltip:AddLine(L["Unaffected"])
                for unit in pairs(list) do
                    local class = UnitClassBase(unit)
                    local name = UnitName(unit)
                    if class and name then
                        CellTooltip:AddLine(F:GetClassColorStr(class)..name.."|r")
                    end
                end
                CellTooltip:Show()
            end
        end)
    end

    function b:SetDesaturated(flag)
        b.texture:SetDesaturated(flag)
    end

    function b:StartGlow(glowType, ...)
        if glowType == "Normal" then
            LCG.PixelGlow_Stop(b)
            LCG.AutoCastGlow_Stop(b)
            LCG.ButtonGlow_Start(b, ...)
        elseif glowType == "Pixel" then
            LCG.ButtonGlow_Stop(b)
            LCG.AutoCastGlow_Stop(b)
            -- color, N, frequency, length, thickness
            LCG.PixelGlow_Start(b, ...)
        elseif glowType == "Shine" then
            LCG.ButtonGlow_Stop(b)
            LCG.PixelGlow_Stop(b)
            LCG.AutoCastGlow_Stop(b)
            -- color, N, frequency, scale
            LCG.AutoCastGlow_Start(b, ...)
        end
    end

    function b:StopGlow()
        LCG.ButtonGlow_Stop(b)
        LCG.PixelGlow_Stop(b)
        LCG.AutoCastGlow_Stop(b)
    end

    function b:Reset()
        b.texture:SetDesaturated(false)
        b.count:SetText("")
        b:SetAlpha(1)
        b:StopGlow()
    end

    function b:UpdatePixelPerfect()
        P:Resize(b)
        P:Repoint(b)
        b:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P:Scale(1)})
        b:SetBackdropBorderColor(0, 0, 0, 1)

        P:Repoint(b.texture)
        P:Repoint(b.count)
    end

    return b
end

local buttons = {}

do
    for _, k in ipairs(order) do
        buttons[k] = CreateBuffButton(buffTrackerFrame, {32, 32}, buffs[k]["name"], buffs[k]["icon"], k)
        buttons[k]:Hide()
        buttons[k]:SetTooltips(unaffected[k])
    end
end

local paladinBuffs = {"BoK", "BoM"}
local warriorBuffs = {"BS", "CS"}
local function UpdateButtons()
    -- NOTE: check paladin buffs
    local paladinBuffsFound = 0
    for _, k in pairs(paladinBuffs) do
        if AuraUtil.FindAuraByName(buffs[k]["name"], "player", "BUFF") then
            paladinBuffsFound = paladinBuffsFound + 1
        end
    end

    -- NOTE: check warrior buffs
    local warriorBuffsFound = 0
    for _, k in pairs(warriorBuffs) do
        if AuraUtil.FindAuraByName(buffs[k]["name"], "player", "BUFF") then
            warriorBuffsFound = warriorBuffsFound + 1
        end
    end

    for _, k in ipairs(order) do
        if available[k] then
            local n = F:Getn(unaffected[k])
            if n == 0 then
                buttons[k].count:SetText("")
                buttons[k]:SetAlpha(0.5)
                buttons[k]:StopGlow()
            else
                buttons[k].count:SetText(n)
                buttons[k]:SetAlpha(1)
                if unaffected[k][myUnit] then
                    local showGlow
                    if strfind(k, "^Bo") then
                        showGlow = paladinBuffsFound < available[k]
                    elseif k == "BS" or k == "CS" then
                        showGlow = warriorBuffsFound < available[k]
                    else
                        showGlow = true
                    end

                    if showGlow then
                        -- color, N, frequency, length, thickness
                        buttons[k]:StartGlow("Pixel", buffs[k]["glowColor"], 8, 0.25, P:Scale(8), P:Scale(2))
                    else
                        buttons[k]:StopGlow()
                    end
                else
                    buttons[k]:StopGlow()
                end
            end
        end
    end
end

local function RepointButtons()
    if InCombatLockdown() then
        buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        local point, relativePoint, offsetX, offsetY, firstX, firstY
        if CellDB["tools"]["buffTracker"][2] == "left-to-right" then
            point, relativePoint = "BOTTOMLEFT", "BOTTOMRIGHT"
            offsetX, offsetY = 3, 0
            firstX, firstY = 0, 0
        elseif CellDB["tools"]["buffTracker"][2] == "right-to-left" then
            point, relativePoint = "BOTTOMRIGHT", "BOTTOMLEFT"
            offsetX, offsetY = -3, 0
            firstX, firstY = 0, 0
        elseif CellDB["tools"]["buffTracker"][2] == "top-to-bottom" then
            point, relativePoint = "TOPLEFT", "BOTTOMLEFT"
            offsetX, offsetY = 0, -3
            firstX, firstY = 0, -18
        elseif CellDB["tools"]["buffTracker"][2] == "bottom-to-top" then
            point, relativePoint = "BOTTOMLEFT", "TOPLEFT"
            offsetX, offsetY = 0, 3
            firstX, firstY = 0, 0
        end

        local last
        for _, k in pairs(order) do
            P:ClearPoints(buttons[k])
            if available[k] then
                buttons[k]:Show()
                if last then
                    P:Point(buttons[k], point, last, relativePoint, offsetX, offsetY)
                else
                    P:Point(buttons[k], point, firstX, firstY)
                end
                last = buttons[k]
            else
                buttons[k]:Hide()
                buttons[k]:Reset()
            end
        end

        last = nil
        for _, icon in pairs(fakeIcons) do
            P:ClearPoints(icon)
            if last then
                P:Point(icon, point, last, relativePoint, offsetX, offsetY)
            else
                P:Point(icon, point, buffTrackerFrame, point, firstX, firstY)
            end
            last = icon
        end
    end
end

local function ResizeButtons()
    if InCombatLockdown() then
        buffTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        local size = CellDB["tools"]["buffTracker"][3]
        for _, i in pairs(fakeIcons) do
            P:Size(i, size, size)
        end
        for _, b in pairs(buttons) do
            P:Size(b, size, size)
        end

        local n = F:Getn(buttons)
        if strfind(CellDB["tools"]["buffTracker"][2], "left") then
            buffTrackerFrame:SetSize(n * P:Scale(size) + (n - 1) * P:Scale(3), P:Scale(size + 18))
        else
            buffTrackerFrame:SetSize(P:Scale(size), n * P:Scale(size) + (n - 1) * P:Scale(3) + P:Scale(18))
        end
    end
end

-------------------------------------------------
-- fade out
-------------------------------------------------
local fadeOuts = {}
for _, b in pairs(buttons) do
    tinsert(fadeOuts, b)
end
A:ApplyFadeInOutToParent(buffTrackerFrame, function()
    return CellDB["tools"]["fadeOut"] and not buffTrackerFrame.moverText:IsShown()
end, unpack(fadeOuts))

-------------------------------------------------
-- check
-------------------------------------------------
local function HasMyBuff(unit, _buffs)
    for _, b in pairs(_buffs) do
        local source = select(7, AuraUtil.FindAuraByName(buffs[b]["name"], unit, "BUFF,PLAYER"))
        if source == "player" then
            return true
        end
    end
end

local function CheckUnit(unit, updateBtn)
    I.HideMissingBuffs(unit)

    -- print("CheckUnit", unit)
    if not hasBuffProvider then return end

    if UnitIsConnected(unit) and UnitIsVisible(unit) and not UnitIsDeadOrGhost(unit) then
        local required = requiredBuffs[UnitClassBase(unit)]
        for k, v in pairs(available) do
            if v ~= false and required[k] then
                if not (AuraUtil.FindAuraByName(buffs[k]["name"], unit, "BUFF") or (buffs[k]["name2"] and AuraUtil.FindAuraByName(buffs[k]["name2"], unit, "BUFF"))) then
                    unaffected[k][unit] = true

                    -- NOTE: don't check paladin/warrior shit here
                    if not strfind(k, "^Bo") and k ~= "BS" and k ~= "CS" then
                        I.ShowMissingBuff(unit, k, buffs[k]["icon"], Cell.vars.playerClass == buffs[k]["provider"])
                    end
                else
                    unaffected[k][unit] = nil
                end
            end
        end

        -- NOTE: check shits
        if Cell.vars.playerClass == "PALADIN" then
            if not HasMyBuff(unit, paladinBuffs) then
                I.ShowMissingBuff(unit, "PALADIN", 254882, true)
            end
        elseif Cell.vars.playerClass == "WARRIOR" then
            if not HasMyBuff(unit, warriorBuffs) then
                I.ShowMissingBuff(unit, "WARRIOR", 254882, true)
            end
        end

    else
        for k, t in pairs(unaffected) do
            t[unit] = nil
        end
    end

    if updateBtn then UpdateButtons() end
end

local function IterateAllUnits()
    Reset("available")
    myUnit = ""

    for unit in F:IterateGroupMembers() do
        if UnitIsConnected(unit) and UnitIsVisible(unit) then
            if UnitClassBase(unit) == "PRIEST" then
                if UnitLevel(unit) >= buffs["PWF"]["level"] then
                    available["PWF"] = true
                    hasBuffProvider = true
                end
                if UnitLevel(unit) >= buffs["SP"]["level"] then
                    available["SP"] = true
                    hasBuffProvider = true
                end

            elseif UnitClassBase(unit) == "MAGE" then
                if UnitLevel(unit) >= buffs["AB"]["level"] then
                    available["AB"] = true
                    hasBuffProvider = true
                end

            elseif UnitClassBase(unit) == "WARRIOR" then
                if UnitLevel(unit) >= buffs["BS"]["level"] then
                    available["BS"] = (available["BS"] or 0) + 1
                    hasBuffProvider = true
                end
                if UnitLevel(unit) >= buffs["CS"]["level"] then
                    available["CS"] = (available["CS"] or 0) + 1
                    hasBuffProvider = true
                end

            elseif UnitClassBase(unit) == "PALADIN" then
                if UnitLevel(unit) >= buffs["BoK"]["level"] then
                    available["BoK"] = (available["BoK"] or 0) + 1
                    hasBuffProvider = true
                end
                if UnitLevel(unit) >= buffs["BoM"]["level"] then
                    available["BoM"] = (available["BoM"] or 0) + 1
                    hasBuffProvider = true
                end

            elseif UnitClassBase(unit) == "DRUID" then
                if UnitLevel(unit) >= buffs["MotW"]["level"] then
                    available["MotW"] = true
                    hasBuffProvider = true
                end
            end

            if UnitIsUnit("player", unit) then
                myUnit = unit
            end
        end
    end

    RepointButtons()

    Reset("unaffected")

    for unit in F:IterateGroupMembers() do
        CheckUnit(unit)
    end

    UpdateButtons()
end

-------------------------------------------------
-- events
-------------------------------------------------
-- function buffTrackerFrame:UnitUpdated(event, guid, unit, info)
--     if unit == "player" then
--         if UnitIsUnit("player", myUnit) then CheckUnit(myUnit, true) end
--     elseif UnitIsPlayer(unit) then -- ignore pets
--         CheckUnit(unit, true)
--     end
-- end

function buffTrackerFrame:PLAYER_ENTERING_WORLD()
    buffTrackerFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    buffTrackerFrame:GROUP_ROSTER_UPDATE()
end

local timer
function buffTrackerFrame:GROUP_ROSTER_UPDATE(immediate)
    if timer then timer:Cancel() end
    if IsInGroup() then
        buffTrackerFrame:RegisterEvent("READY_CHECK")
        buffTrackerFrame:RegisterEvent("UNIT_FLAGS")
        buffTrackerFrame:RegisterEvent("PLAYER_UNGHOST")
        buffTrackerFrame:RegisterEvent("UNIT_AURA")
        -- buffTrackerFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
        -- buffTrackerFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
    else
        buffTrackerFrame:UnregisterEvent("READY_CHECK")
        buffTrackerFrame:UnregisterEvent("UNIT_FLAGS")
        buffTrackerFrame:UnregisterEvent("PLAYER_UNGHOST")
        buffTrackerFrame:UnregisterEvent("UNIT_AURA")
        -- buffTrackerFrame:UnregisterEvent("PARTY_MEMBER_ENABLE")
        -- buffTrackerFrame:UnregisterEvent("PARTY_MEMBER_DISABLE")

        Reset()
        RepointButtons()
        return
    end

    if immediate then
        IterateAllUnits()
    else
        timer = C_Timer.NewTimer(2, IterateAllUnits)
    end
end

function buffTrackerFrame:READY_CHECK()
    buffTrackerFrame:GROUP_ROSTER_UPDATE(true)
end

function buffTrackerFrame:UNIT_FLAGS()
    buffTrackerFrame:GROUP_ROSTER_UPDATE()
end

function buffTrackerFrame:PLAYER_UNGHOST()
    buffTrackerFrame:GROUP_ROSTER_UPDATE()
end

-- function buffTrackerFrame:PARTY_MEMBER_ENABLE()
--     buffTrackerFrame:GROUP_ROSTER_UPDATE()
-- end

-- function buffTrackerFrame:PARTY_MEMBER_DISABLE()
--     buffTrackerFrame:GROUP_ROSTER_UPDATE()
-- end

function buffTrackerFrame:UNIT_AURA(unit)
    if IsInRaid() then
        if string.match(unit, "raid%d") then
            CheckUnit(unit, true)
        end
    else
        if string.match(unit, "party%d") or unit=="player" then
            CheckUnit(unit, true)
        end
    end
end

function buffTrackerFrame:PLAYER_REGEN_ENABLED()
    buffTrackerFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    RepointButtons()
    ResizeButtons()
end

buffTrackerFrame:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)

-------------------------------------------------
-- functions
-------------------------------------------------
local function UpdateTools(which)
    if not which or which == "buffTracker" then
        if CellDB["tools"]["buffTracker"][1] then
            buffTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            buffTrackerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
            -- LGI.RegisterCallback(buffTrackerFrame, "GroupInfo_UpdateBase", "UnitUpdated")

            if not enabled and which == "buffTracker" then -- already in world, manually enabled
                buffTrackerFrame:GROUP_ROSTER_UPDATE(true)
            end
            enabled = true
            if Cell.vars.showMover then
                ShowMover(true)
            end
        else
            buffTrackerFrame:UnregisterAllEvents()
            -- LGI.UnregisterCallback(buffTrackerFrame, "GroupInfo_UpdateBase")

            Reset()
            myUnit = ""

            enabled = false
            ShowMover(false)

            -- missingBuffs indicator
            for unit in F:IterateGroupMembers() do
                I.HideMissingBuffs(unit, true)
            end
        end

        RepointButtons()
        ResizeButtons()
    end

    if not which or which == "fadeOut" then
        if CellDB["tools"]["fadeOut"] and not buffTrackerFrame.moverText:IsShown() then
            buffTrackerFrame:SetAlpha(0)
        else
            buffTrackerFrame:SetAlpha(1)
        end
    end

    if not which then -- position
        P:LoadPosition(buffTrackerFrame, CellDB["tools"]["buffTracker"][4])
    end
end
Cell:RegisterCallback("UpdateTools", "BuffTracker_UpdateTools", UpdateTools)

local function UpdatePixelPerfect()
    -- P:Resize(buffTrackerFrame)

    for _, i in pairs(fakeIcons) do
        i:UpdatePixelPerfect()
    end

    for _, b in pairs(buttons) do
        b:UpdatePixelPerfect()
    end
end
Cell:RegisterCallback("UpdatePixelPerfect", "BuffTracker_UpdatePixelPerfect", UpdatePixelPerfect)