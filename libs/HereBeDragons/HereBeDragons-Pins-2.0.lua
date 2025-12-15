-- HereBeDragons-Pins-2.0 3.3.5a Backport (Fixed zone detection v8)
local MAJOR, MINOR = "HereBeDragons-Pins-2.0", 9008
assert(LibStub, MAJOR .. " requires LibStub")

local pins, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not pins then return end

local HBD = LibStub("HereBeDragons-2.0")

pins.updateFrame = pins.updateFrame or CreateFrame("Frame")
pins.minimapPins = pins.minimapPins or {}
pins.minimapPinRegistry = pins.minimapPinRegistry or {}
pins.Minimap = pins.Minimap or Minimap

-- World Map Pins Storage
pins.worldMapPins = pins.worldMapPins or {}
pins.worldMapPinRegistry = pins.worldMapPinRegistry or {}

-- Constants
local MAP_SCALE = 1000  -- Must match HereBeDragons-2.0

-- Zone name to size in yards mapping (more reliable than IDs)
-- Using GetZoneText() for detection since zone IDs vary
local zoneNameToYards = {
    -- Cities
    ["Stormwind City"] = 1000,
    ["Stormwind"] = 1000,
    ["Orgrimmar"] = 1200,
    ["Ironforge"] = 800,
    ["Thunder Bluff"] = 1000,
    ["Darnassus"] = 1000,
    ["Undercity"] = 1200,
    ["The Exodar"] = 1000,
    ["Silvermoon City"] = 1200,
    ["Shattrath City"] = 800,
    ["Dalaran"] = 600,
    
    -- Common zones
    ["Tirisfal Glades"] = 4000,
    ["Dun Morogh"] = 4000,
    ["Elwynn Forest"] = 3500,
    ["Westfall"] = 4000,
    ["Duskwood"] = 3500,
    ["Stranglethorn Vale"] = 5500,
    ["The Barrens"] = 8000,
    ["Mulgore"] = 5000,
    ["Durotar"] = 4500,
    ["Ashenvale"] = 6000,
    ["Hillsbrad Foothills"] = 3000,
    ["Arathi Highlands"] = 4000,
}

-- Use a smaller default for better minimap behavior
local DEFAULT_ZONE_YARDS = 2000

-- Minimap yard ranges by zoom level (outdoor)
local minimapYardRanges = {
    [0] = 233, [1] = 200, [2] = 166, [3] = 133, [4] = 100, [5] = 66
}

local currentZoneName = ""
local function GetZoneSizeYards()
    local zoneName = GetZoneText() or ""
    if zoneName ~= currentZoneName then
        currentZoneName = zoneName
    end
    return zoneNameToYards[zoneName] or DEFAULT_ZONE_YARDS
end

local rotateMinimap = GetCVar("rotateMinimap") == "1"
local minimapWidth, minimapHeight, mapSin, mapCos
local playerX, playerY, playerInstance
local currentZoneYards = DEFAULT_ZONE_YARDS
local currentMinimapYards = 233

local function drawMinimapPin(pin, data)
    if not playerX or not playerY or not playerInstance then return end
    if not data.x or not data.y then return end
    
    -- Calculate delta in normalized coords (0-1 range = full zone width)
    local deltaNormX = (data.x - playerX) / MAP_SCALE
    local deltaNormY = (data.y - playerY) / MAP_SCALE
    
    -- Convert normalized delta to YARDS using zone size
    local deltaYardsX = deltaNormX * currentZoneYards
    local deltaYardsY = deltaNormY * currentZoneYards
    
    -- 3.3.5a coords: X+ = East, Y+ = South
    -- Screen coords: X+ = Right, Y+ = Up (flip Y)
    local screenYardsX = deltaYardsX
    local screenYardsY = -deltaYardsY
    
    -- Apply rotation if enabled
    if rotateMinimap then
        local dx, dy = screenYardsX, screenYardsY
        screenYardsX = dx * mapCos - dy * mapSin
        screenYardsY = dx * mapSin + dy * mapCos
    end
    
    -- Convert yards to minimap pixels
    local yardsToPixels = minimapWidth / currentMinimapYards
    
    local pixelX = screenYardsX * yardsToPixels
    local pixelY = screenYardsY * yardsToPixels
    
    -- Hide pins that are outside the minimap circle
    -- Using 85% of radius to account for pin icon size
    local dist = math.sqrt(pixelX * pixelX + pixelY * pixelY)
    if dist > minimapWidth * 0.85 then
        pin:Hide()
        return
    end
    
    pin:Show()
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", pins.Minimap, "CENTER", pixelX, pixelY)
end

local function UpdateMinimapPins()
    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    if not x or not y or not instanceID then return end
    
    local facing = GetPlayerFacing() or 0
    local zoom = pins.Minimap:GetZoom() or 0
    
    -- Get zone size by name (more reliable than ID)
    currentZoneYards = GetZoneSizeYards()
    currentMinimapYards = minimapYardRanges[zoom] or 233
    
    -- Update rotation
    if rotateMinimap then
        mapSin = math.sin(facing)
        mapCos = math.cos(facing)
    else
        mapSin, mapCos = 0, 1
    end
    
    minimapWidth = pins.Minimap:GetWidth() / 2
    minimapHeight = pins.Minimap:GetHeight() / 2
    
    playerX, playerY = x, y
    playerInstance = instanceID
    
    for pin, data in pairs(pins.minimapPins) do
        if data.instanceID == instanceID then
            drawMinimapPin(pin, data)
        else
            pin:Hide()
        end
    end
end

-- World Map positioning (unchanged - this works correctly)
local function UpdateWorldMapPins()
    if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end
    if not WorldMapDetailFrame then return end
    
    local mapID = GetCurrentMapAreaID()
    local w, h = WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight()
    if w == 0 or h == 0 then return end
    
    for pin, data in pairs(pins.worldMapPins) do
        if data.instanceID == mapID then
            local nX = data.x / MAP_SCALE
            local nY = data.y / MAP_SCALE
            
            if nX >= 0 and nX <= 1 and nY >= 0 and nY <= 1 then
                pin:Show()
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", nX * w, -nY * h)
                pin:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 10)
            else
                pin:Hide()
            end
        else
            pin:Hide()
        end
    end
end

-- Update loop
pins.updateFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.03 then return end
    self.elapsed = 0
    
    UpdateMinimapPins()
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        UpdateWorldMapPins()
    end
end)
pins.updateFrame:Show()

pins.updateFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CVAR_UPDATE" then
        local arg1 = ...
        if arg1 == "rotateMinimap" then
            rotateMinimap = GetCVar("rotateMinimap") == "1"
        end
    elseif event == "WORLD_MAP_UPDATE" then
        UpdateWorldMapPins()
    end
end)
pins.updateFrame:RegisterEvent("CVAR_UPDATE")
pins.updateFrame:RegisterEvent("WORLD_MAP_UPDATE")

-- API Functions
function pins:AddMinimapIconWorld(ref, icon, instanceID, x, y, floatOnEdge)
    if not self.minimapPinRegistry[ref] then self.minimapPinRegistry[ref] = {} end
    self.minimapPinRegistry[ref][icon] = true
    
    self.minimapPins[icon] = {
        instanceID = instanceID,
        x = x,
        y = y,
        floatOnEdge = floatOnEdge
    }
    
    icon:SetParent(self.Minimap)
    icon:SetFrameLevel(self.Minimap:GetFrameLevel() + 5)
end

function pins:RemoveMinimapIcon(ref, icon)
    self.minimapPins[icon] = nil
    icon:Hide()
end

function pins:RemoveAllMinimapIcons(ref)
    if not self.minimapPinRegistry[ref] then return end
    for icon in pairs(self.minimapPinRegistry[ref]) do
        self:RemoveMinimapIcon(ref, icon)
    end
end

function pins:AddWorldMapIconWorld(ref, icon, instanceID, x, y)
    if not self.worldMapPinRegistry[ref] then self.worldMapPinRegistry[ref] = {} end
    self.worldMapPinRegistry[ref][icon] = true
    
    self.worldMapPins[icon] = {
        instanceID = instanceID,
        x = x,
        y = y
    }
    
    if WorldMapDetailFrame then
        icon:SetParent(WorldMapDetailFrame)
        icon:Show()
        icon:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 10)
    end
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        UpdateWorldMapPins()
    end
end

function pins:RemoveWorldMapIcon(ref, icon)
    self.worldMapPins[icon] = nil
    icon:Hide()
end

function pins:RemoveAllWorldMapIcons(ref)
    if not self.worldMapPinRegistry[ref] then return end
    for icon in pairs(self.worldMapPinRegistry[ref]) do
        self:RemoveWorldMapIcon(ref, icon)
    end
end

function pins:SetMinimapObject(obj) self.Minimap = obj or Minimap end
