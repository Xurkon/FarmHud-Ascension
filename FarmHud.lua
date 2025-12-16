-------------------------------------------------------------------------------
-- FarmHud v2.0.0
-- A transparent HUD for farming herbs and ore
-- Modernized for 3.3.5a with generic addon compatibility
-- Rewritten to avoid taint issues
-------------------------------------------------------------------------------

local addon, ns = ...
ns.L = ns.L or setmetatable({}, { __index = function(t, k) return k end }) -- Localization fallback

-- Reference the XML-defined FarmHud frame (don't create new - that overwrites it!)
-- The XML frame has cluster and TextFrame children we need
local FarmHud = _G.FarmHud or CreateFrame("Frame", addon, UIParent)
ns.FarmHud = FarmHud

-- Note: FarmHudMixin and FarmHudMinimapDummyMixin are defined in FarmHud_Mixins.lua
-- which loads before this file to prevent nil errors in XML scripts

-- Mixin function for module compatibility
ns.Mixin = function(object, mixin)
    for k, v in pairs(mixin) do object[k] = v end
    return object
end
-- Global Mixin for modules
Mixin = Mixin or ns.Mixin

-- Helper functions for Options.lua compatibility
ns.print = function(...) print("FarmHud:", ...) end
ns.debug = function() end
ns.SetShown = function(f, s) if f then if s then f:Show() else f:Hide() end end end
ns.IsClassic = function() return false end
ns.IsRetail = function() return false end
ns.IsDragonFlight = function() return false end
ns.GetContinentID = function() return 0 end -- Stub for 3.3.5a
ns.debugPrint = function() end              -- Debug print stub

-- C_AddOns polyfill for 3.3.5a
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = C_AddOns.IsAddOnLoaded or function(name) return IsAddOnLoaded(name) end

-- GetTrackingTypes for Options.lua
local trackingTypes, numTrackingTypes = {}, 0
function ns.GetTrackingTypes()
    local num = GetNumTrackingTypes and GetNumTrackingTypes() or 0
    if numTrackingTypes ~= num then
        numTrackingTypes = num
        wipe(trackingTypes)
        for i = 1, num do
            local name, texture, active, category = GetTrackingInfo(i)
            if texture then
                trackingTypes[texture] = { index = i, name = name, active = active, subType = category }
            end
        end
    end
    return trackingTypes
end

-- Modules table (empty for now - modules can be added later)
ns.modules = setmetatable({}, {
    __call = function() end
})

-------------------------------------------------------------------------------
-- Create HUD Container Frame
-- This frame acts as the parent for Minimap when HUD is active
-------------------------------------------------------------------------------
local FarmHudMapCluster = CreateFrame("Frame", "FarmHudMapCluster", UIParent)
FarmHudMapCluster:SetFrameStrata("BACKGROUND")
FarmHudMapCluster:SetAllPoints(UIParent)
FarmHudMapCluster:Hide()

-- Create custom player arrow frame (for player_dot option)
local playerArrowFrame = CreateFrame("Frame", "FarmHudPlayerArrow", FarmHudMapCluster)
playerArrowFrame:SetFrameStrata("HIGH")
playerArrowFrame:SetSize(32, 32)
playerArrowFrame:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, 0)

local playerArrowTexture = playerArrowFrame:CreateTexture(nil, "OVERLAY")
playerArrowTexture:SetAllPoints(playerArrowFrame)
playerArrowTexture:SetTexture("Interface\\Minimap\\MinimapArrow")

-------------------------------------------------------------------------------
-- Range Circles (dynamic add/remove support)
-- Uses media/gathercircle.tga texture for each circle
-------------------------------------------------------------------------------
local rangeCircleFrames = {} -- Store circle frames

-- Create or update a single range circle frame
local function CreateRangeCircleFrame(index)
    if rangeCircleFrames[index] then return rangeCircleFrames[index] end

    local frame = CreateFrame("Frame", "FarmHudRangeCircle" .. index, FarmHudMapCluster)
    frame:SetFrameStrata("LOW")
    frame:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, 0)
    frame:Hide() -- Start hidden, UpdateRangeCircles will show if needed

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetTexture("Interface\\AddOns\\FarmHud\\media\\gathercircle")
    texture:SetAllPoints(frame)
    texture:SetVertexColor(0, 1, 0, 0.5)

    frame.texture = texture
    rangeCircleFrames[index] = frame
    return frame
end

-- Update all range circles based on settings
local function UpdateRangeCircles()
    if not FarmHudMapCluster:IsShown() then return end
    if not FarmHudDB or not FarmHudDB.rangeCircles then return end

    local hudSize = FarmHudMapCluster:GetWidth()
    if hudSize <= 0 then hudSize = 500 end

    -- Hide all existing circles first
    for _, frame in pairs(rangeCircleFrames) do
        frame:Hide()
    end

    -- Show and update configured circles
    for i, settings in ipairs(FarmHudDB.rangeCircles) do
        if settings.show then
            local frame = CreateRangeCircleFrame(i)
            local circleSize = hudSize * (settings.scale or 0.45)
            frame:SetSize(circleSize, circleSize)
            frame.texture:SetVertexColor(
                settings.r or 0,
                settings.g or 1,
                settings.b or 0,
                settings.a or 0.5
            )
            frame:Show()
        end
    end
end

-- Store update function for later use
FarmHud.UpdateRangeCircles = UpdateRangeCircles
-- Backwards compatibility
FarmHud.UpdateGatherCircle = UpdateRangeCircles


-------------------------------------------------------------------------------
-- Libraries
-------------------------------------------------------------------------------
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local HUD_SCALE = 1.4
local CARDINAL_DIRECTIONS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
local UPDATE_INTERVAL = 1 / 90 -- ~90 FPS for smooth rotation

-- Player dot texture paths (for player_dot option)
local PLAYER_DOT_TEXTURES = {
    ["blizz"] = nil,         -- Use Blizzard default (don't change)
    ["blizz-smaller"] = nil, -- Use Blizzard default with smaller size
    ["gold"] = "Interface\\AddOns\\FarmHud\\Art\\player_dot_gold",
    ["white"] = "Interface\\AddOns\\FarmHud\\Art\\player_dot_white",
    ["black"] = "Interface\\AddOns\\FarmHud\\Art\\player_dot_black",
    ["hide"] = "HIDE", -- Special value to hide player model
}

-------------------------------------------------------------------------------
-- State variables
-------------------------------------------------------------------------------
local originalRotateSetting
local originalMinimapParent
local originalMinimapPoint = {}
local originalMinimapAlpha
local originalMinimapSize = {} -- Save original minimap size
local originalMinimapZoom      -- Save original minimap zoom
local directions = {}
local updateTotal = 0
local playerDot, gatherCircle, mouseWarn

-------------------------------------------------------------------------------
-- LibDataBroker launcher
-------------------------------------------------------------------------------
local dataObject
if LDB then
    dataObject = LDB:NewDataObject(addon, {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Herb_MountainSilverSage",
        label = addon,
        text = addon,
        OnTooltipShow = function(tt)
            tt:AddLine("FarmHud")
            tt:AddLine("|cffffff00Click|r to toggle FarmHud")
            tt:AddLine("|cffffff00Right click|r to config")
            tt:AddLine("Or macro with /script FarmHud:Toggle()")
        end,
        OnClick = function(_, button)
            if button == "LeftButton" then
                FarmHud:Toggle()
            else
                FarmHud:OpenOptions()
            end
        end
    })
end

-------------------------------------------------------------------------------
-- Keybinding headers
-------------------------------------------------------------------------------
BINDING_HEADER_FARMHUD = addon
BINDING_NAME_TOGGLEFARMHUD = "Toggle FarmHud's Display"
BINDING_NAME_TOGGLEFARMHUDMOUSE = "Toggle FarmHud's tooltips (Can't click through Hud)"

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
SLASH_FARMHUD1 = "/farmhud"
SLASH_FARMHUD2 = "/fh"

SlashCmdList["FARMHUD"] = function(msg)
    msg = msg:lower():trim()

    if msg == "" or msg == "toggle" then
        -- Toggle HUD
        FarmHud:Toggle()
    elseif msg == "options" or msg == "config" or msg == "settings" then
        -- Open options panel
        FarmHud:OpenOptions()
    elseif msg == "mouse" then
        -- Toggle mouse
        FarmHud:MouseToggle()
    elseif msg == "help" then
        print("|cFFFFCC00FarmHud Commands:|r")
        print("  /farmhud or /fh - Toggle HUD")
        print("  /farmhud options - Open options panel")
        print("  /farmhud mouse - Toggle mouse interaction")
        print("  /farmhud help - Show this help")
    else
        print("|cFFFFCC00FarmHud:|r Unknown command. Type /farmhud help for commands.")
    end
end

-------------------------------------------------------------------------------
-- Addon Compatibility Layer
-------------------------------------------------------------------------------

-- Reparent addon-specific pins using their APIs
local function ReparentAddonPins(targetParent)
    -- GatherMate2
    if GatherMate2 and FarmHudDB.show_gathermate then
        pcall(function()
            local display = GatherMate2:GetModule("Display")
            if display and display.ReparentMinimapPins then
                display:ReparentMinimapPins(targetParent)
                display:ChangedVars(nil, "ROTATE_MINIMAP", "1")
            end
        end)
    end

    -- Routes
    if Routes and Routes.ReparentMinimap and FarmHudDB.show_routes then
        pcall(function()
            Routes:ReparentMinimap(targetParent)
            Routes:CVAR_UPDATE(nil, "ROTATE_MINIMAP", "1")
        end)
    end

    -- NPCScan.Overlay
    local NPCScan = _NPCScan and _NPCScan.Overlay and _NPCScan.Overlay.Modules and _NPCScan.Overlay.Modules.List
    if NPCScan and NPCScan["Minimap"] and NPCScan["Minimap"].SetMinimapFrame and FarmHudDB.show_npcscan then
        pcall(function()
            NPCScan["Minimap"]:SetMinimapFrame(targetParent)
        end)
    end
end

-- Restore addon-specific pins to Minimap
local function RestoreAddonPins()
    -- GatherMate2
    if GatherMate2 then
        pcall(function()
            local display = GatherMate2:GetModule("Display")
            if display and display.ReparentMinimapPins then
                display:ReparentMinimapPins(Minimap)
                display:ChangedVars(nil, "ROTATE_MINIMAP", originalRotateSetting or "0")
            end
        end)
    end

    -- Routes
    if Routes and Routes.ReparentMinimap then
        pcall(function()
            Routes:ReparentMinimap(Minimap)
            Routes:CVAR_UPDATE(nil, "ROTATE_MINIMAP", originalRotateSetting or "0")
        end)
    end

    -- NPCScan.Overlay
    local NPCScan = _NPCScan and _NPCScan.Overlay and _NPCScan.Overlay.Modules and _NPCScan.Overlay.Modules.List
    if NPCScan and NPCScan["Minimap"] and NPCScan["Minimap"].SetMinimapFrame then
        pcall(function()
            NPCScan["Minimap"]:SetMinimapFrame(Minimap)
        end)
    end

    -- HandyNotes - refresh minimap pins
    if HandyNotes and HandyNotes.UpdateMinimap then
        pcall(function()
            HandyNotes:UpdateMinimap()
        end)
    end
end

-------------------------------------------------------------------------------
-- HUD Visual Updates
-------------------------------------------------------------------------------

local function UpdateCardinalDirections(bearing)
    -- Check if cardinal points should be shown
    if FarmHudDB and FarmHudDB.show_cardinal_points == false then
        for _, dir in ipairs(directions) do
            dir:Hide()
        end
        return
    end

    -- Calculate radius based on settings
    local baseRadius
    if FarmHudDB and FarmHudDB.cardinal_bind_to_circle then
        -- Bind to gather circle size
        local circleSize = gatherCircle and gatherCircle:GetWidth() or 140
        baseRadius = circleSize * 0.5
    else
        -- Use distance from center percentage
        local distance = (FarmHudDB and FarmHudDB.cardinal_distance) or 30
        baseRadius = 140 * (distance / 100)
    end

    for _, dir in ipairs(directions) do
        local x = math.sin(dir.rad + bearing) * baseRadius
        local y = math.cos(dir.rad + bearing) * baseRadius
        dir:ClearAllPoints()
        dir:SetPoint("CENTER", FarmHudMapCluster, "CENTER", x * HUD_SCALE, y * HUD_SCALE)
        dir:Show()
    end
end

local function OnUpdate(self, elapsed)
    updateTotal = updateTotal + elapsed
    if updateTotal < UPDATE_INTERVAL then return end
    updateTotal = updateTotal - UPDATE_INTERVAL

    -- Ensure MinimapCluster stays hidden
    if MinimapCluster:IsVisible() then
        MinimapCluster:Hide()
    end

    -- Update cardinal direction positions based on player facing
    local bearing = GetPlayerFacing() or 0
    UpdateCardinalDirections(bearing)
end

-------------------------------------------------------------------------------
-- HUD Size and Scale
-------------------------------------------------------------------------------

function FarmHud:SetScales()
    local eScale = UIParent:GetEffectiveScale()
    local width, height = WorldFrame:GetSize()
    if width == 0 or height == 0 then
        width = GetScreenWidth() * eScale
        height = GetScreenHeight() * eScale
    end
    width, height = width / eScale, height / eScale
    local size = min(width, height)

    -- Clamp size to actual screen height
    local screenH = UIParent:GetHeight()
    if size > screenH then size = screenH end
    if size <= 0 then size = 768 end -- Fallback

    -- hudSize controls overall HUD size as percentage of screen
    -- hud_scale controls minimap pin/symbol scaling (for addon compatibility)
    local hudSize = FarmHudDB.hud_size or 1
    local hudScale = FarmHudDB.hud_scale or 1.4
    local HudSize = size * hudSize
    local MinimapScaledSize = HudSize / hudScale

    -- FarmHudMapCluster is NOT scaled - range circles go here
    FarmHudMapCluster:SetSize(HudSize, HudSize)

    -- Minimap IS scaled with hud_scale - this scales addon pins (Routes, HandyNotes, etc.)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, 0)
    Minimap:SetScale(hudScale)
    Minimap:SetSize(MinimapScaledSize, MinimapScaledSize)

    -- Update cardinal direction radius (based on visual HUD size)
    local radius = HudSize * 0.5 * 0.85 -- 85% from center
    for _, dir in ipairs(directions) do
        dir.radius = radius
    end
end

-------------------------------------------------------------------------------
-- Show/Hide Logic
-------------------------------------------------------------------------------

local function SaveMinimapState()
    -- Save original minimap parent
    originalMinimapParent = Minimap:GetParent()

    -- Save original minimap position
    local point, relativeTo, relativePoint, xOfs, yOfs = Minimap:GetPoint()
    originalMinimapPoint = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs
    }

    -- Save original alpha
    originalMinimapAlpha = Minimap:GetAlpha()

    -- Save original size
    originalMinimapSize.width = Minimap:GetWidth()
    originalMinimapSize.height = Minimap:GetHeight()

    -- Save original zoom and lock it
    originalMinimapZoom = Minimap:GetZoom()
end

-- Track hidden Minimap children (ElvUI panels, etc.)
local hiddenMinimapChildren = {}

-- Global frames attached to minimap area that should be hidden during HUD
local ELVUI_MINIMAP_FRAMES = {
    "LayerPickerFrame",          -- Instance selector
    "RightMiniPanel",            -- ElvUI minimap panel
    "LeftMiniPanel",             -- ElvUI minimap panel
    "MinimapPanel",              -- Generic minimap panel
    "MinimapButtonFrame",        -- Minimap buttons
    "MiniMapInstanceDifficulty", -- Instance difficulty indicator
    "GuildInstanceDifficulty",   -- Guild difficulty indicator
}

local function HideMinimapChildren()
    wipe(hiddenMinimapChildren)

    -- Hide specific global ElvUI frames by name
    for _, frameName in ipairs(ELVUI_MINIMAP_FRAMES) do
        local frame = _G[frameName]
        if frame and frame:IsShown() then
            hiddenMinimapChildren[frame] = true
            frame:Hide()
        end
    end

    -- Get all children of Minimap frame and hide those that are visible
    for _, child in pairs({ Minimap:GetChildren() }) do
        if child and child:IsShown() then
            -- Skip addon-specific frames we want to keep (like Routes, GatherMate pins)
            local name = child:GetName() or ""
            -- Only hide frames that look like UI elements (not pins)
            -- ElvUI typically uses names containing "ElvUI" or "Difficulty"
            if name:match("ElvUI") or name:match("Difficulty") or name:match("Instance") or name:match("Button") or name:match("Panel") then
                hiddenMinimapChildren[child] = true
                child:Hide()
            end
        end
    end

    -- Also get all regions (textures, fontstrings) and hide non-essential ones
    for _, region in pairs({ Minimap:GetRegions() }) do
        if region and region:IsShown() then
            local regionType = region:GetObjectType()
            if regionType == "Texture" then
                -- Check if it's a decorative texture (border, backdrop)
                local tex = region:GetTexture()
                if tex and (tex:match("Border") or tex:match("Overlay") or tex:match("Background")) then
                    hiddenMinimapChildren[region] = true
                    region:Hide()
                end
            end
        end
    end
end

local function RestoreMinimapChildren()
    for obj in pairs(hiddenMinimapChildren) do
        if obj and obj.Show then
            obj:Show()
        end
    end
    wipe(hiddenMinimapChildren)
end

local function RestoreMinimapState()
    -- Only restore if state was actually saved
    if not originalMinimapParent then
        return
    end

    -- Restore parent
    Minimap:SetParent(originalMinimapParent)

    -- Restore position
    if originalMinimapPoint.point then
        Minimap:ClearAllPoints()
        -- Use MinimapCluster as fallback if relativeTo is nil
        local relativeTo = originalMinimapPoint.relativeTo or MinimapCluster
        Minimap:SetPoint(
            originalMinimapPoint.point,
            relativeTo,
            originalMinimapPoint.relativePoint or originalMinimapPoint.point,
            originalMinimapPoint.xOfs or 0,
            originalMinimapPoint.yOfs or 0
        )
    end

    -- Restore scale
    Minimap:SetScale(1)

    -- Restore size
    if originalMinimapSize.width and originalMinimapSize.height then
        Minimap:SetSize(originalMinimapSize.width, originalMinimapSize.height)
    end

    -- Restore alpha
    if originalMinimapAlpha then
        Minimap:SetAlpha(originalMinimapAlpha)
    end

    -- Restore zoom (wrapped in pcall for ElvUI compatibility)
    if originalMinimapZoom then
        pcall(function() Minimap:SetZoom(originalMinimapZoom) end)
    end
end

-------------------------------------------------------------------------------
-- Quest Arrow Hiding
-- Based on FarmHud_QuestArrow approach - directly access addon arrow objects
-------------------------------------------------------------------------------
local arrowVisibilityState = {} -- Track which arrows were visible before hiding

local function HideQuestArrows()
    if not FarmHudDB.hide_quest_arrow then return end

    -- Clear previous state
    wipe(arrowVisibilityState)

    -- TomTom - toggle profile setting instead of direct hide (preserves addon arrow state)
    if TomTom and TomTom.profile and TomTom.profile.arrow then
        if TomTom.profile.arrow.enable and TomTom.crazyArrow and TomTom.crazyArrow:IsVisible() then
            arrowVisibilityState.TomTomEnable = true
            TomTom.profile.arrow.enable = false
            TomTom.crazyArrow:Hide()
        end
    end

    -- pfQuest arrow - need to toggle config, not just hide (OnUpdate re-shows it)
    if pfQuest_config and pfQuest_config["arrow"] then
        if pfQuest_config["arrow"] == "1" then
            arrowVisibilityState.pfQuestConfig = pfQuest_config["arrow"]
            pfQuest_config["arrow"] = "0"
            -- Also hide immediately
            if pfQuest and pfQuest.route and pfQuest.route.arrow then
                pfQuest.route.arrow:Hide()
            end
        end
    end

    -- QuestHelper
    if QHArrowFrame then
        if QHArrowFrame:IsVisible() then
            arrowVisibilityState.QuestHelper = true
            QHArrowFrame:Hide()
        end
    end

    -- Questie (if available)
    if Questie and Questie.arrow then
        if Questie.arrow:IsVisible() then
            arrowVisibilityState.Questie = true
            Questie.arrow:Hide()
        end
    end

    -- Global frame fallbacks
    local globalFrames = {
        "TomTomCrazyArrow",
        "pfQuestRouteArrow", -- pfQuest arrow global name
        "DugisArrowFrame",
        "ZygorGuidesViewerPointer",
    }
    for _, frameName in ipairs(globalFrames) do
        local frame = _G[frameName]
        if frame and frame:IsVisible() then
            arrowVisibilityState[frameName] = true
            frame:Hide()
        end
    end
end

local function ShowQuestArrows()
    -- TomTom - restore enable setting
    if arrowVisibilityState.TomTomEnable and TomTom and TomTom.profile and TomTom.profile.arrow then
        TomTom.profile.arrow.enable = true
        -- Call ShowHideCrazyArrow to properly restore the arrow
        if TomTom.ShowHideCrazyArrow then
            TomTom:ShowHideCrazyArrow()
        end
    end

    -- pfQuest - restore config
    if arrowVisibilityState.pfQuestConfig and pfQuest_config then
        pfQuest_config["arrow"] = arrowVisibilityState.pfQuestConfig
    end

    -- QuestHelper
    if arrowVisibilityState.QuestHelper and QHArrowFrame then
        QHArrowFrame:Show()
    end

    -- Questie
    if arrowVisibilityState.Questie and Questie and Questie.arrow then
        Questie.arrow:Show()
    end

    -- Global frame fallbacks
    local globalFrames = { "TomTomCrazyArrow", "pfQuestRouteArrow", "DugisArrowFrame", "ZygorGuidesViewerPointer" }
    for _, frameName in ipairs(globalFrames) do
        if arrowVisibilityState[frameName] then
            local frame = _G[frameName]
            if frame then
                frame:Show()
            end
        end
    end

    wipe(arrowVisibilityState)
end

local function OnShow()
    -- Store original minimap rotation setting
    originalRotateSetting = GetCVar("rotateMinimap")

    -- Apply rotation setting from options (default true = rotate)
    if FarmHudDB.rotation ~= false then
        SetCVar("rotateMinimap", "1")
    else
        SetCVar("rotateMinimap", "0")
    end

    -- Save minimap state before modifying
    SaveMinimapState()

    -- Reparent Minimap to our HUD container
    Minimap:SetParent(FarmHudMapCluster)

    -- Hide ElvUI elements and other minimap children that shouldn't show on HUD
    HideMinimapChildren()

    -- Make minimap background transparent (only show pins)
    Minimap:SetAlpha(0)

    -- Reparent addon pins
    ReparentAddonPins(Minimap)

    -- Set scales and position
    FarmHud:SetScales()

    -- Disable minimap mouse on HUD
    Minimap:EnableMouse(false)
    Minimap:EnableMouseWheel(false) -- Prevent scroll wheel from zooming

    -- Hide original minimap cluster
    MinimapCluster:Hide()

    -- Hide quest arrows from other addons if setting is enabled
    HideQuestArrows()

    -- Start update loop
    FarmHud:SetScript("OnUpdate", OnUpdate)

    -- Enable coords and time display if configured
    FarmHud:UpdateCoords(FarmHudDB.coords_show)
    FarmHud:UpdateTime(FarmHudDB.time_show)

    -- Apply player dot setting
    FarmHud:UpdateOptions("player_dot")

    -- Update gather circle
    if FarmHud.UpdateGatherCircle then
        FarmHud.UpdateGatherCircle()
    end

    -- Dispatch to modules that have OnShow
    for modName, mod in pairs(ns.modules) do
        if mod.OnShow then
            pcall(mod.OnShow)
        end
    end
end

local function OnHide()
    -- Restore minimap rotation setting
    SetCVar("rotateMinimap", originalRotateSetting or "0")

    -- Restore addon pins
    RestoreAddonPins()

    -- Restore ElvUI elements and other minimap children
    RestoreMinimapChildren()

    -- Restore minimap state (parent, position, scale, alpha)
    RestoreMinimapState()

    -- Ensure minimap is visible
    Minimap:Show()

    -- Re-enable minimap mouse
    Minimap:EnableMouse(true)
    Minimap:EnableMouseWheel(true) -- Restore scroll wheel zooming

    -- Show original minimap cluster
    MinimapCluster:Show()

    -- Restore quest arrows that we hid
    ShowQuestArrows()

    -- Stop update loop
    FarmHud:SetScript("OnUpdate", nil)

    -- Disable coords and time display
    FarmHud:UpdateCoords(false)
    FarmHud:UpdateTime(false)

    -- Restore native minimap player arrow
    Minimap:SetPlayerTexture("Interface\\Minimap\\MinimapArrow")

    -- Dispatch to modules that have OnHide
    for modName, mod in pairs(ns.modules) do
        if mod.OnHide then
            pcall(mod.OnHide)
        end
    end
end

-------------------------------------------------------------------------------
-- Coordinates Display
-------------------------------------------------------------------------------
-- Create coords text on the visible frame
local coordsText = FarmHudMapCluster:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
coordsText:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, 100)
coordsText:SetTextColor(1, 0.82, 0, 0.7)
coordsText:Hide()

local coordsUpdater = CreateFrame("Frame")
coordsUpdater:Hide()
coordsUpdater:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer > 0.04 then
        local x, y = GetPlayerMapPosition("player")
        if x and y and (x > 0 or y > 0) then
            coordsText:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
        else
            coordsText:SetText("")
        end
        self.timer = 0
    end
end)

function FarmHud:UpdateCoords(state)
    if state then
        coordsUpdater:Show()
        coordsText:Show()
    else
        coordsUpdater:Hide()
        coordsText:Hide()
    end
end

-------------------------------------------------------------------------------
-- Time Display
-------------------------------------------------------------------------------
-- Create time text on the visible frame
local timeText = FarmHudMapCluster:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
timeText:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, 80)
timeText:SetTextColor(1, 0.82, 0, 0.7)
timeText:Hide()

local timeUpdater = CreateFrame("Frame")
timeUpdater:Hide()
timeUpdater:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer > 1.0 then
        local timeStr = {}
        if FarmHudDB.time_server then
            local sH, sM = GetGameTime()
            tinsert(timeStr, format("%02d:%02d", sH, sM))
        end
        if FarmHudDB.time_local then
            tinsert(timeStr, date("%H:%M"))
            if #timeStr == 2 then
                timeStr[1] = "R: " .. timeStr[1]
                timeStr[2] = "L: " .. timeStr[2]
            end
        end
        timeText:SetText(table.concat(timeStr, " / "))
        self.timer = 0
    end
end)

function FarmHud:UpdateTime(state)
    if state then
        timeUpdater:Show()
        timeText:Show()
    else
        timeUpdater:Hide()
        timeText:Hide()
    end
end

-------------------------------------------------------------------------------
-- Auto-Hide Event Handler (Combat / Instance)
-------------------------------------------------------------------------------
local autoHideFrame = CreateFrame("Frame")
autoHideFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
autoHideFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leaving combat
autoHideFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA") -- Zone change
autoHideFrame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Login/teleport

autoHideFrame:SetScript("OnEvent", function(self, event)
    if not FarmHudMapCluster:IsVisible() then return end

    if event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat
        if FarmHudDB.hideInCombat then
            FarmHudMapCluster:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended - no auto-show, user must toggle back on
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        -- Zone changed - check if in instance
        if FarmHudDB.hideInInstance then
            local inInstance, instanceType = IsInInstance()
            if inInstance and instanceType ~= "none" then
                FarmHudMapCluster:Hide()
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function FarmHud:Toggle(flag)
    if flag == nil then
        if FarmHudMapCluster:IsVisible() then
            FarmHudMapCluster:Hide()
        else
            FarmHudMapCluster:Show()
        end
    else
        if flag then
            FarmHudMapCluster:Show()
        else
            FarmHudMapCluster:Hide()
        end
    end
end

function FarmHud:MouseToggle()
    if Minimap:IsMouseEnabled() then
        Minimap:EnableMouse(false)
        if mouseWarn then mouseWarn:Hide() end
    else
        Minimap:EnableMouse(true)
        if mouseWarn then mouseWarn:Show() end
    end
end

-- OpenOptions using Ace3 config dialog
function FarmHud:OpenOptions()
    local ACD = LibStub("AceConfigDialog-3.0", true)
    if ACD then
        ACD:Open(addon)
    else
        InterfaceOptionsFrame_OpenToCategory(addon)
        InterfaceOptionsFrame_OpenToCategory(addon) -- Called twice due to Blizzard bug
    end
end

-- UpdateOptions - called by FarmHud_Options.lua when settings change
function FarmHud:UpdateOptions(key)
    if not self:IsVisible() and not FarmHudMapCluster:IsVisible() then return end

    -- Handle specific option changes
    if key == "show_cardinal_points" then
        self:UpdateCardinalVisibility()
    elseif key == "cardinal_distance" or key == "cardinal_bind_to_circle" then
        self:UpdateCardinalPositions()
    elseif key == "hud_scale" or key == "hud_size" then
        self:SetScales()
        -- Coords options
    elseif key == "coords_show" then
        self:UpdateCoords(FarmHudDB.coords_show)
    elseif key == "coords_color" then
        local c = FarmHudDB.coords_color or { 1, 0.82, 0, 0.7 }
        coordsText:SetTextColor(unpack(c))
    elseif key == "coords_bottom" or key == "coords_radius" then
        local radius = (FarmHudDB.coords_radius or 0.51) * 200
        local yOffset = FarmHudDB.coords_bottom and -radius or radius
        coordsText:ClearAllPoints()
        coordsText:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, yOffset)
        -- Time options
    elseif key == "time_show" then
        self:UpdateTime(FarmHudDB.time_show)
    elseif key == "time_color" then
        local c = FarmHudDB.time_color or { 1, 0.82, 0, 0.7 }
        timeText:SetTextColor(unpack(c))
    elseif key == "time_bottom" or key == "time_radius" then
        local radius = (FarmHudDB.time_radius or 0.48) * 200
        local yOffset = FarmHudDB.time_bottom and -radius or radius
        timeText:ClearAllPoints()
        timeText:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, yOffset)
    elseif key == "time_server" or key == "time_local" then
        -- Time format changes are handled in the updater
        -- General options
    elseif key == "rotation" then
        local rotVal = FarmHudDB.rotation and "1" or "0"
        SetCVar("rotateMinimap", rotVal)
    elseif key == "text_scale" then
        -- Apply text scale to cardinal points
        local scale = FarmHudDB.text_scale or 1.4
        for _, dir in ipairs(directions) do
            local font, _, flags = dir:GetFont()
            if font then
                dir:SetFont(font, 14 * scale, flags)
            end
        end
    elseif key == "player_dot" then
        -- Player dot/arrow texture change using custom overlay
        local dotType = FarmHudDB.player_dot or "blizz"
        local tex

        if dotType == "hide" then
            -- Hide custom arrow
            playerArrowFrame:Hide()
            return
        elseif dotType == "blizz" then
            -- Default Blizzard arrow
            tex = "Interface\\Minimap\\MinimapArrow"
        else
            -- Custom textures from media folder
            tex = "Interface\\AddOns\\FarmHud\\media\\playerDot-" .. dotType
        end

        -- Show and set texture on custom arrow
        playerArrowTexture:SetTexture(tex)
        playerArrowFrame:Show()

        -- Hide native minimap arrow
        Minimap:SetPlayerTexture("")
    elseif key == "hideInInstance" or key == "hideInCombat" then
        -- These are handled by event handlers, no immediate action needed
    elseif key == "background_alpha" or key == "background_alpha2" then
        local alpha = FarmHudDB.background_alpha_toggle and FarmHudDB.background_alpha or FarmHudDB.background_alpha2
        Minimap:SetAlpha(alpha or 0)
    elseif key == "MinimapIcon" then
        local LDBIcon = LibStub("LibDBIcon-1.0", true)
        if LDBIcon then
            if FarmHudDB.MinimapIcon and FarmHudDB.MinimapIcon.hide then
                LDBIcon:Hide("FarmHud")
            else
                LDBIcon:Show("FarmHud")
            end
        end
    end
end

function FarmHud:UpdateCardinalVisibility()
    local show = FarmHudDB.show_cardinal_points ~= false -- Default to true if nil
    for _, dir in ipairs(directions) do
        if show then
            dir:Show()
        else
            dir:Hide()
        end
    end
end

function FarmHud:UpdateCardinalPositions()
    -- This is called when settings change
    -- Cardinal positions are recalculated every frame in OnUpdate
    -- No action needed here - the OnUpdate loop will pick up the new settings
end

-------------------------------------------------------------------------------
-- Create HUD Elements
-------------------------------------------------------------------------------

local function CreateHUDElements()
    -- Note: Range circles are now managed by UpdateRangeCircles() function
    -- The old gatherCircle texture has been removed to prevent duplicate circles

    -- Player dot
    playerDot = FarmHudMapCluster:CreateTexture(nil, "OVERLAY")
    playerDot:SetTexture([[Interface\GLUES\MODELS\UI_Tauren\gradientCircle.blp]])
    playerDot:SetBlendMode("ADD")
    playerDot:SetPoint("CENTER")
    playerDot:SetWidth(15)
    playerDot:SetHeight(15)

    -- Cardinal directions
    local radius = 140 * 0.214              -- Initial radius, will be updated
    for i, text in ipairs(CARDINAL_DIRECTIONS) do
        local rot = (0.785398163 * (i - 1)) -- 45 degrees in radians
        local dir = FarmHudMapCluster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dir:SetText(text)
        dir:SetShadowOffset(0.2, -0.2)
        dir.rad = rot
        dir.rot = rot -- CardinalPoints module expects this
        dir.radius = radius
        -- Mark N/E/S/W vs NE/SE/SW/NW for coloring
        dir.NWSE = (text == "N" or text == "E" or text == "S" or text == "W")
        table.insert(directions, dir)
    end

    -- Mouse warning text
    mouseWarn = FarmHudMapCluster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mouseWarn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, 50)
    mouseWarn:SetText("MOUSE ON")
    mouseWarn:Hide()

    -- Create FarmHud.TextFrame for CardinalPoints module compatibility
    -- The XML parentKey doesn't work in 3.3.5a so we create it manually
    if not FarmHud.TextFrame then
        FarmHud.TextFrame = CreateFrame("Frame", nil, FarmHud)
        FarmHud.TextFrame:SetAllPoints()
    end
    FarmHud.TextFrame.cardinalPoints = directions
    FarmHud.TextFrame.ScaledHeight = UIParent:GetHeight() / (FarmHudDB.text_scale or 1)

    -- Also expose cluster frame for compatibility
    if not FarmHud.cluster then
        FarmHud.cluster = FarmHudMapCluster
    end
end

-------------------------------------------------------------------------------
-- Initialize Database
-------------------------------------------------------------------------------

local function InitializeDB()
    if not FarmHudDB then
        FarmHudDB = {}
    end

    if not FarmHudDB.MinimapIcon then
        FarmHudDB.MinimapIcon = {
            hide = false,
            minimapPos = 220,
            radius = 80,
        }
    end

    if FarmHudDB.show_gathermate == nil then
        FarmHudDB.show_gathermate = true
    end

    if FarmHudDB.show_routes == nil then
        FarmHudDB.show_routes = true
    end

    if FarmHudDB.show_npcscan == nil then
        FarmHudDB.show_npcscan = true
    end

    -- Cardinal points defaults
    if FarmHudDB.show_cardinal_points == nil then
        FarmHudDB.show_cardinal_points = true
    end

    if FarmHudDB.cardinal_bind_to_circle == nil then
        FarmHudDB.cardinal_bind_to_circle = false
    end

    if FarmHudDB.cardinal_distance == nil then
        FarmHudDB.cardinal_distance = 30 -- Default distance from center (percentage)
    end
end

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

function FarmHud:PLAYER_LOGIN()
    InitializeDB()

    -- Register options panel
    if ns.RegisterOptions then
        ns.RegisterOptions()
    end

    -- Register minimap icon
    if LDBIcon and dataObject then
        LDBIcon:Register(addon, dataObject, FarmHudDB.MinimapIcon)
    end

    -- Setup FarmHudMapCluster
    FarmHudMapCluster:SetAlpha(FarmHudDB.hud_alpha or 0.7)

    -- Create visual elements
    CreateHUDElements()

    -- Setup show/hide scripts
    FarmHudMapCluster:SetScript("OnShow", OnShow)
    FarmHudMapCluster:SetScript("OnHide", OnHide)
end

function FarmHud:PLAYER_LOGOUT()
    self:Toggle(false)
end

-- Hide in combat support
function FarmHud:PLAYER_REGEN_DISABLED()
    if FarmHudDB.hide_in_combat and FarmHudMapCluster:IsVisible() then
        self._wasVisibleBeforeCombat = true
        self:Toggle(false)
    end
end

function FarmHud:PLAYER_REGEN_ENABLED()
    if self._wasVisibleBeforeCombat then
        self._wasVisibleBeforeCombat = nil
        self:Toggle(true)
    end
end

-- Hide in instances support
function FarmHud:ZONE_CHANGED_NEW_AREA()
    if FarmHudDB.hide_in_instances then
        local inInstance, instanceType = IsInInstance()
        if inInstance and FarmHudMapCluster:IsVisible() then
            self._wasVisibleBeforeInstance = true
            self:Toggle(false)
        elseif not inInstance and self._wasVisibleBeforeInstance then
            self._wasVisibleBeforeInstance = nil
            self:Toggle(true)
        end
    end
end

-------------------------------------------------------------------------------
-- Event Handler
-------------------------------------------------------------------------------

FarmHud:SetScript("OnEvent", function(self, event, ...)
    -- Dispatch to FarmHud handlers
    if self[event] then
        self[event](self, ...)
    end

    -- Dispatch to modules that have event handlers
    for modName, mod in pairs(ns.modules) do
        if mod.events and mod.events[event] then
            pcall(mod.events[event], ...)
        end
    end
end)

FarmHud:RegisterEvent("PLAYER_LOGIN")
FarmHud:RegisterEvent("PLAYER_LOGOUT")
FarmHud:RegisterEvent("PLAYER_REGEN_DISABLED")
FarmHud:RegisterEvent("PLAYER_REGEN_ENABLED")
FarmHud:RegisterEvent("ZONE_CHANGED_NEW_AREA")
FarmHud:RegisterEvent("PLAYER_ENTERING_WORLD")
