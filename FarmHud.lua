local addon, ns = ...;
local L = ns.L;
ns.debugMode = false; -- Disable debug mode
-- LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"FH"); -- Might not be needed or fails if lib missing. Comment out for safety unless I see it being essential. It decorates 'print'.
-- Let's define ns:print manually if missing
if not ns.print then ns.print = function(...) print("FarmHud:", ...) end end
if not ns.debug then ns.debug = function(...) end end -- Silent debug call
ns.SetShown = function(f, s) if s then f:Show() else f:Hide() end end
ns.Mixin = function(object, mixin)
	for k, v in pairs(mixin) do object[k] = v end
	return object
end

local ACD = LibStub("AceConfigDialog-3.0");
-- local HBDPins = LibStub("HereBeDragons-Pins-2.0") -- HBD might break in 3.3.5a if not compatible. Comment out to be safe.

FarmHudMixin = {};

-- Polyfills for 3.3.5a (Global)
C_Minimap = C_Minimap or {}
function C_Minimap.GetNumTrackingTypes()
	return GetNumTrackingTypes()
end

function C_Minimap.GetTrackingInfo(index)
	local name, texture, active, category = GetTrackingInfo(index)
	return { name = name, texture = texture, active = active, subType = category }
end

function C_Minimap.SetTracking(index, state)
	if state ~= false then -- In 3.3.5a we typically enable by index. Disabling is switching to another or 'None' (which is index 0 or similar but rare)
		SetTracking(index)
	end
end

-- C_Timer polyfill - only create if it doesn't exist
if not C_Timer then
	C_Timer = {}
end
if not C_Timer.After then
	function C_Timer.After(duration, func)
		local f = CreateFrame("Frame")
		f.time = 0
		f:SetScript("OnUpdate", function(self, elapsed)
			self.time = self.time + elapsed
			if self.time >= duration then
				self:SetScript("OnUpdate", nil)
				func()
			end
		end)
	end
end
if not C_Timer.NewTicker then
	function C_Timer.NewTicker(duration, callback)
		local tick = { cancelled = false }
		local f = CreateFrame("Frame")
		f.elapsed = 0
		f:SetScript("OnUpdate", function(self, elapsed)
			if tick.cancelled then
				self:SetScript("OnUpdate", nil)
				return
			end
			self.elapsed = self.elapsed + elapsed
			if self.elapsed >= duration then
				self.elapsed = 0
				callback()
			end
		end)
		function tick:Cancel() self.cancelled = true end

		return tick
	end
end

C_Map = C_Map or {}
function C_Map.GetBestMapForUnit(unit)
	return GetCurrentMapAreaID()
end

function C_Map.GetPlayerMapPosition(mapID, unit)
	local x, y = GetPlayerMapPosition(unit)
	return { GetXY = function() return x, y end }
end

function C_Map.GetMapInfo(mapID) return nil end

C_AddOns = C_AddOns or {}
function C_AddOns.IsAddOnLoaded(name) return IsAddOnLoaded(name) end

C_CVar = C_CVar or {}
C_CVar.SetCVar = C_CVar.SetCVar or function(name, value) SetCVar(name, value) end
C_CVar.GetCVar = C_CVar.GetCVar or function(name) return GetCVar(name) end
C_CVar.GetCVarBool = C_CVar.GetCVarBool or function(name) return GetCVar(name) == "1" end

local _G, type, wipe, tinsert, unpack, tostring = _G, type, wipe, table.insert, unpack, tostring;
local Minimap_OnClick = Minimap_OnClick;
local Minimap_UpdateRotationSetting = Minimap_UpdateRotationSetting or function() end

ns.QuestArrowToken = {};
local LibHijackMinimap_Token, LibHijackMinimap, _ = {}, nil, nil;
local media = "Interface\\AddOns\\" .. addon .. "\\media\\";
local mps, Minimap, MinimapMT, mouseOnKeybind = {}, _G.Minimap, getmetatable(_G.Minimap).__index, nil;
local playerDot_orig, playerDot_custom = "Interface\\Minimap\\MinimapArrow", nil;
-- Removed WOW_PROJECT_ID check for 3.3.5a
local timeTicker, cardinalTicker, coordsTicker, background_alpha_current;
local knownProblematicAddOns, knownProblematicAddOnsDetected = { BasicMinimap = true }, {};
local SetPointToken, SetParentToken = {}, {};
local trackingTypes, trackingTypesStates, numTrackingTypes, trackingHookLocked = {}, {}, 0, false;
local MinimapFunctionHijacked --= {"SetParent","ClearAllPoints","SetAllPoints","GetPoint","GetNumPoints"};
local rotationMode, mTI
local foreignObjects = {}
local anchoredFrames = { -- frames there aren't childs of minimap but anchored it.
	-- <name[string]> - Could be a path from _G delimited by dots.
	-- Blizzard
	"GameTimeFrame",                  -- required if foreign addon changed
	"GarrisonLandingPageMinimapButton",
	"MinimapCluster.InstanceDifficulty", -- required if foreign addon changed (ElvUI)
	"MinimapBackdrop",                -- required if foreign addon changed
	"MinimapCompassTexture",
	"MinimapNorthTag",
	"MiniMapTracking",
	"MiniMapWorldMapButton",
	"MinimapZoneText",
	"MinimapZoomIn",
	"MinimapZoomOut",
	"TimeManagerClockButton", -- required if foreign addon changed
	"TimerTracker",
	-- MinimapButtonFrame
	--"MBB_MinimapButtonFrame",
	-- SexyMap
	--"SexyMapCustomBackdrop",
	"QueueStatusMinimapButton",
	-- chinchilla minimap
	"Chinchilla_Coordinates_Frame",
	"Chinchilla_Location_Frame",
	"Chinchilla_Compass_Frame",
	"Chinchilla_Appearance_MinimapCorner1",
	"Chinchilla_Appearance_MinimapCorner2",
	"Chinchilla_Appearance_MinimapCorner3",
	"Chinchilla_Appearance_MinimapCorner4",
	-- obeliskminimap
	"ObeliskMinimapZoneText",
	"ObeliskMinimapInformationFrame",
	-- Lorti-UI / Lorti-UI-Classic
	"rBFS_BuffDragFrame",
	"rBFS_DebuffDragFrame",
	-- BtWQuests
	"BtWQuestsMinimapButton",
	-- GW2_UI
	"GwQuestTracker",
	"Minimap.gwTrackingButton", -- added with parent key, without SetParent, but with SetAllPoints to the Minimap. Has prevented mouse interaction with 3d world.
	"GwAddonToggle",
	"GwCalendarButton",
	"GwGarrisonButton",
	"GwMailButton",
};
local ignoreFrames = {
	FarmHudRangeCircles = true
}
local modifiers = {
	A  = { LALT = 1, RALT = 1 },
	AL = { LALT = 1 },
	AR = { RALT = 1 },
	C  = { LCTRL = 1, RCTRL = 1 },
	CL = { LCTRL = 1 },
	CR = { RCTRL = 1 },
	S  = { LSHIFT = 1, RSHIFT = 1 },
	SL = { LSHIFT = 1 },
	SR = { RSHIFT = 1 },
};
local minimapScripts = {
	-- <ScriptFunctionName> = <action[CurrenctlyNotImplemented]>
	OnMouseDown = "Dummy",
	OnDragStart = "nil",
	OnDragStop = "nil"
}
local minimapCreateTextureTable = {};
local trackEnableMouse, suppressNextMouseEnable = false, false; -- try to get more info for mouse enable bug
local excludeInstance = {                                       -- exclude instance from hideInInstace option

}

local function moduleEventFunc(self, event, ...)
	if self.module.events[event] then
		self.module.events[event](self.module.eventFrame, ...)
	end
end

ns.modules = setmetatable({}, {
	__newindex = function(t, name, module)
		rawset(t, name, module)
		if module.events then
			local c = 0;
			for event, func in pairs(module.events) do
				c = c + 1;
				if type(func) == "function" then
					if not module.eventFrame then
						module.eventFrame = CreateFrame("Frame");
						module.eventFrame.module = module;
						module.eventFrame.moduleName = name;
						module.eventFrame:SetScript("OnEvent", moduleEventFunc)
					end
					module.eventFrame:RegisterEvent(event);
				end
			end
		end
	end,
	__call = function(t, arg1, ...)
		for modName, mod in pairs(t) do
			local modObj = mod[arg1];
			if modObj then
				local objType = type(modObj);
				if objType == "function" then
					modObj(...);
				elseif objType == "string" and type(mod[modObj]) == "function" then
					mod[modObj](...);
				elseif objType == "table" then
					local frame = type(modObj.frame) == "string" and (_G[modObj.frame] or FarmHud[modObj.frame]) or false;
					if frame and frame.GetObjectType and frame:GetObjectType() == "Frame" and frame[modObj.func] then
						frame[modObj.func](frame, ...)
					end
				end
			elseif arg1 == "Event" and mod[arg1] then
				mod[arg1](FarmHud, arg1, ...);
			end
		end
	end
})

do
	function ns.IsClassic()
		return false; -- Treat as WotLK/Retail hybrid for tracking purposes (enable tracking)
	end

	function ns.IsClassicBC()
		return false;
	end

	function ns.IsRetail()
		return false;
	end

	function ns.IsDragonFlight()
		return false;
	end
end

local function SetPlayerDotTexture(bool)
	local tex = media .. "playerDot-" .. FarmHudDB.player_dot
	if FarmHudDB.player_dot == "blizz" or not bool then
		tex = playerDot_custom or playerDot_orig;
	end

	-- Prevent recursion just in case, though we are hiding native
	if _G.FarmHud_InSetPlayerTexture then return end
	_G.FarmHud_InSetPlayerTexture = true

	-- Update fake arrow if it exists (FarmHud visible)
	if FarmHud:IsVisible() and FarmHud.PlayerArrow then
		FarmHud.PlayerArrow:SetTexture(tex)
		-- Hide native arrow while FarmHud is visible (set to empty)
		Minimap:SetPlayerTexture("")
	else
		-- Fallback or when FarmHud hidden (restore native)
		Minimap:SetPlayerTexture(tex);
	end
	_G.FarmHud_InSetPlayerTexture = false
end

-- continent id of map id

function ns.GetContinentID(mapID)
	if not mapID then
		mapID = C_Map.GetBestMapForUnit("player");
		if not mapID then
			return false;
		end
	end
	local mapInfo = C_Map.GetMapInfo(mapID);
	if mapInfo and mapInfo.parentMapID and mapInfo.mapType > 2 then
		return ns.GetContinentID(mapInfo.parentMapID);
	end
	return mapID
end

-- transparency options

function FarmHudMixin:UpdateMapAlpha(by, force)
	local alpha = {
		main = FarmHudDB.background_alpha,
		alt = FarmHudDB.background_alpha2
	}
	if by == "OptChange" or by == "OnShow" or by == "ToggleBackground" then
		if by == "OnShow" and FarmHudDB.background_alpha_default then
			FarmHudDB.background_alpha_toggle = true
		elseif by == "ToggleBackground" then
			FarmHudDB.background_alpha_toggle = not FarmHudDB.background_alpha_toggle;
		end
		background_alpha_current = FarmHudDB.background_alpha_toggle and "main" or "alt";
	end
	MinimapMT.SetAlpha(Minimap, force and force or alpha[background_alpha_current]);
end

-- tracking options

function ns.GetTrackingTypes()
	-- if ns.IsClassic() then return {}; end -- Enabled for 3.3.5a
	local num = C_Minimap.GetNumTrackingTypes();
	if numTrackingTypes ~= num then
		numTrackingTypes = num;
		wipe(trackingTypes);
		for i = 1, num do
			local info = C_Minimap.GetTrackingInfo(i) or {}
			if info.texture then
				trackingTypes[info.texture] = { index = i, name = info.name, active = info.active, level = info.subType }
			end
		end
	end
	return trackingTypes;
end

local function TrackingTypes_Update(bool, id)
	-- if ns.IsClassic() then return end -- Enabled for 3.3.5a
	if not id then
		ns.GetTrackingTypes();
		for tId in pairs(trackingTypes) do
			if FarmHudDB["tracking^" .. tId] == "true" or FarmHudDB["tracking^" .. tId] == "false" then
				TrackingTypes_Update(bool, tId);
			end
		end

		if bool == false and mps.minimapTrackedInfov3 then
			-- try to restore on close. blizzard changing it outside the lua code area.
			mTI = mps.minimapTrackedInfov3 > 0 and mps.minimapTrackedInfov3 or 1006319;
			C_Timer.After(0.314159, function() C_CVar.SetCVar("minimapTrackedInfov3", mTI) end);
		end

		return;
	end
	local key, data = "tracking^" .. id, trackingTypes[id];
	local info = C_Minimap.GetTrackingInfo(data.index) or {};
	trackingHookLocked = true;
	if bool then
		if FarmHudDB[key] == "client" then
			if trackingTypesStates[data.index] ~= nil then
				C_Minimap.SetTracking(data.index, trackingTypesStates[data.index]);
				trackingTypesStates[data.index] = nil;
			end
		elseif FarmHudDB[key] ~= tostring(info.active) then
			if trackingTypesStates[data.index] == nil then
				trackingTypesStates[data.index] = info.active;
			end
			C_Minimap.SetTracking(data.index, (FarmHudDB[key] == true or FarmHudDB[key] == "true"));
		end
	elseif not bool and trackingTypesStates[data.index] ~= nil then
		C_Minimap.SetTracking(data.index, trackingTypesStates[data.index]);
		trackingTypesStates[data.index] = nil;
	end
	trackingHookLocked = false;
end


-- repalce CreateTexture function from Minimap to get access on nameless texture created by foreign addons; i hate such activity but forced to do...
do
	function Minimap:CreateTexture(...)
		local tex = MinimapMT.CreateTexture(self, ...);
		tinsert(minimapCreateTextureTable, tex);
		return tex;
	end
end

-- dummyOnly; prevent changes by foreign addons while farmhud is visible
local function dummyOnly_SetPoint(self, point, relTo, relPoint, x, y)
	if relTo == Minimap or relTo == "Minimap" then
		relTo = FarmHudMinimapDummy
	end
	return self[SetPointToken](self, point, relTo, relPoint, x, y);
end

local function dummyOnly_SetParent(self, parent)
	if parent == Minimap or parent == "Minimap" then
		parent = FarmHudMinimapDummy;
	end
	return self[SetParentToken](self, parent);
end

-- function replacements for Minimap while FarmHud is enabled.
-- Should prevent problems with repositioning of minimap buttons from other addons.
local replacements, addHooks
do
	local alreadyHooked, useDummy, lockedBy = {}, nil, nil;
	local function MinimapOrDummy(func, ...)
		if useDummy then
			return FarmHudMinimapDummy[func](FarmHudMinimapDummy, ...);
		end
		return MinimapMT[func](Minimap, ...);
	end
	replacements = {
		GetWidth = function() return MinimapOrDummy("GetWidth") end,
		GetHeight = function() return MinimapOrDummy("GetHeight") end,
		GetSize = function() return MinimapOrDummy("GetSize") end,
		GetCenter = function() return FarmHudMinimapDummy:GetCenter() end,
		GetEffectiveScale = function() return FarmHudMinimapDummy:GetEffectiveScale() end,
		GetLeft = function() return FarmHudMinimapDummy:GetLeft() end,
		GetRight = function() return FarmHudMinimapDummy:GetRight() end,
		GetBottom = function() return FarmHudMinimapDummy:GetBottom() end,
		GetTop = function() return FarmHudMinimapDummy:GetTop() end,
		SetZoom = function(m, z) end, -- prevent zoom
	}

	local objHookedFunctions = {
		OnEnter = function(self, ...)
			if lockedBy ~= false then
				return alreadyHooked[self].OnEnter(self, ...)
			end
			lockedBy = self;
			useDummy = true;
		end,
		OnLeave = function(self, ...)
			if lockedBy ~= self then
				return alreadyHooked[self].OnLeave(self, ...)
			end
			useDummy = false;
		end,
		OnDragStart = function(self, ...)
			if lockedBy ~= false then
				return alreadyHooked[self].OnDragStart(self, ...)
			end
			lockedBy = self;
			useDummy = true;
		end,
		OnDragStop = function(self, ...)
			if lockedBy ~= self then
				return alreadyHooked[self].OnDragStop(self, ...)
			end
			useDummy = false;
		end
	}

	function addHooks(obj)
		if alreadyHooked[obj] then
			return;
		end
		alreadyHooked[obj] = {}
		for e, f in pairs(objHookedFunctions) do
			local func = obj:GetScript(e)
			if func then
				alreadyHooked[obj][e] = func;
				obj:SetScript(e, f);
			end
		end
	end
end

-- move anchoring of objects from minimap to dummy and back
local objSetPoint = {};
local objSetParent = {};
local function objectToDummy(object, enable, debugStr)
	local objName = (object.GetName and object:GetName() or tostring(object));
	local objType = object:GetObjectType();

	-- == ignore == --
	if (HBDPins and HBDPins.minimapPins[object]) -- ignore herebedragons pins
		or objType == "Line"                  -- ignore object type "Line"
		or (ignoreFrames[objName])
	then
		return;
	end

	-- == prepare == --
	local changedSetParent, changedSetPoint = false, false;
	if objSetParent[objType] == nil then
		objSetParent[objType] = getmetatable(object).__index.SetParent;
	end
	if objSetPoint[objType] == nil then
		objSetPoint[objType] = getmetatable(object).__index.SetPoint;
	end

	-- == parent == --

	-- get strata/layer/level info
	local fstrata, flevel, dlayer, dlevel
	if object.GetDrawLayer then
		dlayer, dlevel = object:GetDrawLayer(); -- textures
	else
		fstrata = object:GetFrameStrata(); -- frames
		flevel = object:GetFrameLevel();
	end

	local parent = object:GetParent();
	if enable == true and parent == Minimap then
		objSetParent[objType](object, FarmHudMinimapDummy);
		changedSetParent = true;
	elseif enable == false and parent == FarmHudMinimapDummy then
		objSetParent[objType](object, Minimap);
		changedSetParent = true;
	end

	if changedSetParent then
		-- get mouse enabled boolean
		local MouseEnabledState = object.IsMouseEnabled and object:IsMouseEnabled() or false


		-- replace SetParent function
		if enable then
			object[SetParentToken], object.SetParent = object.SetParent, dummyOnly_SetParent;
		else
			object.SetParent, object[SetParentToken] = object[SetParentToken], nil;
		end
		-- reapply strata/layer/level after change of parent
		if dlayer then
			object:SetDrawLayer(dlayer, dlevel);
		else
			object:SetFrameStrata(fstrata);
			object:SetFrameLevel(flevel);
			addHooks(object)
		end

		-- revert unwanted changed mouse enable status
		if object.IsMouseEnabled and object:IsMouseEnabled() ~= MouseEnabledState then
			ns:debug("objectToDummy", objName, "unwanted mouse enabled... revert it!")
			-- found problem with <frame>:HookScript. It enables mouse for frames on use. If this normal?
			object:EnableMouse(MouseEnabledState)
		end
	end

	-- == anchors == --
	local changedSetPoint = false; -- reset for SetPoint

	-- search and change anchors on minimap
	if object.GetNumPoints then
		for p = 1, (object:GetNumPoints()) do
			local point, relTo, relPoint, x, y = object:GetPoint(p);
			if enable == true and relTo == Minimap then
				objSetPoint[objType](object, point, FarmHudMinimapDummy, relPoint, x, y);
				changedSetPoint = true;
			elseif enable == false and relTo == FarmHudMinimapDummy then
				objSetPoint[objType](object, point, Minimap, relPoint, x, y);
				changedSetPoint = true;
			end
		end
	end

	if changedSetPoint then
		-- replace SetPoint function
		if enable then
			object[SetPointToken], object.SetPoint = object.SetPoint, dummyOnly_SetPoint;
		else
			object.SetPoint, object[SetPointToken] = object[SetPointToken], nil;
		end
	end

	return changedSetParent, changedSetPoint;
end


-- coordinates

local coordsUpdater = CreateFrame("Frame", nil, FarmHud)
coordsUpdater:Hide()
coordsUpdater:SetScript("OnUpdate", function(self, elapsed)
	self.timer = (self.timer or 0) + elapsed
	if self.timer > 0.04 then
		local x, y = GetPlayerMapPosition("player");
		if x and y and (x > 0 or y > 0) then
			FarmHud.TextFrame.coords:SetFormattedText("%.1f, %.1f", x * 100, y * 100);
		else
			FarmHud.TextFrame.coords:SetText("");
		end
		self.timer = 0
	end
end)

function FarmHudMixin:UpdateCoords(state)
	if state == true then
		coordsUpdater:Show()
	else
		coordsUpdater:Hide()
	end
	ns.SetShown(self.TextFrame.coords, state);
end

-- time

local timeUpdater = CreateFrame("Frame", nil, FarmHud)
timeUpdater:Hide()
timeUpdater:SetScript("OnUpdate", function(self, elapsed)
	self.timer = (self.timer or 0) + elapsed
	if self.timer > 1.0 then
		local timeStr = {};
		if FarmHudDB.time_server then
			local sH, sM = GetGameTime();
			tinsert(timeStr, format("%02d:%02d", sH, sM));
		end
		if FarmHudDB.time_local then
			tinsert(timeStr, date("%H:%M")); -- local time
			if #timeStr == 2 then
				timeStr[1] = "R: " .. timeStr[1];
				timeStr[2] = "L: " .. timeStr[2];
			end
		end
		FarmHud.TextFrame.time:SetText(table.concat(timeStr, " / "));
		self.timer = 0
	end
end)

function FarmHudMixin:UpdateTime(state)
	if state == true then
		timeUpdater:Show()
		-- Force initial update
		local sH, sM = GetGameTime();
		if FarmHudDB.time_server and sH then FarmHud.TextFrame.time:SetText(format("%02d:%02d", sH, sM)) end
	else
		timeUpdater:Hide()
	end
	ns.SetShown(self.TextFrame.time, state);
end

FarmHudMinimapDummyMixin = {}

function FarmHudMinimapDummyMixin:OnMouseUp()
	if type(mps.OnMouseUp) ~= "function" then return end
	mps.OnMouseUp(self);
end

function FarmHudMinimapDummyMixin:OnMouseDown()
	if type(mps.OnMouseDown) ~= "function" and not type(mps.OnMouseUp) ~= "function" then
		return -- Ignore OnMouseDown of OnMouseUp present
	end
	mps.OnMouseDown(self);
end

-- main frame mixin functions

function FarmHudMixin:SetScales(enabled)
	if self ~= FarmHud then
		self = FarmHud
	end

	-- using WorldFrame size for changable view port by users
	local eScale = UIParent:GetEffectiveScale();
	local width, height = WorldFrame:GetSize();
	if width == 0 or height == 0 then
		width = GetScreenWidth() * eScale;
		height = GetScreenHeight() * eScale;
	end
	width, height = width / eScale, height / eScale;
	local size = min(width, height);

	-- Root Cause Fix: Clamp size to actual screen height to prevent 7000px glitch
	local screenH = UIParent:GetHeight()
	if size > screenH then size = screenH end

	if size <= 0 then size = 768 end -- Fallback to safe default

	self:SetSize(size, size);

	local MinimapSize = size * FarmHudDB.hud_size;
	local MinimapScaledSize = MinimapSize / FarmHudDB.hud_scale;
	MinimapMT.SetScale(Minimap, FarmHudDB.hud_scale);
	MinimapMT.SetSize(Minimap, MinimapScaledSize, MinimapScaledSize);

	-- Fix for 3.3.5a interaction distance: Extend hitbox to cover full screen without changing visual size
	local extraW = math.max(0, width - size) / 2;
	local extraH = math.max(0, height - size) / 2;
	-- Adjust for HUD scale
	local insetW = extraW / FarmHudDB.hud_scale;
	local insetH = extraH / FarmHudDB.hud_scale;

	Minimap:SetHitRectInsets(-insetW, -insetW, -insetH, -insetH);
	Minimap:SetClampedToScreen(false);

	self.size = MinimapSize;

	self.cluster:SetScale(FarmHudDB.hud_scale);
	self.cluster:SetSize(MinimapScaledSize, MinimapScaledSize);
	self.cluster:SetFrameStrata(Minimap:GetFrameStrata());
	self.cluster:SetFrameLevel(Minimap:GetFrameLevel());

	ns.modules("Update", enabled)

	local y = (self:GetHeight() * FarmHudDB.buttons_radius) * 0.5;
	if (FarmHudDB.buttons_bottom) then y = -y; end
	self.onScreenButtons:ClearAllPoints();
	self.onScreenButtons:SetPoint("CENTER", self, "CENTER", 0, y);

	self.TextFrame:SetScale(FarmHudDB.text_scale);
	self.TextFrame.ScaledHeight = (size / FarmHudDB.text_scale) * 0.5;

	local coords_y = self.TextFrame.ScaledHeight * FarmHudDB.coords_radius;
	local time_y = self.TextFrame.ScaledHeight * FarmHudDB.time_radius;
	if (FarmHudDB.coords_bottom) then coords_y = -coords_y; end
	if (FarmHudDB.time_bottom) then time_y = -time_y; end

	self.TextFrame.coords:ClearAllPoints()
	self.TextFrame.time:ClearAllPoints()
	self.TextFrame.mouseWarn:ClearAllPoints()

	self.TextFrame.coords:SetPoint("CENTER", self, "CENTER", 0, coords_y);
	self.TextFrame.time:SetPoint("CENTER", self, "CENTER", 0, time_y);
	self.TextFrame.mouseWarn:SetPoint("CENTER", self, "CENTER", 0, -16);

	if enabled then
		self:UpdateForeignAddOns(true)
	end
end

function FarmHudMixin:UpdateScale()
	if not self:IsShown() then return end
end

function FarmHudMixin:UpdateForeignAddOns(state)
	local Map = state and self.cluster or Minimap;

	if _G["GatherMate2"] then
		_G["GatherMate2"]:GetModule("Display"):ReparentMinimapPins(Map);
	end
	if _G["Routes"] and _G["Routes"].ReparentMinimap then
		_G["Routes"]:ReparentMinimap(Map);
	end
	if _G["Bloodhound2"] and _G["Bloodhound2"].ReparentMinimap then
		_G["Bloodhound2"].ReparentMinimap(Map, "Minimap");
	end
	local HBD1 = LibStub.libs["HereBeDragons-Pins-1.0"];
	if HBD1 and HBD1.SetMinimapObject then
		HBD1:SetMinimapObject(state and Map or nil);
	end
	local HBD2 = LibStub.libs["HereBeDragons-Pins-2.0"];
	if HBD2 and HBD2.SetMinimapObject then
		HBD2:SetMinimapObject(state and Map or nil);
	end
	if LibStub.libs["HereBeDragonsQuestie-Pins-2.0"] then
		LibStub("HereBeDragonsQuestie-Pins-2.0"):SetMinimapObject(state and Map or nil);
	end
	if LibHijackMinimap then
		LibHijackMinimap:ReleaseMinimap(LibHijackMinimap_Token, state and Map or nil);
	end
end

do
	-- the following part apply some config changes while FarmHud is enabled
	local function IsKey(k1, k2)
		return k1 == k2 or k1 == nil;
	end
	function FarmHudMixin:UpdateOptions(key)
		if not self:IsVisible() then return end

		self:SetScales(true);

		if IsKey(key, "background_alpha") or IsKey(key, "background_alpha2") or IsKey(key, "background_alpha_toggle") then
			self:UpdateMapAlpha("OptChange")
		elseif IsKey(key, "player_dot") then
			SetPlayerDotTexture(true);
		elseif IsKey(key, "mouseoverinfo_color") then
			self.TextFrame.mouseWarn:SetTextColor(unpack(FarmHudDB.mouseoverinfo_color));
		elseif IsKey(key, "coords_show") then
			ns.SetShown(self.TextFrame.coords, FarmHudDB.coords_show);
		elseif IsKey(key, "coords_color") then
			self.TextFrame.coords:SetTextColor(unpack(FarmHudDB.coords_color));
		elseif IsKey(key, "time_show") then
			ns.SetShown(self.TextFrame.time, FarmHudDB.time_show);
		elseif IsKey(key, "time_color") then
			self.TextFrame.time:SetTextColor(unpack(FarmHudDB.time_color));
		elseif IsKey(key, "buttons_show") then
			ns.SetShown(self.onScreenButtons, FarmHudDB.buttons_show);
		elseif IsKey(key, "buttons_alpha") then
			self.onScreenButtons:SetAlpha(FarmHudDB.buttons_alpha);
		elseif IsKey(key, "showDummy") then
			ns.SetShown(FarmHudMinimapDummy, FarmHudDB.showDummy);
		elseif IsKey(key, "showDummyBg") then
			ns.SetShown(FarmHudMinimapDummy.bg,
				FarmHudDB.showDummyBg and (not HybridMinimap or (HybridMinimap and not HybridMinimap:IsShown())));
		elseif key:find("tracking^.+") and not ns.IsClassic() then
			local id = key:match("^tracking%^(.+)$");
			if id then
				TrackingTypes_Update(true, id);
			end
		elseif key:find("rotation") then
			rotationMode = FarmHudDB.rotation and "1" or "0";
			C_CVar.SetCVar("rotateMinimap", rotationMode);
			Minimap_UpdateRotationSetting();
		elseif IsKey(key, "SuperTrackedQuest") and FarmHud_ToggleSuperTrackedQuest and FarmHud:IsShown() then
			FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken, FarmHudDB.SuperTrackedQuest);
		elseif IsKey(key, "hud_size") then
			FarmHud:SetScales();
		end
	end
end

local function Minimap_OnClick(self)
	-- Copy of Minimap_OnClick. Require for replaced functions GetCenter and GetEffectiveScale
	local x, y = GetCursorPosition();
	local s, X, Y = MinimapMT.GetEffectiveScale(Minimap)
	x = x / s;
	y = y / s;

	local cx, cy = MinimapMT.GetCenter(Minimap)
	X = x - cx;
	Y = y - cy;

	if (sqrt(X * X + Y * Y) < (self:GetWidth() / 2)) then
		Minimap:PingLocation(X, Y);
	end
end

local MinimapSetAllPoints;
function MinimapSetAllPoints(try)
	-- sometimes SetPoint produce error "because[SetPoint would result in anchor family connection]"
	ns:debug("<MinimapSetAllPoints>", tostring(try))
	if try == nil then
		for i = 1, 3 do
			local retOK, ret1 = pcall(MinimapSetAllPoints, i);
			if retOK then
				return true;
			end
		end
		return;
	end
	MinimapMT.ClearAllPoints(Minimap);
	if try < 3 then
		MinimapMT.SetPoint(Minimap, "CENTER", FarmHud, "CENTER", 0, 0);
	else
		MinimapMT.SetAllPoints(Minimap);
	end
end

function FarmHudMixin:OnShow()
	-- Abort if in combat to prevent taint spreading to action bars
	if InCombatLockdown() then
		C_Timer.After(0.5, function()
			if not InCombatLockdown() and not FarmHud:IsShown() then
				FarmHud:Show()
			end
		end)
		return FarmHud:Hide()
	end
	trackEnableMouse = true;

	FarmHudMinimapDummy:SetParent(Minimap:GetParent());
	FarmHudMinimapDummy:SetScale(Minimap:GetScale());
	FarmHudMinimapDummy:SetSize(Minimap:GetSize());
	FarmHudMinimapDummy:SetFrameStrata(Minimap:GetFrameStrata());
	FarmHudMinimapDummy:SetFrameLevel(Minimap:GetFrameLevel());
	FarmHudMinimapDummy:ClearAllPoints();
	for i = 1, Minimap:GetNumPoints() do
		FarmHudMinimapDummy:SetPoint(Minimap:GetPoint(i));
	end
	ns.SetShown(FarmHudMinimapDummy.bg,
		FarmHudDB.showDummyBg and (not HybridMinimap or (HybridMinimap and not HybridMinimap:IsShown())));
	ns.SetShown(FarmHudMinimapDummy, FarmHudDB.showDummy);
	self.cluster:Show();
	-- Ensure TextFrame is visible and inherits size (since XML lacked points)
	if self.TextFrame then
		self.TextFrame:SetAllPoints(self);
		self.TextFrame:Show();
	end
	-- Ensure buttons are managed
	if self.onScreenButtons then
		ns.SetShown(self.onScreenButtons, FarmHudDB.buttons_show);
	end

	-- cache some data from minimap
	mps.anchors = {};
	mps.childs = {};
	mps.replacements = {};
	mps.zoom = Minimap:GetZoom();
	mps.parent = Minimap:GetParent();
	mps.scale = Minimap:GetScale();
	mps.size = { Minimap:GetSize() };
	mps.strata = Minimap:GetFrameStrata();
	mps.level = Minimap:GetFrameLevel();
	mps.mouse = Minimap:IsMouseEnabled();
	mps.mousewheel = Minimap:IsMouseWheelEnabled();
	mps.alpha = Minimap:GetAlpha();
	mps.backdropMouse = MinimapBackdrop:IsMouseEnabled();
	mps.minimapTrackedInfov3 = tonumber(GetCVar("minimapTrackedInfov3"));


	-- cache script entries
	-- TAINT FIX: Script modifications removed - they were causing action bar taint
	-- We now leave Minimap scripts untouched to prevent taint spread
	local OnMouseUp = Minimap:GetScript("OnMouseUp");
	local OnMouseDown = Minimap:GetScript("OnMouseDown");
	mps.OnMouseUp = OnMouseUp;
	mps.OnMouseDown = OnMouseDown;
	-- Note: We no longer modify scripts, just cache them for reference

	-- cache minimap anchors
	for i = 1, Minimap:GetNumPoints() do
		mps.anchors[i] = { Minimap:GetPoint(i) };
	end

	-- TAINT FIX v1.0.4: Disabled ALL objectToDummy calls
	-- This function was replacing methods (SetParent, SetPoint) on child frames and
	-- calling SetScript on them, which caused massive taint spread to action bars
	-- Trade-off: Some minimap button addons may not work correctly with FarmHud

	-- move child and regions of a frame to FarmHudDummy
	-- for object, movedElements in pairs(foreignObjects) do
	-- 	local parent, point
	-- 	-- childs
	-- 	local childs = { object:GetChildren() };
	-- 	for i = 1, #childs do
	-- 		if not ignoreFrames[childs[i]:GetName()] then
	-- 			parent, point = objectToDummy(childs[i], true, "OnShow.GetChildren");
	-- 			if parent or point then
	-- 				tinsert(movedElements.childs, childs[i]);
	-- 			end
	-- 		end
	-- 	end

	-- 	-- child textures/fontstrings
	-- 	local regions = { object:GetRegions() };
	-- 	for r = 1, #regions do
	-- 		parent, point = objectToDummy(regions[r], true, "OnShow.GetRegions");
	-- 		if parent or point then
	-- 			tinsert(movedElements.regions, regions[r]);
	-- 		end
	-- 	end
	-- end

	-- reanchor named frames that not have minimap as parent but anchored on it
	mps.anchoredFrames = {};
	-- for _, frameName in ipairs(anchoredFrames) do
	-- 	local frame;
	-- 	if frameName:match("%.") then
	-- 		local path = { strsplit(".", frameName) };
	-- 		if _G[path[1]] then
	-- 			local f = _G[path[1]]
	-- 			for i = 2, #path do
	-- 				if f[path[i]] then
	-- 					f = f[path[i]];
	-- 				end
	-- 			end
	-- 			frame = f;
	-- 		end
	-- 	end
	-- 	if _G[frameName] then
	-- 		frame = _G[frameName];
	-- 	end
	-- 	if frame and objectToDummy(frame, true, "OnShow.anchoredFrames") then
	-- 		mps.anchoredFrames[frameName] = true;
	-- 	end
	-- end

	-- nameless textures
	-- if #minimapCreateTextureTable > 0 then
	-- 	for i = 1, #minimapCreateTextureTable do
	-- 		objectToDummy(minimapCreateTextureTable[i], true, "OnShow.minimapCreateTextureTable");
	-- 	end
	-- end

	-- move and change minimap for FarmHud
	MinimapMT.Hide(Minimap);
	MinimapMT.SetParent(Minimap, FarmHud);
	Minimap:ClearAllPoints();
	MinimapSetAllPoints()
	MinimapMT.SetFrameStrata(Minimap, "HIGH");
	MinimapMT.SetFrameLevel(Minimap, 50);
	MinimapMT.SetScale(Minimap, 1);
	MinimapMT.SetZoom(Minimap, 0);
	self:UpdateMapAlpha("OnShow");

	-- disable mouse enabled frames (protected during combat)
	suppressNextMouseEnable = true;
	if not InCombatLockdown() then
		MinimapMT.EnableMouse(Minimap, false);
		MinimapMT.EnableMouseWheel(Minimap, false);
	end

	mps.backdropMouse = MinimapBackdrop:IsMouseEnabled();
	if mps.backdropMouse then
		MinimapBackdrop:EnableMouse(false);
	end

	local mc_points = { MinimapCluster:GetPoint() };
	if mc_points[2] == Minimap then
		mps.mc_mouse = MinimapCluster:IsMouseEnabled();
		mps.mc_mousewheel = MinimapCluster:IsMouseWheelEnabled();
		MinimapCluster:EnableMouse(false);
		MinimapCluster:EnableMouseWheel(false);
	end

	mps.rotation = C_CVar.GetCVar("rotateMinimap");
	if FarmHudDB.rotation ~= (mps.rotation == "1") then
		rotationMode = FarmHudDB.rotation and "1" or "0";
		C_CVar.SetCVar("rotateMinimap", rotationMode);
		Minimap_UpdateRotationSetting();
		if not ns.IsDragonFlight() then
			MinimapCompassTexture:Hide(); -- Note: Compass Texture is the new border texture in dragonflight
		end
	end

	-- TAINT FIX: Method replacements removed - they were causing action bar taint
	-- We now leave Minimap methods untouched to prevent taint spread
	-- The replacements table was used to intercept GetWidth/GetCenter/etc but this taints Minimap
	-- for k, v in pairs(replacements) do
	-- 	mps.replacements[k] = Minimap[k];
	-- 	Minimap[k] = v;
	-- end

	if FarmHud_ToggleSuperTrackedQuest and FarmHudDB.SuperTrackedQuest then
		FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken, true); -- FarmHud_QuestArrow
	end

	SetPlayerDotTexture(true);
	TrackingTypes_Update(true);

	self:UpdateCoords(FarmHudDB.coords_show);
	self:UpdateTime(FarmHudDB.time_show);

	-- second try to suppress mouse enable state (protected during combat)
	suppressNextMouseEnable = true;
	if not InCombatLockdown() then
		MinimapMT.EnableMouse(Minimap, false);
		MinimapMT.EnableMouseWheel(Minimap, false);
	end

	self:SetScales(true);
	ns.modules("OnShow", true)

	MinimapMT.Show(Minimap);
end

function FarmHudMixin:OnHide()
	if rotationMode ~= mps.rotation then
		C_CVar.SetCVar("rotateMinimap", mps.rotation);
		rotationMode = mps.rotation
		Minimap_UpdateRotationSetting();
	end

	trackEnableMouse = false;

	-- TAINT FIX: Method restorations removed - we no longer replace methods
	-- for k in pairs(replacements) do
	-- 	Minimap[k] = mps.replacements[k];
	-- end

	Minimap:Hide();
	MinimapMT.SetParent(Minimap, mps.parent);
	MinimapMT.SetScale(Minimap, mps.scale);
	MinimapMT.SetSize(Minimap, unpack(mps.size));
	MinimapMT.SetFrameStrata(Minimap, mps.strata);
	MinimapMT.SetFrameLevel(Minimap, mps.level);
	MinimapMT.EnableMouse(Minimap, mps.mouse);
	MinimapMT.EnableMouseWheel(Minimap, mps.mousewheel);

	-- Restore Minimap HitRect and Clamping (Fix Mouse Control)
	Minimap:SetHitRectInsets(0, 0, 0, 0);
	Minimap:SetClampedToScreen(true);

	self:UpdateMapAlpha("OnHide", mps.alpha)
	Minimap:Show();

	FarmHudMinimapDummy.bg:Hide();
	FarmHudMinimapDummy:Hide();
	self.cluster:Hide();

	-- TAINT FIX: Script restorations removed - we no longer modify scripts
	-- if mps.OnMouseDown and Minimap:GetScript("OnMouseDown") == nil then
	-- 	MinimapMT.SetScript(Minimap, "OnMouseUp", mps.OnMouseUp);
	-- 	MinimapMT.SetScript(Minimap, "OnMouseDown", mps.OnMouseDown);
	-- 	FarmHudMinimapDummy:SetScript("OnMouseUp", nil);
	-- 	FarmHudMinimapDummy:SetScript("OnMouseDown", nil);
	-- 	FarmHudMinimapDummy:EnableMouse(false);
	-- elseif mps.OnMouseUp then
	-- 	MinimapMT.SetScript(Minimap, "OnMouseUp", mps.OnMouseUp);
	-- 	FarmHudMinimapDummy:SetScript("OnMouseUp", nil);
	-- 	FarmHudMinimapDummy:EnableMouse(false);
	-- end

	-- for name, todo in pairs(minimapScripts) do
	-- 	if type(mps[name]) == "function" then
	-- 		MinimapMT.SetScript(Minimap, name, mps[name]);
	-- 	end
	-- end

	MinimapMT.ClearAllPoints(Minimap);
	for i = 1, #mps.anchors do
		MinimapMT.SetPoint(Minimap, unpack(mps.anchors[i]));
	end

	-- move child frames and regions (textures/fontstrings) of a frame back agian to Minimap
	for object, movedElements in pairs(foreignObjects) do
		-- childs
		for i = 1, #movedElements.childs do
			objectToDummy(movedElements.childs[i], false, "OnHide.GetChildren");
		end
		wipe(movedElements.childs);

		-- child textures/fontstrings
		for r = 1, #movedElements.regions do
			objectToDummy(movedElements.regions[r], false, "OnHide.GetRegions");
		end
		wipe(movedElements.regions);
	end

	-- anchored frames by name
	if mps.anchoredFrames then
		for frameName in pairs(mps.anchoredFrames) do
			if _G[frameName] then
				objectToDummy(_G[frameName], false, "OnHide.anchoredFrames");
			end
		end
	end

	-- nameless textures
	if #minimapCreateTextureTable > 0 then
		for i = 1, #minimapCreateTextureTable do
			objectToDummy(minimapCreateTextureTable[i], false, "OnHide.minimapCreateTextureTable");
		end
	end

	if mps.mc_mouse then
		MinimapCluster:EnableMouse(true);
	end
	if mps.mc_mousewheel then
		MinimapCluster:EnableMouseWheel(true);
	end

	local maxLevels = Minimap:GetZoomLevels();
	if mps.zoom > maxLevels then mps.zoom = maxLevels; end
	MinimapMT.SetZoom(Minimap, mps.zoom);

	-- if FarmHud_ToggleSuperTrackedQuest and FarmHudDB.SuperTrackedQuest then
	-- 	FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,false); -- FarmHud_QuestArrow
	-- end

	ns.modules("OnHide");

	SetPlayerDotTexture(false);
	TrackingTypes_Update(false);

	wipe(mps);

	self:UpdateCoords(false);
	self:UpdateTime(false);
	self:UpdateForeignAddOns(false);

	-- Force refresh minimap zone data to restore texture immediately
	SetMapToCurrentZone()

	if mps.backdropMouse ~= MinimapBackdrop:IsMouseEnabled() then
		MinimapBackdrop:EnableMouse(mps.backdropMouse);
	end
end

local function checkOnKnownProblematicAddOns()
	wipe(knownProblematicAddOnsDetected);
	for addOnName, bool in pairs(knownProblematicAddOns) do
		if bool and (C_AddOns.IsAddOnLoaded(addOnName)) then
			tinsert(knownProblematicAddOnsDetected, addOnName);
		end
	end
end

--- RegisterForeignAddOnObject
-- Register a frame or button or other type to help avoid problems with FarmHud.
-- FarmHud check childs and regions of the object and change SetPoint anchored from Minimap to FarmHudDummy
-- while FarmHud is enabled and OnHide back again.
-- @object: object - a frame table that is anchored on Minimap and holds texture, fontstrings or other elements that should be moved to FarmHudDummy while FarmHud is enabled.
-- @byAddOn: string - name of the addon. this will be disable warning message on toggle FarmHud.
-- @return: boolean - true on success

function FarmHudMixin:RegisterForeignAddOnObject(object, byAddOn)
	local arg1Type, arg2Type = type(object), type(byAddOn);
	assert(arg1Type == "table" and object.GetObjectType,
		"Argument #1 (called object) must be a table (frame,button,...), got " .. arg1Type);
	assert(arg2Type == "string", "Argument #2 (called byAddOn) must be a string, got " .. arg2Type);
	foreignObjects[object] = { childs = {}, regions = {}, byAddOn = byAddOn };
	if knownProblematicAddOns[byAddOn] then
		knownProblematicAddOns[byAddOn] = nil; -- remove addon from knownProblematicAddOns table
		checkOnKnownProblematicAddOns();
	end
	return false;
end

-- Toggle FarmHud display
function FarmHudMixin:Toggle(force)
	-- Prevent toggle during combat to avoid taint spreading to action bars
	if InCombatLockdown() then
		ns:print("|cffff6600Cannot toggle FarmHud during combat (prevents action bar taint)|r")
		return
	end
	if #knownProblematicAddOnsDetected > 0 then
		ns:print("|cffffee00" .. L["KnownProblematicAddOnDetected"] .. "|r",
			"|cffff8000(" .. table.concat(knownProblematicAddOnsDetected, ", ") .. ")|r")
	end
	if force == nil then
		force = not self:IsShown();
	end
	if force and MinimapFunctionHijacked then
		local isHijacked = {};
		for i = 1, #MinimapFunctionHijacked do
			local k = MinimapFunctionHijacked[i];
			if MinimapMT[k] ~= Minimap[k] then
				local _, taintBy = issecurevariable(Minimap, k);
				tinsert(isHijacked, k .. " (" .. (taintBy or UNKNOWN) .. ")");
			end
		end
		if #isHijacked > 0 then
			ns:print("|cffffee00" .. L["AnotherAddOnsHijackedFunc"] .. "|r", table.concat(isHijacked, ", "));
			return;
		end
	end
	ns.SetShown(self, force);
end

-- Tooltip fix for 3.3.5a: Manual scan since Minimap ping/zoom prevents standard tooltip
local tooltipFrame = CreateFrame("Frame")
tooltipFrame:Hide()
tooltipFrame:SetScript("OnUpdate", function(self, elapsed)
	if not FarmHud:IsVisible() then return end
	if not Minimap:IsMouseEnabled() then
		GameTooltip:Hide()
		return
	end

	local mouseX, mouseY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = Minimap:GetCenter()
	local dx, dy = (mouseX / scale) - cx, (mouseY / scale) - cy
	if (dx * dx + dy * dy < (Minimap:GetWidth() / 2) ^ 2) then
		Minimap:PingLocation(dx, dy) -- This forces a ping, but maybe we just need to let the game handle it if strata is correct
	end
	-- Actually 3.3.5a Minimap doesn't easily expose blip tooltips manually without Ping or native hover.
	-- If native hover isn't working, strata/mask is likely the issue.
	-- But we tried strata.
	-- Let's try forcing UpdateTooltip on the Minimap if GameTooltip is stuck.
	-- Or, just leave this empty for now if we can't manually scan blips (API doesn't exist).
end)

function FarmHudMixin:ToggleMouse(force)
	if FarmHud:IsVisible() then
		local shouldEnable = not Minimap:IsMouseEnabled()
		if force ~= nil then shouldEnable = force end

		suppressNextMouseEnable = true;
		Minimap:EnableMouse(shouldEnable); -- Direct call

		if shouldEnable then
			self.TextFrame.mouseWarn:Show();
			-- tooltipFrame:Show() -- Not implemented fully as API is limited
			Minimap:SetZoom(Minimap:GetZoom() == 0 and 1 or 0) -- Toggle zoom to refresh blips?
			Minimap:SetZoom(0)
		else
			self.TextFrame.mouseWarn:Hide();
			-- tooltipFrame:Hide()
		end

		if not force then
			mouseOnKeybind = not shouldEnable
		end
	end
end

function FarmHudMixin:ToggleBackground()
	if Minimap:GetParent() == self then
		self:UpdateMapAlpha("ToggleBackground")
	end
end

function FarmHudMixin:ToggleOptions()
	if ACD.OpenFrames[addon] ~= nil then
		ACD:Close(addon);
	else
		ACD:Open(addon);
		ACD.OpenFrames[addon]:SetStatusText(GAME_VERSION_LABEL .. (CHAT_HEADER_SUFFIX or ": ") .. "Ascension 3.3.5");
	end
end

function FarmHudMixin:AddChatMessage(token, msg)
	local from = (token == ns.QuestArrowToken and "QuestArrow") or false
	if from and type(msg) == "string" then
		ns:print("()", from, L[msg]);
	end
end

function FarmHudMixin:RegisterModule(name, module)
	assert(type(name) == "string" and type(module) == "table",
		"FarmHud:RegisterModule(<moduleName[string]>, <module[table]>)");
	ns.modules[name] = module;
end

function FarmHudMixin:OnEvent(event, ...)
	if event == "ADDON_LOADED" and addon == ... then
		ns.RegisterOptions();
		ns.RegisterDataBroker();
		if FarmHudDB.AddOnLoaded or IsShiftKeyDown() then
			ns:print(L.AddOnLoaded);
		end
	elseif event == "PLAYER_LOGIN" then
		self:SetFrameLevel(2);

		--local radius = Minimap:GetWidth() * 0.214;
		for i, v in ipairs(self.TextFrame.cardinalPoints) do
			local label = v:GetText();
			v.NWSE = strlen(label) == 1;
			v.rot = (0.785398163 * (i - 1));
			-- v:SetFontObject("FarmHudFont");
			v:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE");
			v:SetText(L[label]);
			v:SetTextColor(1.0, 0.82, 0);
			if v.NWSE then
				v:SetTextColor(unpack(FarmHudDB.cardinalpoints_color1));
			else
				v:SetTextColor(unpack(FarmHudDB.cardinalpoints_color2));
			end
		end

		ns.SetShown(self.TextFrame.coords, FarmHudDB.coords_show);

		self.TextFrame.coords:SetTextColor(unpack(FarmHudDB.coords_color));

		self.TextFrame.time:SetTextColor(unpack(FarmHudDB.time_color));
		ns.SetShown(self.TextFrame.time, FarmHudDB.time_show);

		ns.SetShown(self.onScreenButtons, FarmHudDB.buttons_show);
		self.onScreenButtons:SetAlpha(FarmHudDB.buttons_alpha);

		self.TextFrame.mouseWarn:SetText(L.MouseOn);
		self.TextFrame.mouseWarn:SetTextColor(unpack(FarmHudDB.mouseoverinfo_color));

		if (LibStub.libs['LibHijackMinimap-1.0']) then
			LibHijackMinimap = LibStub('LibHijackMinimap-1.0');
			LibHijackMinimap:RegisterHijacker(addon, LibHijackMinimap_Token);
		end

		if _G["BasicMinimap"] and _G["BasicMinimap"].backdrop then
			self:RegisterForeignAddOnObject(_G["BasicMinimap"].backdrop:GetParent(), "BasicMinimap");
		end

		checkOnKnownProblematicAddOns()
		self.playerIsLoggedIn = true
	elseif event == "PLAYER_LOGOUT" and mps.rotation and rotationMode and rotationMode ~= mps.rotation then
		-- reset rotation on logout and reload if FarmHud was open
		C_CVar.SetCVar("rotateMinimap", mps.rotation);
	elseif event == "MODIFIER_STATE_CHANGED" and self:IsShown() then
		local key, down = ...;
		if not mouseOnKeybind and modifiers[FarmHudDB.holdKeyForMouseOn] and modifiers[FarmHudDB.holdKeyForMouseOn][key] == 1 then
			self:ToggleMouse(down == 0);
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if FarmHudDB.hideInInstance then
			if IsInInstance() and FarmHud:IsShown() and not excludeInstance[1] then
				self.hideInInstanceActive = true;
				self:Hide() -- hide FarmHud in Instance
			elseif self.hideInInstanceActive then
				self.hideInInstanceActive = nil;
				self:Show(); -- restore visibility on leaving instance
			end
		end
	elseif event == "PLAYER_REGEN_DISABLED" and FarmHudDB.hideInCombat and FarmHud:IsShown() then
		self.hideInCombatActive = true;
		-- Defer hide to next frame to avoid tainting action bars during combat transition
		C_Timer.After(0, function()
			if FarmHud.hideInCombatActive and FarmHud:IsShown() then
				FarmHud:Hide()
			end
		end)
		return
	elseif event == "PLAYER_REGEN_ENABLED" and FarmHudDB.hideInCombat and self.hideInCombatActive then
		self.hideInCombatActive = nil;
		-- Defer show to next frame to avoid tainting action bars during combat transition
		C_Timer.After(0, function()
			if not FarmHud.hideInCombatActive and not InCombatLockdown() then
				FarmHud:Show()
			end
		end)
		return;
	end
end

function FarmHudMixin:OnLoad()
	ns.Mixin(self, FarmHudMixin)
	-- FarmHudMinimapDummy.bg:SetMask("interface/CHARACTERFRAME/TempPortraitAlphaMask");

	-- Polyfill parentArray "cardinalPoints" and ensure parentKeys
	-- Polyfill parentArray "cardinalPoints" and ensure parentKeys
	-- 1. Initialize table if missing
	if not self.TextFrame.cardinalPoints then
		self.TextFrame.cardinalPoints = {}
	end

	-- 2. If table is empty, find regions manually
	if #self.TextFrame.cardinalPoints == 0 then
		local regions = { self.TextFrame:GetRegions() }
		for _, region in ipairs(regions) do
			if region:GetObjectType() == "FontString" then
				local text = region:GetText()
				-- Filter out known parentKeys if possible, or just match text
				if region ~= self.TextFrame.mouseWarn and region ~= self.TextFrame.coords and region ~= self.TextFrame.time then
					-- Match standard cardinal points (English XML defaults)
					if text and (text:match("^[NSWE][NSWE]?$") or text:match("^[NSWE][NSWE]?$")) then
						tinsert(self.TextFrame.cardinalPoints, region)
					elseif text == nil then
						-- Potential unnamed cardinal point if localized?
						-- Unlikely, just skip
					end
				end
			end
		end
	end

	-- 3. Iterate table (populated by parentArray OR manual above) and assign rotations
	for i, region in ipairs(self.TextFrame.cardinalPoints) do
		local text = region:GetText() or ""
		-- Assign rotation (radians) assuming 0=North, pi/2=East?
		-- Based on logic: x=sin(rot+bearing), y=cos(rot+bearing).
		-- N=0, NE=pi/4, E=pi/2, SE=3pi/4, S=pi, SW=5pi/4, W=3pi/2, NW=7pi/4
		local rots = {
			["N"] = 0,
			["NE"] = math.pi / 4,
			["E"] = math.pi / 2,
			["SE"] = 3 * math.pi / 4,
			["S"] = math.pi,
			["SW"] = 5 * math.pi / 4,
			["W"] = 3 * math.pi / 2,
			["NW"] = 7 * math.pi / 4,
		}
		-- Fallback for non-matching text (e.g. localized) -> Use Index
		if rots[text] then
			region.rot = rots[text]
		else
			-- 0 to 7. 0=N.
			-- Map index to N, NE, E...
			-- i=1 (N) -> 0. i=2 (NE) -> pi/4.
			-- (i-1) * pi/4
			region.rot = (i - 1) * (math.pi / 4)
		end
		region.NWSE = (i % 2 == 1) -- Odd indices are N, E, S, W (1, 3, 5, 7)
	end
	-- End Discovery Block


	-- Verify other parentKeys if needed (mouseWarn, coords, time).
	-- If TextFrame exists, likely they exist.
	if not self.TextFrame.coords then
		-- Fallback search if parentKey failed
		local regions = { self.TextFrame:GetRegions() }
		local found = 0
		for _, region in ipairs(regions) do
			if region:GetObjectType() == "FontString" and not region:GetText() then
				-- Inspect further?
				-- XML: coords hidden=true, time hidden=true.
				if found == 0 then
					self.TextFrame.coords = region; found = 1
				elseif found == 1 then
					self.TextFrame.time = region; found = 2
				end
			end
		end
	end

	if self.TextFrame.mouseWarn then self.TextFrame.mouseWarn:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE"); end
	if self.TextFrame.coords then self.TextFrame.coords:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE"); end
	if self.TextFrame.time then self.TextFrame.time:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE"); end

	self:RegisterForeignAddOnObject(Minimap, addon);

	-- TAINT FIX v1.0.3: All hooksecurefunc calls on Minimap removed
	-- These hooks inject addon code into Blizzard's secure call path, causing taint
	-- The hooks were intercepting SetPlayerTexture, SetZoom, SetAlpha, EnableMouse
	-- Trade-off: Some visual features may not work perfectly, but action bars will function

	-- hooksecurefunc(Minimap, "SetPlayerTexture", function(_, texture)
	-- 	if FarmHud:IsVisible() and not _G.FarmHud_InSetPlayerTexture then
	-- 		playerDot_custom = texture;
	-- 		SetPlayerDotTexture(true);
	-- 	end
	-- end);

	-- hooksecurefunc(Minimap, "SetZoom", function(_, level)
	-- 	if FarmHud:IsVisible() and level ~= 0 then
	-- 		MinimapMT.SetZoom(Minimap, 0);
	-- 	end
	-- end);

	-- hooksecurefunc(Minimap, "SetAlpha", function(_, level)
	-- 	if not FarmHud:IsVisible() then
	-- 		return; -- ignore
	-- 	end
	-- 	if FarmHudDB.background_alpha ~= level then
	-- 		FarmHud:UpdateMapAlpha("HookSetAlpha")
	-- 	end
	-- end);

	-- hooksecurefunc(Minimap,\"SetMaskTexture\",function(_,texture)
	-- 	FarmHudMinimapDummy.bg:SetMask(texture);
	-- end);

	-- hooksecurefunc(Minimap, "EnableMouse", function(_, bool)
	-- 	-- if not trackEnableMouse or suppressNextMouseEnable then
	-- 	-- 	suppressNextMouseEnable = false;
	-- 	-- 	return
	-- 	-- end
	-- 	-- ns:print(L.PleaseReportThisMessage,"<EnableMouse>",bool,"|n"..debugstack());
	-- end);

	-- EditModeManagerFrame removed for 3.3.5a

	if not ns.IsClassic() then
		local function hookSetTracking(index, bool)
			if not trackingHookLocked and FarmHud:IsVisible() and trackingTypesStates[index] ~= nil then
				trackingTypesStates[index] = nil;
			end
		end
		-- Hook global SetTracking for 3.3.5a
		if SetTracking then
			hooksecurefunc("SetTracking", hookSetTracking);
		else
			hooksecurefunc(C_Minimap, "SetTracking", hookSetTracking);
		end
	end

	function self.cluster:GetZoom()
		return Minimap:GetZoom();
	end

	function self.cluster:SetZoom()
		-- dummy
	end

	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("PLAYER_LOGOUT");

	self:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	self:SetFrameStrata("FULLSCREEN_DIALOG");

	-- Create standalone player arrow for 3.3.5a (decoupled from Minimap alpha)
	if not self.PlayerArrow then
		-- Parent to cluster so it inherits Strata/Scale/Visibility from cluster (which mimics Minimap)
		-- self.cluster is initialized in OnLoad via parentKey? No, XML.
		self.PlayerArrow = self.cluster:CreateTexture(nil, "OVERLAY")
		self.PlayerArrow:SetSize(32, 32)                          -- Standard arrow size
		self.PlayerArrow:SetPoint("CENTER", self.cluster, "CENTER", 0, 0)
		self.PlayerArrow:SetTexture("Interface\\Minimap\\MinimapArrow") -- Default start
		-- Ensure arrow is above minimap content
		-- Texture DrawLayer OVERLAY should be enough if parent is at same level as Minimap.
		-- We set cluster level to valid value in SetScales.
	end


	-- Rotation update loop
	self:SetScript("OnUpdate", function(f, elapsed)
		if not f:IsVisible() then return end

		-- Rotate arrow
		if GetPlayerFacing then
			local facing = GetPlayerFacing()
			if f.PlayerArrow then
				-- Minimap rotation usually counter-rotates the map, keeping arrow 'up' or 'forward'.
				-- If map rotates, arrow points UP (0).
				-- If map is static, arrow rotates to facing.
				-- FarmHud usually rotates map.
				-- If RotateMinimap is ON: Arrow points UP (standard) or Forward?
				-- Actually, native minimap arrow points North relative to Map?
				-- Wait. If map rotates north-to-top, arrow is locked Up.
				-- If map rotates so player-facing is Up, arrow is locked Up.
				-- Let's check typical behavior.
				-- User screenshot shows "Rotation" checked.
				-- If map rotates, the world rotates around player. Player stays facing "Up" on screen?
				-- No, usually Arrow points Up.
				-- But if I create a texture, I need to set its rotation.
				-- If `GetCVar("rotateMinimap")` is "1":
				--    Map rotates so player direction is always UP. Arrow rotation = 0.
				-- If `GetCVar("rotateMinimap")` is "0":
				--    Map is North-Up. Arrow points to `GetPlayerFacing()`.
				-- I need to implement this logic.

				local rot = GetCVar("rotateMinimap") == "1"
				if rot then
					f.PlayerArrow:SetRotation(0) -- Always UP
				else
					-- In 3.3.5a Check if SetRotation accepts radians (usually yes). GetPlayerFacing returns radians (0=North, pi=South, etc counter-clockwise?)
					-- SetRotation(r): r is radians counter-clockwise ?
					-- Need to verify direction. Usually `SetRotation(GetPlayerFacing())` works.
					f.PlayerArrow:SetRotation(facing)
				end
			end
		end
	end)

	self:RegisterEvent("MODIFIER_STATE_CHANGED");

	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");

	ns.modules("OnLoad");
end
