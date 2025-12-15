local addon,ns = ...;
local L = ns.L;

local module = {}
module.dbDefaults={
    cardinalpoints_show=true,
    cardinalpoints_color1={1,0.82,0,0.7},
    cardinalpoints_color2={1,0.82,0,0.7},
    cardinalpoints_radius=0.47,
    cardinalpoints_gathercircle_bind = false,
    cardinalpoints_gathercircle_pos = "inside",
    cardinalpoints_gathercircle_distance = 10,
}
module.events = {}
module.OnShow = function(state) module.ToggleCardicalPoints(state) end
module.OnHide = function() module.ToggleCardicalPoints(false) end

local function opt(info, value, ...)
    local key = info[#info]
    if value ~= nil then 
        if info.type == "color" then
            local r,g,b,a = value, ...
            FarmHudDB[key] = {r, g, b, a}
        else
            -- print("Debug: Opt Set", key, value) 
            FarmHudDB[key] = value
        end
        module.UpdateOptions(key, FarmHudDB[key])
    end
    if info.type == "color" then
        if type(FarmHudDB[key]) ~= "table" then return 1,1,1,1 end
        return unpack(FarmHudDB[key])
    end
    return FarmHudDB[key]
end

local updater = CreateFrame("Frame", nil, UIParent)
updater:SetSize(1,1)
updater:SetPoint("CENTER")
updater:Hide()

local function Update()
    if not FarmHudDB.cardinalpoints_show then return end
    
	local bearing = GetPlayerFacing() or 0;
	local scaledRadius;

	if FarmHudDB.cardinalpoints_gathercircle_bind then
		local lp,radius = FarmHudRangeCircles.CirclesDefault[1].linePool,nil; 
        if lp and #lp>0 then
            local _,_,ex,ey = lp[#lp-1]:GetEndPoint()
            if ex and ey then
                radius = math.sqrt(ex*ex + ey*ey)
            end
        end
        radius = radius or 100 -- safe default
        
        -- Logic: Calc base radius then apply distance offset
		scaledRadius = radius * 0.725
	else
        -- Logic fix: ScaledHeight is sometimes absurd (e.g. 7000+), use ScreenHeight as robust baseline
        local sh = FarmHud.TextFrame.ScaledHeight or 1000
        local screenH = UIParent:GetHeight()
        
        -- If SH is way larger than screen (2x), it's likely broken scaling math. Fallback.
        if sh > screenH * 2 then 
            sh = screenH / (FarmHudDB.text_scale or 1)
        end
        
		scaledRadius = sh * (FarmHudDB.cardinalpoints_radius or 0.47);
	end

    -- Apply Distance Offset (Universal)
    local distance = FarmHudDB.cardinalpoints_gathercircle_distance;
    if FarmHudDB.cardinalpoints_gathercircle_pos=="inside" then
        distance = -distance;
    end
    scaledRadius = scaledRadius + distance

    
    -- Verify radius is not 0 or absurdly large (clamp to visible range)
    -- Verify radius is not 0 or absurdly large
    if scaledRadius < 10 then scaledRadius = 150 end 
    -- Relaxed clamp now that input is sane
    if scaledRadius > 2000 then scaledRadius = 2000 end

	for i=1, #FarmHud.TextFrame.cardinalPoints do
		local cp = FarmHud.TextFrame.cardinalPoints[i];
		cp:ClearAllPoints();
        
        local rot = cp.rot or 0
        -- Simple recovery if missing (redundant if OnLoad fixed it, but safe)
        if not cp.rot then
             local t = cp:GetText()
             if t == "N" then rot=0 elseif t=="E" then rot=math.pi/2 elseif t=="S" then rot=math.pi elseif t=="W" then rot=3*math.pi/2 end
        end

        local x,y = math.sin(rot+bearing)*scaledRadius, math.cos(rot+bearing)*scaledRadius
		cp:SetPoint("CENTER", FarmHud, "CENTER", x, y);
        
        -- Update Color
        if cp.NWSE then
            cp:SetTextColor(unpack(FarmHudDB.cardinalpoints_color1));
        else
            cp:SetTextColor(unpack(FarmHudDB.cardinalpoints_color2));
        end
	end
end

updater:SetScript("OnUpdate", function(self, elapsed)
    Update()
end)

function module.ToggleCardicalPoints(state)
	if FarmHudDB.cardinalpoints_show and state~=false then
        updater:Show()
        Update()
		for i,e in ipairs(FarmHud.TextFrame.cardinalPoints) do
			ns.SetShown(e, true);
		end
	else
        updater:Hide()
		for i,e in ipairs(FarmHud.TextFrame.cardinalPoints) do
			ns.SetShown(e, false);
		end
	end
end

function module.UpdateOptions(key, value)
    if key == "cardinalpoints_show" then
        module.ToggleCardicalPoints(value)
    else
        Update()
    end
end

local options = {
	cardinalpoints = {
		type = "group", order = 3,
		name = L["CardinalPoints"],
		get=opt,set=opt,
		args = {
			cardinalpoints_show = {
				type = "toggle", order = 1, width = "double",
				name = L["CardinalPointsShow"], desc = L["CardinalPointsShowDesc"],
                get=opt,set=opt,
			},
            cardinalpoints_color1 = {
                type = "color", order = 2,
                name = L["Color"].." 1", hasAlpha = true,
                get=opt,set=opt,
            },
            cardinalpoints_color2 = {
                type = "color", order = 3,
                name = L["Color"].." 2", hasAlpha = true,
                get=opt,set=opt,
            },
            cardinalpoints_radius = {
                type = "range", order = 4,
                name = L["CardinalPointsRadius"],
                min = 0.2, max = 1.0, step = 0.01,
                get=opt,set=opt,
            },
			cardinalpoints_gathercircle_bind = {
                type = "toggle", order = 5,
                name = "Bind GatherCircle",
                get=opt,set=opt,
            },
            cardinalpoints_gathercircle_pos = {
                type = "select", order = 6,
                name = "Position",
                values = { inside = "Inside", outside = "Outside" },
                get=opt,set=opt,
            },
            cardinalpoints_gathercircle_distance = {
                type = "range", order = 7,
                name = "Distance",
                min = 5, max = 100, step = 1,
                get=opt,set=opt,
            },
		},
	},
}

function module.AddOptions()
	return options
end

function module.events.PLAYER_LOGIN()
	--FarmHud:UpdateCardinalPoints();
	for k,v in pairs(module.dbDefaults)do
        -- Sanity check: If DB has a table but default is not a table, it's corrupted. Reset it.
        if FarmHudDB[k] ~= nil and type(v) ~= "table" and type(FarmHudDB[k]) == "table" then
            FarmHudDB[k] = v
        end
        -- Sanity check 2: If DB has number/string but default is table (colors), it's corrupted.
        if FarmHudDB[k] ~= nil and type(v) == "table" and type(FarmHudDB[k]) ~= "table" then
             FarmHudDB[k] = CopyTable(v)
        end

		if FarmHudDB[k]==nil then
            if type(v) == "table" then
			    FarmHudDB[k] = CopyTable(v);
            else
                FarmHudDB[k] = v
            end
		end
	end
end

ns.modules["CardinalPoints"] = module;
