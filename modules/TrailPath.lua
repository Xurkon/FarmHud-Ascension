local addon, ns = ...;
local L = ns.L;
--LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"FH/TP");

local HBD = LibStub("HereBeDragons-2.0", true)
local HBDPins = LibStub("HereBeDragons-Pins-2.0", true)
if not HBD or not HBDPins then return end

local EnableMouse, SetShown
local media = "Interface\\AddOns\\FarmHud\\media\\";
local minDistanceBetween = 12;
local trailPathActive, trailPathPool, lastX, lastY, lastM, lastFacing, IsOpened = {}, {}, nil, nil, nil, nil, nil;
local trailPathUpdateFrame = CreateFrame("Frame", "FarmHudTrailPathUpdateFrame", FarmHud);
trailPathUpdateFrame:Hide();

local maxYards = 40 / 0.2047; -- 195.4 yards visibility radius to screen edge

local trailPathIcons = {      -- coords_pos = { <left>, <right>, <top>, <bottom>, <sizeW>, <sizeH> }
	arrow01 = { file = media .. "arrows1.tga", coords_pos = { 58, 122, 64, 128, 128, 128 }, desaturated = true },
	arrow02 = { file = media .. "arrows1.tga", coords_pos = { 69, 98, 0, 29, 128, 128 }, desaturated = true },
	arrow03 = { file = media .. "arrows1.tga", coords_pos = { 39, 54, 30, 45, 128, 128 }, desaturated = true },
	arrow04 = { file = media .. "arrows1.tga", coords_pos = { 18, 33, 107, 125, 128, 128 }, desaturated = true },
	arrow05 = { file = media .. "arrows1.tga", coords_pos = { 74, 105, 29, 59, 128, 128 }, desaturated = false },
	arrow06 = { file = media .. "arrows1.tga", coords_pos = { 34, 57, 68, 91, 128, 128 }, desaturated = false },
	dot01 = { file = media .. "playerDot-white.tga", coords = { 0.2, 0.8, 0.2, 0.8 } },
	dot02 = { file = "Interface\\Minimap\\Minimap-Blip-Small", coords = { 0, 1, 0, 1 }, desaturated = false },
	ring1 = { file = "Interface\\Minimap\\Minimap-TrackingBorder", coords = { 0, 1, 0, 1 }, desaturated = true },
	ring2 = { file = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", desaturated = true, mode = "ADD" },
}

local TrailPathIconValues = {
	arrow01 = L["Arrow 1"],
	arrow02 = L["Arrow 2"],
	arrow03 = L["Arrow 3"],
	arrow04 = L["Arrow 4"],
	arrow05 = L["Arrow 5"],
	arrow06 = L["Arrow 6"],
	dot01 = L["Dot 1"],
	dot02 = L["Dot 2"],
	ring1 = L["Ring 1"],
	ring2 = L["Ring 2"],
}

-- Helper to fix 3.3.5a parentKey incompatibility
-- Manually sets up entry.pin, entry.pin.icon, entry.pin.Facing from child frames
local function SetupPinStructure(entry)
	-- Get child frames (the pin frame is the first child)
	local children = { entry:GetChildren() }
	if children[1] then
		entry.pin = children[1]
		-- Get the icon texture from the pin's regions
		local regions = { entry.pin:GetRegions() }
		for _, region in ipairs(regions) do
			if region:IsObjectType("Texture") then
				entry.pin.icon = region
				break
			end
		end
		-- Get the Facing animation group - 3.3.5a stores animations differently
		-- Try GetAnimationGroups if available, otherwise check for named children
		if entry.pin.GetAnimationGroups then
			local animGroups = { entry.pin:GetAnimationGroups() }
			if animGroups[1] then
				entry.pin.Facing = animGroups[1]
				-- Get the Rotate animation from the animation group
				local animations = animGroups[1].GetAnimations and { animGroups[1]:GetAnimations() } or {}
				if animations[1] then
					entry.pin.Facing.Rotate = animations[1]
				end
			end
		end
		-- Ensure the pin and icon are shown
		entry.pin:Show()
		if entry.pin.icon then
			entry.pin.icon:Show()
		end
	end

	-- If no child frame found, create pin structure manually
	if not entry.pin then
		entry.pin = CreateFrame("Frame", nil, entry)
		entry.pin:SetAllPoints(entry)
		entry.pin.icon = entry.pin:CreateTexture(nil, "OVERLAY")
		entry.pin.icon:SetAllPoints(entry.pin)
		entry.pin.icon:SetTexture("Interface\\Minimap\\Minimap-Blip-Small")
		entry.pin:Show()
		entry.pin.icon:Show()
	end

	-- Ensure icon exists
	if not entry.pin.icon then
		entry.pin.icon = entry.pin:CreateTexture(nil, "OVERLAY")
		entry.pin.icon:SetAllPoints(entry.pin)
		entry.pin.icon:SetTexture("Interface\\Minimap\\Minimap-Blip-Small")
		entry.pin.icon:Show()
	end
end

FarmHudTrailPathPinMixin = {}

local function UpdateVisibility(self)
	local HUD = FarmHud:IsShown();
	-- Check if this is a world map pin (has mapPin flag or parent is WorldMapDetailFrame)
	local isWorldMapPin = self.isWorldMapPin or (self:GetParent() == WorldMapDetailFrame)

	if isWorldMapPin then
		-- World map pins: show if world map is visible and trailPathShow is enabled
		if WorldMapFrame and WorldMapFrame:IsVisible() and FarmHudDB.trailPathShow then
			SetShown(self, true)
		else
			SetShown(self, false)
		end
	elseif HUD then
		-- HUD pins: Always show on HUD if active
		SetShown(self, true)
	else
		-- Minimap pins: rely on HBD-Minimap settings
		SetShown(self, FarmHudDB.trailPathOnMinimap)
	end
end

FarmHudTrailPathPinMixin.UpdateTrailVisibility = UpdateVisibility
FarmHudTrailPathPinMixin.EnableMouse = function() end;

function FarmHudTrailPathPinMixin:UpdatePin(facing, onCluster)
	-- onCluster is true if we are rendering for the HUD (Manual mode)
	-- or if we are rendering for Minimap (HBD mode) relative to config?
	-- Actually, this mixin is used for BOTH the HUD pin and the Map pin if they share it.
	-- But we separated MapPin logic. Let's assume this mixin is primarily for the HUD/Minimap pin.

	-- Ensure pin structure exists
	if not self.pin or not self.pin.icon then return end

	-- facing
	local rotateMiniMap = GetCVar("rotateMinimap") == "1";
	if facing and self.pin.Facing and self.pin.Facing.Rotate then
		if rotateMiniMap then
			self.pin.Facing.Rotate:SetRadians(self.info.f - facing);
		elseif not rotateMiniMap then
			self.pin.Facing.Rotate:SetRadians(self.info.f);
		end
	end
	-- texture
	-- For world map pins (isWorldMapPin), use dot unless rotation is enabled
	-- For HUD pins (onCluster), use arrow if rotation is enabled
	local pinIcon = "dot02"
	if self.isWorldMapPin then
		-- World map: use arrow only if rotation is enabled
		pinIcon = (FarmHudDB.rotation and FarmHudDB.trailPathIcon) or "dot02"
	elseif onCluster then
		-- HUD: use arrow if rotation is enabled
		pinIcon = (FarmHudDB.rotation and FarmHudDB.trailPathIcon) or "dot02"
	end
	-- Always set texture (not just when changed) to ensure it's applied
	local icon = trailPathIcons[pinIcon];
	if icon then
		-- Ensure coords are calculated if using coords_pos
		-- coords_pos format: {left, right, top, bottom, sizeW, sizeH}
		-- We need to convert pixel coordinates to normalized 0-1 texture coordinates
		if icon.coords_pos and (not icon.coords or #icon.coords < 4) then
			local sizeW = icon.coords_pos[5] or 128
			local sizeH = icon.coords_pos[6] or 128
			icon.coords = {
				icon.coords_pos[1] / sizeW, -- left (normalized)
				icon.coords_pos[2] / sizeW, -- right (normalized)
				icon.coords_pos[3] / sizeH, -- top (normalized)
				icon.coords_pos[4] / sizeH -- bottom (normalized)
			}
		end
		if not icon.coords or #icon.coords < 4 then
			icon.coords = { 0, 1, 0, 1 };
		end

		-- Always set texture to ensure it's loaded (fixes black squares)
		self.pin.icon:SetTexture(icon.file)
		self.pin.icon:SetTexCoord(unpack(icon.coords));
		self.pin.icon:SetDesaturated(icon.desaturated == true)
		self.pin.icon:SetBlendMode(icon.mode or "BLEND");
		self.info.currentPinIcon = pinIcon

		-- Ensure texture is visible
		self.pin.icon:Show()
	end
	-- scaling
	local scale = onCluster and FarmHudDB.trailPathScale or 0.7;
	if self.info.currentPinScale ~= scale then
		self.pin:SetScale(scale);
		self.info.currentPinScale = scale;
	end
	-- color
	if FarmHudDB.trailPathColor1 then
		self.pin.icon:SetVertexColor(unpack(FarmHudDB.trailPathColor1))
		self.info.currentPinColor1 = FarmHudDB.trailPathColor1;
	end

	-- Force EnableMouse off
	EnableMouse(self, false);

	-- visibility
	UpdateVisibility(self);
end

-- Manual Position Update for HUD Mode
-- Uses zone-based yard calculation matching HereBeDragons-Pins approach
local MAP_SCALE = 1000 -- Must match HereBeDragons-2.0

-- Zone name to size in yards mapping (matching HereBeDragons-Pins)
local zoneNameToYards = {
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
	["Tirisfal Glades"] = 4000,
	["Dun Morogh"] = 4000,
	["Elwynn Forest"] = 3500,
	["Westfall"] = 4000,
}
local DEFAULT_ZONE_YARDS = 2000

local function GetHudZoneSizeYards()
	local zoneName = GetZoneText() or ""
	return zoneNameToYards[zoneName] or DEFAULT_ZONE_YARDS
end

function FarmHudTrailPathPinMixin:UpdateManual(px, py, pInst, pFacing)
	if not self.info or not self.info.map or self.info.map ~= pInst then
		if self.info and self.info.map ~= pInst then
			self:Hide()
		end
		return
	end

	if not self.info.x or not self.info.y then
		self:Hide()
		return
	end

	-- Get zone size for proper yard calculation
	local zoneYards = GetHudZoneSizeYards()

	-- Calculate delta in normalized coords, then convert to yards
	local deltaNormX = (self.info.x - px) / MAP_SCALE
	local deltaNormY = (self.info.y - py) / MAP_SCALE

	local deltaYardsX = deltaNormX * zoneYards
	local deltaYardsY = deltaNormY * zoneYards

	-- 3.3.5a: X+ = East, Y+ = South
	-- Screen: X+ = Right, Y+ = Up (flip Y)
	local screenYardsX = deltaYardsX
	local screenYardsY = -deltaYardsY

	-- Convert yards to HUD pixels using maxYards (HUD visibility range)
	local hudRadius = FarmHud:GetHeight() / 2
	local yardsToPixels = hudRadius / maxYards

	local pixelX = screenYardsX * yardsToPixels
	local pixelY = screenYardsY * yardsToPixels

	local sx, sy

	if FarmHudDB.rotation then
		local theta = -pFacing
		local cos, sin = math.cos(theta), math.sin(theta)
		sx = pixelX * cos - pixelY * sin
		sy = pixelX * sin + pixelY * cos
	else
		sx = pixelX
		sy = pixelY
	end

	-- Hide if outside HUD bounds
	local dist = math.sqrt(sx * sx + sy * sy)
	if dist > hudRadius * 0.95 then
		self:Hide()
		return
	end

	self:Show()
	self:ClearAllPoints()
	self:SetPoint("CENTER", FarmHud, "CENTER", sx, sy)

	self:UpdatePin(pFacing, true)
end

local function GetMicrotime()
	return ceil(GetTime() * 100);
end

trailPathUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
	if not FarmHud:IsShown() then
		-- Ensure frame stays visible for next check, but don't update
		return
	end

	local x, y, instance = HBD:GetPlayerWorldPosition()
	local facing = GetPlayerFacing() or 0

	if not (x and y and instance) then return end

	-- Iterate active trails and update positions manually
	for _, pin in ipairs(trailPathActive) do
		if pin and pin.info and pin.info.map == instance then
			pin:UpdateManual(x, y, instance, facing)
		end
	end
end)

local function TrailPath_TickerFunc()
	-- get position from HereBeDragon
	local x, y, instance = HBD:GetPlayerWorldPosition();

	-- skip function on invalid result; in dungeons/raids
	if not (x and y and instance) then
		return
	end

	local registerNew = true;
	local currentTime = GetMicrotime();
	local currentFacing = GetPlayerFacing() or 0; -- 0 - 6.5
	-- Make HUD icon settings apply to trailPathOnMinimap
	local HUD = FarmHud:IsShown();
	local IsOnCluster = HUD or (not HUD and FarmHudDB.trailPathOnMinimap);

	-- check distance between current and prev. position; skip function
	if trailPathActive[1] and trailPathActive[1].info and trailPathActive[1].info.x then
		local deltaX, deltaY, distance, angle = HBD:GetWorldVector(instance, trailPathActive[1].info.x,
			trailPathActive[1].info.y, x, y);
		if distance and distance <= minDistanceBetween then
			trailPathActive[1].info.f = currentFacing;
			-- If HUD is shown, OnUpdate handles position. If not, HBD handles it.
			if not HUD then
				trailPathActive[1]:UpdatePin(nil, IsOnCluster);
			end
			registerNew = false;
		end
	end

	if registerNew then
		-- reuse pin frame from pool or create new
		local entry = trailPathPool[1];
		if entry then
			tremove(trailPathPool, 1);
		else
			entry = CreateFrame("Frame", nil, nil, "FarmHudTrailPathPinTemplate");
			SetupPinStructure(entry); -- Fix 3.3.5a parentKey incompatibility
			ns.Mixin(entry, FarmHudTrailPathPinMixin);
			entry.info = {};
			-- Safely play animation if it exists
			if entry.pin and entry.pin.Facing and entry.pin.Facing.Play then
				entry.pin.Facing:Play();
			end
			entry:EnableMouse(false);

			-- Create MapPin for World Map
			entry.mapPin = CreateFrame("Frame", nil, nil, "FarmHudTrailPathPinTemplate")
			SetupPinStructure(entry.mapPin); -- Fix 3.3.5a parentKey incompatibility
			ns.Mixin(entry.mapPin, FarmHudTrailPathPinMixin)
			entry.mapPin.info = {}
			entry.mapPin:EnableMouse(false)
			entry.mapPin.isWorldMapPin = true -- Mark as world map pin for visibility logic
			-- Safely play animation if it exists
			if entry.mapPin.pin and entry.mapPin.pin.Facing and entry.mapPin.pin.Facing.Play then
				entry.mapPin.pin.Facing:Play()
			end
			-- Ensure mapPin is visible
			entry.mapPin:Show()
			if entry.mapPin.pin then
				entry.mapPin.pin:Show()
				if entry.mapPin.pin.icon then
					entry.mapPin.pin.icon:Show()
				end
			end
		end

		-- update info table entries
		entry.info.map = instance;
		entry.info.x = x;
		entry.info.y = y;
		entry.info.f = currentFacing;
		entry.info.t = currentTime;

		-- Sync MapPin info
		wipe(entry.mapPin.info)
		for k, v in pairs(entry.info) do entry.mapPin.info[k] = v end

		entry:UpdatePin(nil, IsOnCluster);
		-- Initialize MapPin texture/rotation before adding to world map
		-- Force texture reload by clearing current icon to ensure it's set correctly
		entry.mapPin.info.currentPinIcon = nil
		-- For world map, use dot icon (not arrow) unless rotation is enabled
		local worldMapIcon = FarmHudDB.rotation and FarmHudDB.trailPathIcon or "dot02"
		local icon = trailPathIcons[worldMapIcon]
		if icon and entry.mapPin.pin and entry.mapPin.pin.icon then
			-- Calculate coords if needed
			if icon.coords_pos and (not icon.coords or #icon.coords < 4) then
				local sizeW = icon.coords_pos[5] or 128
				local sizeH = icon.coords_pos[6] or 128
				icon.coords = {
					icon.coords_pos[1] / sizeW,
					icon.coords_pos[2] / sizeW,
					icon.coords_pos[3] / sizeH,
					icon.coords_pos[4] / sizeH
				}
			end
			if not icon.coords or #icon.coords < 4 then
				icon.coords = { 0, 1, 0, 1 }
			end
			-- Set texture immediately
			entry.mapPin.pin.icon:SetTexture(icon.file)
			entry.mapPin.pin.icon:SetTexCoord(unpack(icon.coords))
			entry.mapPin.pin.icon:SetDesaturated(icon.desaturated == true)
			entry.mapPin.pin.icon:SetBlendMode(icon.mode or "BLEND")
			entry.mapPin.pin.icon:Show()
		end
		entry.mapPin:UpdatePin(currentFacing, false); -- false = Not on Cluster (World Map Mode)

		-- Ensure mapPin is visible and properly configured
		entry.mapPin:Show()
		if entry.mapPin.pin then
			entry.mapPin.pin:Show()
			if entry.mapPin.pin.icon then
				entry.mapPin.pin.icon:Show()
			end
		end

		-- register pin frame at HereBeDragon
		-- GLOBAL MAP: Always register MapPin
		if FarmHudDB.trailPathShow then
			HBDPins:AddWorldMapIconWorld(FarmHud, entry.mapPin, instance, x, y);
			-- Force update visibility after adding
			UpdateVisibility(entry.mapPin)
		end

		-- MINIMAP / HUD:
		if HUD then
			-- Manual Mode: Do NOT register with HBDPins Minimap.
			-- Add to manual list is implicit (trailPathActive).
			-- Ensure it's parented to FarmHud for drawing
			entry:SetParent(FarmHud)
			-- Position will be set by OnUpdate next frame
		else
			-- Standard Mode: Register with HBDPins Minimap
			entry:SetParent(Minimap)
			HBDPins:AddMinimapIconWorld(FarmHud, entry, instance, x, y);
		end

		tinsert(trailPathActive, 1, entry);
	end

	-- check pin frame too old; remove or update
	if #trailPathActive > 0 then
		for i = #trailPathActive, 1, -1 do
			local v = trailPathActive[i];
			if i > 1 and (i > FarmHudDB.trailPathCount or (v.info.t and currentTime - v.info.t > (FarmHudDB.trailPathTimeout * 100))) then
				HBDPins:RemoveMinimapIcon(FarmHud, v);
				if v.mapPin then
					HBDPins:RemoveWorldMapIcon(FarmHud, v.mapPin);
				end
				wipe(v.info);
				tinsert(trailPathPool, v);
				tremove(trailPathActive, i);
			else
				if not HUD then
					trailPathActive[i]:UpdatePin(currentFacing, IsOnCluster);
				end
				-- MapPin update - ensure texture is always set correctly
				if v.mapPin and FarmHudDB.trailPathShow then
					-- Force texture reload to fix squares issue
					v.mapPin.info.currentPinIcon = nil
					-- For world map, use dot icon (not arrow) unless rotation is enabled
					local worldMapIcon = FarmHudDB.rotation and FarmHudDB.trailPathIcon or "dot02"
					local icon = trailPathIcons[worldMapIcon]
					if icon and v.mapPin.pin and v.mapPin.pin.icon then
						-- Calculate coords if needed
						if icon.coords_pos and (not icon.coords or #icon.coords < 4) then
							local sizeW = icon.coords_pos[5] or 128
							local sizeH = icon.coords_pos[6] or 128
							icon.coords = {
								icon.coords_pos[1] / sizeW,
								icon.coords_pos[2] / sizeW,
								icon.coords_pos[3] / sizeH,
								icon.coords_pos[4] / sizeH
							}
						end
						if not icon.coords or #icon.coords < 4 then
							icon.coords = { 0, 1, 0, 1 }
						end
						-- Set texture immediately before UpdatePin
						v.mapPin.pin.icon:SetTexture(icon.file)
						v.mapPin.pin.icon:SetTexCoord(unpack(icon.coords))
						v.mapPin.pin.icon:SetDesaturated(icon.desaturated == true)
						v.mapPin.pin.icon:SetBlendMode(icon.mode or "BLEND")
						v.mapPin.pin.icon:Show()
					end
					v.mapPin:UpdatePin(currentFacing, false) -- False = Not on Cluster (Map Mode)
					-- Force visibility update for world map pins
					if WorldMapFrame and WorldMapFrame:IsVisible() then
						UpdateVisibility(v.mapPin)
						-- Ensure texture is visible
						if v.mapPin.pin and v.mapPin.pin.icon then
							v.mapPin.pin:Show()
							v.mapPin.pin.icon:Show()
						end
					end
				end
			end
		end
	end
end

-- Timer replacement: use OnUpdate frame instead of C_Timer.NewTicker
local trailPathTickerFrame = CreateFrame("Frame")
trailPathTickerFrame:Hide()
trailPathTickerFrame.elapsed = 0
trailPathTickerFrame:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if self.elapsed >= 0.5 then
		self.elapsed = 0
		TrailPath_TickerFunc()
	end
end)

local function UpdateTrailPath(force)
	if force == nil then
		force = FarmHudDB.trailPathShow;
	end
	if force == true and not trailPathTickerFrame:IsShown() then
		trailPathTickerFrame:Show();
	elseif force == false and trailPathTickerFrame:IsShown() then
		trailPathTickerFrame:Hide();
		HBDPins:RemoveAllMinimapIcons(FarmHud)
		HBDPins:RemoveAllWorldMapIcons(FarmHud)
		if FarmHud.TrailPathPool then
			for i, v in ipairs(FarmHud.TrailPathPool) do
				v:Hide();
			end
		end
	end
end

local module = {};
module.events = {};
module.dbDefaults = {
	trailPathShow = true,
	trailPathOnMinimap = true,
	trailPathCount = 32,
	trailPathTimeout = 60,
	trailPathIcon = "arrow01",
	trailPathColor1 = { 1, .2, .2, 1, .75 },
	trailPathScale = 1,
};

function module.AddOptions()
	return {
		trial = {
			type = "group", --order = 9,
			name = L["TrailPath"],
			childGroups = "tab",
			args = {
				onWorldmap = {
					type = "group",
					inline = true,
					name = L["TrailPathOnWorldmap"],
					args = {
						trailPathShow = {
							type = "toggle",
							order = 1,
							name = L["TrailPathShow"], -- desc = L["TrailPathShowDesc"],
						},
						trailPathIcon = {
							type = "select",
							order = 5,
							name = L["TrailPathIcon"],
							desc = L["TrailPathIconDesc"],
							values = TrailPathIconValues
						},
						trailPathScale = {
							type = "range",
							order = 6,
							name = L["TrailPathScale"],
							desc = L["TrailPathScaleDesc"],
							min = 0.1,
							step = 0.1,
							max = 1,
							isPercent = true
						},
					}
				},
				onMinimap = {
					type = "group",
					inline = true,
					name = L["TrailPathOnMinimap"],
					desc = L["TrailPathOnMinimapDesc"],
					args = {
						trailPathOnMinimap = {
							type = "toggle",
							order = 2,
							name = SHOW,
						},
						trailPathMinimapIcon = {
							type = "select",
							order = 5,
							name = L["TrailPathMinimapIcon"],
							desc = L["TrailPathMinimapIconDesc"],
							values = TrailPathIconValues
						},
						trailPathMinimapScale = {
							type = "range",
							order = 6,
							name = L["TrailPathMinimapScale"],
							desc = L["TrailPathMinimapScaleDesc"],
							min = 0.1,
							step = 0.1,
							max = 1,
							isPercent = true
						},
					}
				},
				trailPathCount = {
					type = "range",
					order = 3,
					name = L["TrailPathCount"],
					desc = L["TrailPathCountDesc"],
					min = 10,
					step = 1,
					max = 64,
				},
				trailPathTimeout = {
					type = "range",
					order = 4,
					name = L["TrailPathTimeout"],
					desc = L["TrailPathTimeoutDesc"],
					min = 10,
					step = 10,
					max = 600,
				},
				trailPathColor1 = {
					type = "color",
					order = 7,
					name = COLOR,
					desc = L["TrailPathColorsDesc"],
					hasAlpha = true,
					hidden = false -- function to check color mode
				},
			}
		}
	};
end

function module.UpdateOptions(key, value)
	if key == "trailPathShow" then
		UpdateTrailPath(value);
	elseif key == "trailPathOnMinimap" then
		-- Re-trigger OnShow/OnHide logic based on current HUD state
		if FarmHud:IsShown() then
			module.OnShow()
		else
			module.OnHide()
		end
	elseif key == "trailPathIcon" or key == "trailPathColor1" or key == "trailPathScale" then
		-- Force update all pins when icon, color, or scale changes
		local scale = FarmHudDB.trailPathScale or 1
		for _, pin in ipairs(trailPathActive) do
			if pin then
				local HUD = FarmHud:IsShown();
				local IsOnCluster = HUD or (not HUD and FarmHudDB.trailPathOnMinimap);
				-- Update scale
				local baseSize = 20
				pin:SetWidth(baseSize * scale)
				pin:SetHeight(baseSize * scale)
				if pin.pin then
					pin.pin:SetWidth(baseSize * scale)
					pin.pin:SetHeight(baseSize * scale)
				end
				-- Force texture update
				if pin.info then pin.info.currentPinIcon = nil end
				pin:UpdatePin(GetPlayerFacing() or 0, IsOnCluster);
			end
			if pin and pin.mapPin then
				-- Update scale for map pin
				local baseSize = 20
				pin.mapPin:SetWidth(baseSize * scale)
				pin.mapPin:SetHeight(baseSize * scale)
				if pin.mapPin.pin then
					pin.mapPin.pin:SetWidth(baseSize * scale)
					pin.mapPin.pin:SetHeight(baseSize * scale)
				end
				if pin.mapPin.info then pin.mapPin.info.currentPinIcon = nil end
				pin.mapPin:UpdatePin(GetPlayerFacing() or 0, false);
			end
		end
	-- trailPathCount and trailPathTimeout are read dynamically, no immediate action needed
	end
end

function module.events.PLAYER_ENTERING_WORLD()
	if IsInInstance() then
		UpdateTrailPath(false)
	else
		UpdateTrailPath()
	end
end

-- Handle Transitions between Manual (HUD) and Library (Minimap)
function module.OnShow()
	-- Switch to Manual Mode
	trailPathUpdateFrame:Show()

	-- Remove pins from HBD Minimap ONLY
	for _, pin in ipairs(trailPathActive) do
		HBDPins:RemoveMinimapIcon(FarmHud, pin)
		pin:SetParent(FarmHud) -- Ensure it's on the HUD frame
		pin:Show()
	end
end

function module.OnHide()
	-- Switch to Library Mode
	trailPathUpdateFrame:Hide()

	-- Restore pins to HBD Minimap (if enabled)
	if FarmHudDB.trailPathOnMinimap then
		for _, pin in ipairs(trailPathActive) do
			if pin and pin.info and pin.info.map and pin.info.x and pin.info.y then
				-- Set proper parent for minimap display
				pin:SetParent(Minimap)
				-- Re-register with HBD
				HBDPins:AddMinimapIconWorld(FarmHud, pin, pin.info.map, pin.info.x, pin.info.y)
				pin:Show()
			end
		end
	else
		-- If not on minimap, just hide them
		for _, pin in ipairs(trailPathActive) do
			if pin then
				pin:Hide()
			end
		end
	end
end

function module.events.PLAYER_LOGIN()
	local mt = getmetatable(FarmHud).__index;
	EnableMouse, SetShown = mt.EnableMouse, ns.SetShown;

	-- prepare trailPathIcons texture coords from coords_pos entries
	FarmHud.UpdateTrailPath = UpdateTrailPath;

	for key, value in pairs(trailPathIcons) do
		if value.coords_pos then
			if not value.coords then
				value.coords = { 0, 1, 0, 1 };
			end
			-- Calculate texture coordinates from coords_pos
			-- coords_pos format: {left, right, top, bottom, sizeW, sizeH}
			for i, pos in ipairs(value.coords_pos) do
				if i > 4 then break; end
				local sizeIndex = i <= 2 and 5 or 6
				if value.coords_pos[sizeIndex] and value.coords_pos[sizeIndex] > 0 then
					value.coords[i] = pos / value.coords_pos[sizeIndex];
				else
					value.coords[i] = pos > 1 and (pos / 128) or pos
				end
			end
			-- Ensure all 4 coords are set
			if not value.coords[1] then value.coords[1] = 0 end
			if not value.coords[2] then value.coords[2] = 1 end
			if not value.coords[3] then value.coords[3] = 0 end
			if not value.coords[4] then value.coords[4] = 1 end
		elseif not value.coords then
			value.coords = { 0, 1, 0, 1 };
		end
	end
	UpdateTrailPath();

	-- Hook OnShow/OnHide logic via Module Event Dispatcher if supported,
	-- Or just hook FarmHud script?
	-- Currently FarmHud uses `ns.modules` dispatching for events, but OnShow/OnHide are mapped strings?
	-- FarmHud.lua uses:
	-- OnShow = {frame="FarmHud",func="OnShow"}, -- No, that's not how it works.
	-- FarmHud.lua calls module.OnShow if defined!
	-- Yes!
end

ns.modules["TrailPath"] = module;
