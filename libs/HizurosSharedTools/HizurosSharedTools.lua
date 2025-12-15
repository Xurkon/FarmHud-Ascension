
local MAJOR, MINOR = "HizurosSharedTools", tonumber((gsub("r46","r",""))) or 9999;
---@class HizurosSharedTools
local lib = LibStub:NewLibrary(MAJOR, MINOR);
if not lib then return end

local _G,tostringall,tonumber,rawset,type = _G,tostringall,tonumber,rawset,type
local ConsolePrint = ConsolePrint;

local LC = LibStub("LibColors-1.0");
local C = LC.color;
LC.colorset({
	["curseforge"] = "ff8000", --"F16436"
	["github"] = "adbac7",
	["paypal"] = "44dd44",
});

local L = setmetatable({},{
	__index = function(t,k)
		local v = tostring(k);
		rawset(t,k,v);
		return v;
	end
});

L["ThxSpecial"] = "Special thanks at..."
L["ThxLocale"] = "Thanks for the translations..."
L["ThxSupport"] = "Thanks for the support..."
L["ThxDonation"] = "Thanks for the donation..."

if LOCALE_deDE then
	L["ThxSpecial"] = "Speziellen Dank an..."
	L["ThxLocale"] = "Danke für die Übersetzungen..."
	L["ThxSupport"] = "Danke für die Unterstützung..."
	L["ThxDonation"] = "Danke für die Spende..."
	L["Credit"] = "Anerkennung"
	L["Thanks at..."] = "Danke an..."
end

--== colorized print ==--
do
	local defaultColors = {"20b0ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"};
	-- If you want your own colors add a table named printColors in your addon namespace.
	-- count of entries is not limited.

	-- Patch 11.1 - Blizzard filtering all messages to console (ConsolePrint/C_Log.LogMessage) from third party addons.
	-- Wonderful tool to avoid bothering players with accidentally forgotten debug messages.
	-- But I have to get around Console Print. I hope that won't be taken away from me too.
	local function _ConsolePrint(...)
		if not _G["DeveloperConsole"] then
			return
		end
		DeveloperConsole:AddMessage(string.join(" ",...))
	end

	local function colorize(ns,...)
		if not ns.addon then
			_ConsolePrint(MAJOR,debugstack());
		end
		local colors = ns.printColors or defaultColors; --
		local t,c,a1 = {tostringall(...)},1,...;
		if type(a1)=="boolean" then tremove(t,1); end
		if a1~=false then
			tinsert(t,1,"|cff"..colors[1]..((a1==true and ns.addon_short) or (a1=="||" and "||") or ns.addon or "oops").."|r"..(a1~="||" and HEADER_COLON or ""));
			c=2;
		end
		for i=c, #t do
			if not t[i]:find("\124c") then
				t[i],c = "|cff"..colors[c]..t[i].."|r", c<#colors and c+1 or 1;
			end
		end
		return unpack(t);
	end

	local function ns_print(ns,...)
		print(colorize(ns,...));
	end

	local function ns_debug(ns,...)
		_ConsolePrint(date("|cff999999%X|r"),colorize(ns,"<debug>",...));
	end

	local function ns_debugPrint(ns,...)
		if not ns.debugMode then return end
		print(colorize(ns,"<debug>",...));
	end

	function lib.debug(...)
		_ConsolePrint(date("|cff999999%X|r"),colorize({addon=MAJOR},"<debug>",...));
	end

	--- Add print functions to given addon namespace
	---@param ns table AddOn namespace
	---@param addon string AddOn name
	---@param short string AddOn short name
	function lib.RegisterPrint(ns,addon,short)
		ns.addon,ns.addon_short = addon,short;
		ns.print,ns.debug,ns.debugPrint = ns_print,ns_debug,ns_debugPrint;
		ns.deprecated = lib.deprecated;
	end
end

-- for internal use
local ns = {debugMode=true};
lib.RegisterPrint(ns,MAJOR,"HzST");


--== shared credits page ==--
do -- 013088, 0070E0
	local donation_platforms = {PP="|cff375388Pay|cff5a9de0Pal|r",PA="Patreon",GH="Github"};
	local myAddOns = {
		"AFK_fullscreen","AuctionSellers","BestSellButton","Broker_Everything","CommunityInfo",
		"FarmHud","FollowerLocationInfo","GarrisonRandomNPCs","GatherMate2_ImportExport","GuildApplicantTracker",
		"HizurosToolbox","HzFontPack1","LFR [of the past]","QuickRoutes","StayClassy","TooltipRealmInfo",
		-- don't sort by name. add new at the end
	};

	local github_pr_s = "For pull request on github."
	local github_pr_p = "For %d pull requests on github."
	local supporter = { -- {<color>,<name>}, <localizations>, <donations>, <otherSupportTypes>, <special text>,
		-- special mentions
		{"battlenet","liquidbase",false,"/", "deathknight","Merith", false,"(Author of DuffedUI)"},false,false,false,{"For idea and first code to add quest level to quest tracker :)",11},
		{"battlenet","pas06",false,"/", "curseforge","Bullseiify"   },{"deDE",4,6,10,7,16},false,false,{"For idea to the keystroke replace function",11},
		{"github","TegraGG (Github)"},false,false,false,{github_pr_s,16},
		{"github","bruteostrich (Github)"},false,false,false,{github_pr_s,6},
		{"github","fuba82 (Github)"}, false,false,false,{"For idea to use hooksecurefunc on mixin table.",13},
		{"github","flaicher (Github)"},false,false,false,{github_pr_s,3},
		{"github","BelegCufea (Github)"},false,false,false,{github_pr_p:format(2),3},
		{"github","kanegasi (Github)"},false,false,false,{github_pr_s,3},
		{"github","Brixus3 (Github)"},false,false,false,{github_pr_p:format(2),3},
		{"github","4C51 (Github)"},false,false,false,{github_pr_s,3},
		{"github","agentschmitt (Github)"},false,false,false,{github_pr_s,3},
		{"github","lowlee (Github)"},false,false,false,{github_pr_s,3},
		{"github","Sockdolager (Github)"},false,false,false,{github_pr_s,6},
		{"github","MrStrugglez (Github)"},false,false,false,{github_pr_s,6},
		{"github","tucomel (Github)"},false,false,false,{github_pr_s,6},
 		{"github","QartemisT (Github)"},false,false,false,{github_pr_s,13},
		{"github","lkshrk (Github)"},false,false,false,{github_pr_p:format(2),16},

		-- donations
		{"paypal","Nanci"}, false, {"PP",true}, false, false,

		-- localizations
		{"curseforge","Nelfym"},		{"frFR",1},false,false,false,
		{"curseforge","pczombie09"},	{"koKR",1},false,false,false,
		{"curseforge","KARMA_Zz"},		{"ruRU",1},false,false,false,
		{"curseforge","BNS333"},		{"zhTW",1},false,false,false,
		{"curseforge","Crisll"},		{"esES",1},false,false,false,

		{"curseforge","ZamestoTV"},		{"ruRU",2,5,9,13,15},false,false,false,
		{"curseforge","Der_Adrinator"}, {"deDE",4},false,false,false,
		{"curseforge","Nierhain"},		{"deDE",4},false,false,false,
		{"curseforge","Araldwenn"},		{"frFR",4},false,false,false,
		{"curseforge","Braincell1980"},	{"frFR",4,13},false,false,false,
		{"curseforge","netaras"},		{"koKR",4,6},false,false,false,
		{"curseforge","적셔줄게"},		{"koKR",4},false,false,false,
		{"curseforge","cikichen"},		{"zhCN",4,"zhTW",4},false,false,false,
		{"curseforge","sanxy00"},		{"zhCN",4},false,false,false,
		{"curseforge","雪夜霜刀"},		{"zhCN",4},false,false,false,
		{"curseforge","半熟魷魚"},		{"zhTW",4},false,false,false,
		{"curseforge","spridar"},		{"zhTW",4},false,false,false,

		{"curseforge","Lightuky"},		{"frFR",5},false,false,false,
		{"curseforge","TomasRipley"},	{"ruRU",5},false,false,false,

		{"curseforge","Dathwada"},		{"deDE",6},false,false,false,
		{"curseforge","supahmexman"},	{"esES",6},false,false,false,
		{"curseforge","justregular16"},	{"esMX",6},false,false,false,
		{"curseforge","Zickwik"},		{"frFR",6},false,false,false,
		{"curseforge","oxscott"},		{"itIT",6},false,false,false,
		{"curseforge","g0ldenev1l"},	{"zhCN",6},false,false,false,
		{"curseforge","gjfleo"},		{"zhCN",6},false,false,false,
		{"curseforge","kuaishan"},		{"zhCN",6},false,false,false,
		{"curseforge","mccma"},			{"zhTW",6},false,false,false,

		{"curseforge","Tumbleweed_DSA"},{"deDE",7},false,false,false,
		{"curseforge","Felli64"},		{"deDE",7},false,false,false,
		{"curseforge","Dabeuliou"},		{"frFR",7},false,false,false,
		{"curseforge","unrealcrom96"},	{"koKR",7},false,false,false,
		{"curseforge","Canettieri"},	{"ptBR",7},false,false,false,
		{"curseforge","dropdb"},		{"ruRU",7},false,false,false,
		{"curseforge","Igara86"},		{"ruRU",7},false,false,false,
		{"curseforge","Ananhaid"},		{"zhCN",7},false,false,false,

		{"curseforge","Hollicsh"},		{"ruRU",16},false,false,false,
	}

	--local foreignAddOns = {}

	local creditTemplate = {type="group",order=200,name=L["Credit"],args={
		thanks={type="description",order=0,fontSize="large",name=C("dkyellow",L["Thanks at..."])},
		thanksLine={type="header",order=1,name=""}
	}};

	local supporterTemplate = {
		type="group",inline=true,width="normal",order=0,name="",
		args={
			label={type="description",order=1,fontSize="large"},
			reasons={type="description",order=2,fontSize="medium"}
		}
	};
	local descLargeTemplate = {type="description",order=0,fontSize="large"}
	local headerTemplate = {type="header",order=0,name=""};

	local function thisAddOn(addon,tbl)
		local res,obj = {};
		for _,value in ipairs(tbl) do
			if type(value)=="string" then
				obj = value;
			elseif value==true then
				tinsert(res,obj);
			elseif myAddOns[value]==addon then
				tinsert(res,obj);
			end
		end
		if #res>0 then
			return res;
		end
		return false;
	end

	local function Supporter_GetName(entry)
		local name = {};
		if type(entry)=="table" then
			for n=1, #entry, 2 do
				local color,nameStr = entry[n], entry[n+1];
				if color then
					tinsert(name,C(color,nameStr));
				else
					tinsert(name,nameStr);
				end
			end
		else
			tinsert(name,entry);
		end
		return table.concat(name," ");
	end

	local function Supporter_GetLanguages(entries)
		local unique,res = {},{}
		for i,v in ipairs(entries) do
			local value = v:upper();
			if value=="PTPT" and not LFG_LIST_LANGUAGE_PTPT then
				-- blizzard using on eu clients LFG_LIST_LANGUAGE_PTBR instead of LFG_LIST_LANGUAGE_PTPT
				value = LFG_LIST_LANGUAGE_PTBR;
			elseif _G["LFG_LIST_LANGUAGE_"..value] then
				value = _G["LFG_LIST_LANGUAGE_"..value];
			end
			if not unique[value] then
				tinsert(res,value);
				unique[value] = true;
			end
		end
		return table.concat(res,", ");
	end

	local function Supporter_GetDonationPlatforms(entries)
		for i,v in ipairs(entries) do
			entries[i] = donation_platforms[v] or v;
		end
		return table.concat(entries,", ");
	end

	local function Supporter_GetSupport(entries)
		for i,v in ipairs(entries)do
			entries[i] = v;
		end
		return table.concat(entries,", ");
	end

	local function Supporter_AddStyle(addon,credit)
		local specials,donations,translations,special,donation,translation = {},{},{},3,2,1;

		if credit.args.thanks then
			credit.args.thanks.hidden=true
			credit.args.thanksLine.hidden=true
		end

		local prev = nil;

		local sIndex,hasNoEntries = {1,1,1,1},true;
		local labels = {"ThxLocale","ThxDonation","ThxSupport"}
		for s=1, #supporter, 5 do
			local name = Supporter_GetName(supporter[s]);
			for r=4,1,-1 do
				local rInvert = 4-r;
				local rIndex,objs = s+r;
				if supporter[rIndex] then
					objs = thisAddOn(addon,supporter[rIndex]);
				end
				if objs then
					local res = {name};
					local width,size = "normal",nil;
					if r==1 then -- translations
						tinsert(res,Supporter_GetLanguages(objs));
					elseif r==2 then -- donations
						tinsert(res,Supporter_GetDonationPlatforms(objs));
					elseif r==3 then -- other support types
						tinsert(res,Supporter_GetSupport(objs));
					else -- specials
						tAppendAll(res,objs);
						width="full";
						size="medium";
					end
					local entry = CopyTable(descLargeTemplate);
					entry.order = rInvert*1000+sIndex[r];
					entry.name = table.concat(res,"|n");
					entry.width = width;
					if size then
						entry.fontSize = size;
					end
					credit.args["supporter-"..s.."-"..r] = entry;
					sIndex[r] = sIndex[r] + 1;
				end
				if objs and not credit.args["header-"..r] then
					credit.args["header-"..r] = CopyTable(descLargeTemplate);
					credit.args["header-"..r].order = rInvert*1000;
					credit.args["header-"..r].name = "|n"..C("cyan",L[labels[r] or "ThxSpecial"]);
					hasNoEntries = false
				end
			end
		end
		return hasNoEntries;
	end

	-- Add custom credit
	---@param addon string
	---@param creditSection? table
	---@param style? string
	function lib.AddCredit(addon,creditSection,style)
		local credit = CopyTable(creditTemplate);
		credit.name = addon.." / "..L["Credit"]
		--credit.args = {};
		--[[
		if tonumber(order) then
			credit.order = order;
		end
		--]]

		-- add supporter
		local isEmpty = Supporter_AddStyle(addon,credit);

		if isEmpty then
			return;
		end

		-- register
		if type(creditSection)=="table" then
			Mixin(creditSection,credit.args);
		else
			-- add own sub option table
			LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(addon.."/Credit", credit);
			LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addon.."/Credit", "Credit", addon);
		end
	end
end

--== Blizz option panel functions ==--
do
	local function CalculateOffset(panel)
		local pType = type(panel);
		local buttonCount = #InterfaceOptionsFrameAddOns.buttons;
		--local buttonHeight = InterfaceOptionsFrameAddOns.buttons[1]:GetHeight();

		local elementsBefore = 0;
		for i, element in next, INTERFACEOPTIONS_ADDONCATEGORIES do
			if not element.hidden then
				if (pType=="string" and element.name==panel) or (pType=="table" and element==panel) then
					break;
				end
				elementsBefore = elementsBefore + 1;
			end
		end

		if elementsBefore>buttonCount then
			ns:print(elementsBefore,buttonCount);
			return elementsBefore + 1 - buttonCount;
		end

		return 0;
	end

	--[[local function BlizzOptions_ExpandOnShowHook(self)
		local p = false;
		for i, button in next, InterfaceOptionsFrameAddOns.buttons do
			if button.element then
				if button.element.name == self.name then
					p = button
				end
			end
		end
		if p and p.element.collapsed then
			OptionsListButtonToggle_OnClick(p.toggle)
			local offset = CalculateOffset();
			if offset>0 then
				-- SetOffset(offset)
			end
		end
	end]]

	---@param opts table
	function lib.BlizzOptions_ExpandOnShow(opts)
		if opts.hasExpandOnShowHook then return end
		--opts:HookScript("OnShow", BlizzOptions_ExpandOnShowHook);
		opts.hasExpandOnShowHook = true;
	end

	---@param panel table
	function lib.InterfaceOptionsFrame_OpenToCategory(panel)
		Settings.OpenToCategory(panel)
	end
end

function lib.C_Table_Search(find)
	local n,c="C_Table_Search",0;
	lib.debug(n,"results for",find)
	for gname, gvalue in pairs(_G)do
		if tostring(gname):match("^C_") and type(gvalue)=="table" then
			for fname in pairs(_G[gname]) do
				if fname:match(find) then
					c=c+1;
					lib.debug(n,c,gname,fname)
				end
			end
		end
	end
end

--== Compatibility between clients ==--
do
	lib.deprecated = {
		C_QuestLog = {
			GetInfo = function(questLogIndex)
				if C_QuestLog and C_QuestLog.GetInfo then
					return C_QuestLog.GetInfo(questLogIndex)
				end
				local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory, isHidden, isScaling  = GetQuestLogTitle(questLogIndex);
				if type(suggestedGroup)=="string" then
					suggestedGroup = tonumber(suggestedGroup) or 0; -- problem on bc classic client?
				end
				return {
					frequency = frequency,
					hasLocalPOI = hasLocalPOI,
					isAutoComplete = isComplete,
					isCollapsed = isCollapsed,
					isHeader = isHeader,
					isHidden = isHidden,
					isOnMap = isOnMap,
					isScaling = isScaling,
					isStory = isStory,
					isTask = isTask,
					level = level,
					questID = questID,
					questLogIndex = questLogIndex,
					startEvent = startEvent,
					suggestedGroup = suggestedGroup,
					title = title,
					-- dummies. not present in old function
					campaignID = 0,
					difficultyLevel = 0,
					isBounty = false,
					isLegendarySort = false,
					overridesSortOrder = false,
					readyForTranslation = false,
					useMinimapHeader = false,
				};
			end,
			GetQuestTagInfo = function(questID)
				if C_QuestLog and C_QuestLog.GetQuestTagInfo then
					return C_QuestLog.GetQuestTagInfo(questID)
				end
				-- 10/22/2023: Not present in Classic and Classic Era
				local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, displayTimeLeft = GetQuestTagInfo(questID);
				return {
					tagID = tagID,
					tagName = tagName,
					worldQuestType = worldQuestType,
					quality = rarity,
					isElite = isElite,
					tradeskillLineID = tradeskillLineIndex,
					displayExpiration = displayTimeLeft
				};
			end,
		},

		C_GossipInfo = {
			GetFriendshipReputation = function(friendshipFactionID)
				if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
					return C_GossipInfo.GetFriendshipReputation(friendshipFactionID);
				end
				local info = {reverseColor=false,overrideColor=0};
				-- friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold
				info.friendshipFactionID, info.standing, info.maxRep, info.name, info.text, info.texture, info.reaction, info.reactionThreshold, info.nextThreshold = GetFriendshipReputation(friendshipFactionID);
				return info;
			end
		},

		C_Reputation = {
			_GetFactionData = function(i,fSuffix)
				if C_Reputation and C_Reputation.GetFactionInfo then
					local info = C_Reputation.GetFactionInfo(i)
					if type(info)=="table" then
						return info;
					end
				end
				local fName = "GetFactionInfo"..(fSuffix=="ID" and "ByID" or "");
				if not _G[fName] then
					return;
				end
				local info = {};
				info.name,info.description,info.reaction,info.currentReactionThreshold,info.nextReactionThreshold,info.currentStanding,info.atWarWith,
				info.canToggleAtWar,info.isHeader,info.isCollapsed,info.hasRep,info.isWatched,info.isChild,
				info.factionID,info.hasBonusRepGain,info.canBeLFGBonus = _G["GetFactionInfo"..(fSuffix=="ID" and "ByID" or "")](i)
				if not info.name then
					return;
				end
				return info
			end,
			GetFactionDataByIndex = function(index) -- new in 11.0
				if C_Reputation and C_Reputation.GetFactionDataByIndex then
					return C_Reputation.GetFactionDataByIndex(index)
				end
				return lib.deprecated.C_Reputation._GetFactionData(index,"Index")
			end,
			GetFactionDataByID = function(id) -- new in 11.0
				if C_Reputation and C_Reputation.GetFactionDataByID then
					return C_Reputation.GetFactionDataByID(id)
				end
				return lib.deprecated.C_Reputation._GetFactionData(id,"ID");
			end,
			GetNumFactions = function() -- new in 11.0
				if C_Reputation and C_Reputation.GetNumFactions then
					return C_Reputation.GetNumFactions()
				end
				return GetNumFactions()
			end,
			GetWatchedFactionData = function(...) -- new in 11.0
				if C_Reputation and C_Reputation.GetWatchedFactionData then
					return C_Reputation.GetWatchedFactionData(...)
				end
				local _, _, _, _, _, factionID = GetWatchedFactionInfo()
				return lib.deprecated.C_Reputation.GetFactionDataByID(factionID);
			end,
			ExpandFactionHeader = function(...) -- new in 11.0
				if C_Reputation and C_Reputation.ExpandFactionHeader then
					return C_Reputation.ExpandFactionHeader(...)
				end
				ExpandFactionHeader(...)
			end,
			CollapseFactionHeader = function(...) -- new in 11.0
				if C_Reputation and C_Reputation.CollapseFactionHeader then
					return C_Reputation.CollapseFactionHeader(...)
				end
				CollapseFactionHeader(...)
			end
		},

		C_Spell = {
			GetSpellInfo = function(...)
				if C_Spell and C_Spell.GetSpellInfo then
					return C_Spell.GetSpellInfo(...)
				elseif C_SpellBook and C_SpellBook.GetSpellInfo then
					return C_SpellBook.GetSpellInfo(...)
				elseif GetSpellInfo then
					-- old: name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon
					-- rank is missing
					local info = {}
					info.name, info.rank, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID, info.originalIcon = GetSpellInfo(...)
					return info;
				end
			end,
			GetSpellCooldown = function(...)
				if C_Spell and C_Spell.GetSpellCooldown then
					return C_Spell.GetSpellCooldown(...)
				end
				return GetSpellCooldown(...)
			end,
			GetSpellLink = function(...)
				if C_Spell and C_Spell.GetSpellLink then
					return C_Spell.GetSpellLink(...)
				end
				return GetSpellLink(...)
			end,
			GetSpellIcon = function(...)
				if C_Container and C_Spell.GetSpellIcon then
					return C_Spell.GetSpellIcon(...)
				end
				return GetSpellIcon(...)
			end

		},

		C_Item = {
			GetItemStats = function(...)
				if C_Container and C_Item.GetItemStats then

					return C_Item.GetItemStats(...)
				end
				return GetItemStats(...)
			end,
			GetItemSpell = function(...)
				if C_Item and C_Item.GetItemSpell then
					return C_Item.GetItemSpell(...)
				end
				return GetItemSpell(...)
			end,
			GetItemInfoInstant = function(...)
				if C_Item and C_Item.GetItemInfoInstant then
					return C_Item.GetItemInfoInstant(...)
				end
				return GetItemInfoInstant(...)
			end,
			GetItemCooldown = function(...)
				if C_Item and C_Item.GetItemCooldown then
					return C_Item.GetItemCooldown(...)
				end
				return GetItemCooldown(...)
			end,
			GetItemIconByID = function(...)
				if C_Item and C_Item.GetItemIconByID then
					return C_Item.GetItemIconByID(...)
				end
				return GetItemIcon(...);
			end,
			GetItemIcon = function(...)
				lib.debug("Warning","GetItemIcon must be replaced by GetItemIconByID",debugstack())
				return lib.deprecated.C_Spell.GetItemIconByID(...)
			end
		},

		C_Container = {
			ContainerIDToInventoryID = function(...)
				if C_Container and C_Container.ContainerIDToInventoryID then
					return C_Container.ContainerIDToInventoryID(...)
				end
				return ContainerIDToInventoryID(...)
			end,
			GetContainerItemDurability = function(...)
				if C_Container and C_Container.GetContainerItemDurability then
					return C_Container.GetContainerItemDurability(...)
				end
				return GetContainerItemDurability(...)
			end
		},

		global = {
			UnitInVehicle = function() -- speed
				if UnitInVehicle then
					return UnitInVehicle()
				end
				return false;
			end,
		},

		C_TransmogSets = {
			GetFullBaseSetsCounts = function(...)
				if C_TransmogSets.GetFullBaseSetsCounts then
					return C_TransmogSets.GetFullBaseSetsCounts(...)
				end
				return C_TransmogSets.GetBaseSetsCounts(...)
			end,
		},

		C_Minimap = {
			SetTracking = function(...)
				if C_Minimap and C_Minimap.SetTracking then
					return C_Minimap.SetTracking(...)
				end
				SetTracking(...)
			end

		},

		C_AddOns = {
			GetAddOnMemoryUsage = function(...)
				if C_AddOns and C_AddOns.GetAddOnMemoryUsage then
					return C_AddOns.GetAddOnMemoryUsage(...)
				end
				return GetAddOnMemoryUsage(...)
			end
		},

		C_CurrencyInfo = {
			GetCoinTextureString = function(...)
				if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
					return C_CurrencyInfo.GetCoinTextureString(...)
				end
				return GetCoinTextureString(...)
			end
		}
	}

	local dummyF = function() end
	local dummyMT = {}
	function dummyMT.__index(t,k)
		lib.debug("deprecated-api missing table function",t.__parent,k,debugstack());
		rawset(t,k,dummyF);
		return dummyF;
	end

	setmetatable(lib.deprecated,{
		__index = function(t,k)
			lib.debug("deprecated-api missing table",k)
			local d = setmetatable({__parent=k},dummyMT);
			rawset(t,k,d);
			return d;
		end
	});

	for k,v in pairs(lib.deprecated)do
		if type(v)=="table" then
			v.__parent = k;
			setmetatable(v,dummyMT)
		end
	end

	if WOW_PROJECT_ID~=WOW_PROJECT_MAINLINE then
		local current = WOW_PROJECT_ID==WOW_PROJECT_CLASSIC and "era" or "classic"
		for name1, funcs in pairs(lib.deprecated) do
			if type(funcs)=="function" then
				if _G[name1] then
					lib.debug("deprecated-api ("..current..")",name1);
				end
			else
				for name2 in pairs(funcs) do
					if _G[name1] and type(_G[name1][name2])=="function" then
						lib.debug("deprecated-api ("..current..")",name1,name2);
					end
				end
			end
		end
	end
end

--== MapPin or TomTom ==--
do
	function lib.AddWaypoint(mapId, x,y, label, useTomTom, addon)
		local TomTom = _G["TomTom"];
		if TomTom and TomTom.AddWaypoint and useTomTom then
			TomTom:AddWaypoint(mapId,x/100,y/100,{
				title = label,
				from = addon,
				persistent = nil,
				minimap = true,
				world = true
			});
			-- Thanks @ fuba82@github for reminding me. i've forgot to add this function content. :-)
		else -- as option and fallback
			_G["DEFAULT_CHAT_FRAME"]:AddMessage("\124cffffff00\124Hworldmap:"..mapId..":"..(x*100)..":"..(y*100).."\124h[\124A:Waypoint-MapPin-ChatIcon:13:13:0:0\124a "..label.."-Kartenmarkierung]\124h\124r");
		end
	end
end

