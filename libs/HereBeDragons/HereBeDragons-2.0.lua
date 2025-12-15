-- HereBeDragons-2.0 3.3.5a Backport (Simplified v3)
local MAJOR, MINOR = "HereBeDragons-2.0", 9003
assert(LibStub, MAJOR .. " requires LibStub")

local HereBeDragons, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not HereBeDragons then return end

local CBH = LibStub("CallbackHandler-1.0")

HereBeDragons.eventFrame = HereBeDragons.eventFrame or CreateFrame("Frame")
HereBeDragons.callbacks = HereBeDragons.callbacks or CBH:New(HereBeDragons, nil, nil, false)

local currentPlayerUIMapID

-- 3.3.5a Coordinate System:
-- GetPlayerMapPosition returns normalized (0-1) coordinates
-- X: 0 = West edge, 1 = East edge (X increases East)
-- Y: 0 = NORTH edge, 1 = SOUTH edge (Y increases South/Down on map)

-- This library uses a consistent "map units" system:
-- We keep coordinates as normalized values (0-1) multiplied by a standard scale
-- This ensures consistent behavior across zones

local MAP_SCALE = 1000  -- Arbitrary scale for precision

-- Get player position in map units
-- Returns: x (East+), y (South+, as per 3.3.5a convention), mapID
-- IMPORTANT: Must call SetMapToCurrentZone() first in 3.3.5a to get fresh position data
-- BUT only when FarmHud is visible and world map is not (to avoid interfering with normal minimap)
function HereBeDragons:GetPlayerWorldPosition()
    -- Only refresh map when:
    -- 1. FarmHud is visible (we need accurate position for HUD display)
    -- 2. World map is not open (to not interfere with user zooming)
    -- When FarmHud is hidden, we don't need fresh position data and shouldn't interfere with minimap
    if FarmHud and FarmHud:IsVisible() and (not WorldMapFrame or not WorldMapFrame:IsVisible()) then
        SetMapToCurrentZone()
    end
    local x, y = GetPlayerMapPosition("player")
    if not x or not y or (x <= 0 and y <= 0) then return nil, nil, nil end
    local mapID = GetCurrentMapAreaID()
    return x * MAP_SCALE, y * MAP_SCALE, mapID
end

function HereBeDragons:GetUnitWorldPosition(unitId)
    local x, y = GetPlayerMapPosition(unitId)
    if not x or not y or (x <= 0 and y <= 0) then return nil, nil, nil end
    local mapID = GetCurrentMapAreaID()
    return x * MAP_SCALE, y * MAP_SCALE, mapID
end

function HereBeDragons:GetPlayerZone()
    return GetCurrentMapAreaID(), 0
end

-- Calculate distance between two points
-- Returns: distance, deltaX, deltaY
function HereBeDragons:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not oX or not oY or not dX or not dY then return nil, nil, nil end
    local deltaX, deltaY = dX - oX, dY - oY
    local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    return distance, deltaX, deltaY
end

-- Calculate world vector (direction and distance)
-- Returns: deltaX, deltaY, distance, angle
function HereBeDragons:GetWorldVector(instanceID, oX, oY, dX, dY)
    local distance, deltaX, deltaY = self:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not distance then return nil, nil, nil, nil end
    
    -- Calculate angle (0 = North, increasing clockwise)
    -- In 3.3.5a coords: X+ is East, Y+ is South
    -- Angle from North (Y-): atan2(deltaX, -deltaY)
    local angle = math.atan2(deltaX, -deltaY)
    if angle < 0 then angle = angle + math.pi * 2 end
    
    return deltaX, deltaY, distance, angle
end

function HereBeDragons:GetWorldCoordinatesFromZone(x, y, zone)
    return x * MAP_SCALE, y * MAP_SCALE, zone
end

function HereBeDragons:GetZoneCoordinatesFromWorld(worldX, worldY, zone, allowOutOfBounds)
    local x, y = worldX / MAP_SCALE, worldY / MAP_SCALE
    if not allowOutOfBounds then
        x = math.max(0, math.min(1, x))
        y = math.max(0, math.min(1, y))
    end
    return x, y
end

function HereBeDragons:GetZoneSize(mapID)
    -- Return consistent scale
    return MAP_SCALE, MAP_SCALE
end

-- Event Handling
local function OnEvent(frame, event, ...)
    local mapID = GetCurrentMapAreaID()
    if mapID ~= currentPlayerUIMapID then
        currentPlayerUIMapID = mapID
        HereBeDragons.callbacks:Fire("PlayerZoneChanged", mapID, 0)
    end
end

HereBeDragons.eventFrame:SetScript("OnEvent", OnEvent)
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED")
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
HereBeDragons.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Utility functions
function HereBeDragons:GetLocalizedMap(uiMapID) return GetZoneText() end
function HereBeDragons:GetAllMapIDs() return {} end
