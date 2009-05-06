-- Thanks to haste for the original tagging code, which I then mostly ripped apart and stole!
local Tags = ShadowUF:NewModule("Tags")
local fontStrings, eventlessUnits, events, tagPool, functionPool, temp = {}, {}, {}, {}, {}, {}
local frame
local L = ShadowUFLocals

function Tags:OnInitialize()
	self:LoadTags()
	
	-- Updates for frames without unit events, such as totot
	local timeElapsed = 0
	frame = CreateFrame("Frame")
	frame:Hide()

	frame:SetScript("OnUpdate", function(self, elapsed)
		timeElapsed = timeElapsed + elapsed
		
		if( timeElapsed >= 0.50 ) then
			for _, text in pairs(eventlessUnits) do
				if( text.parent:IsVisible() and UnitExists(text.parent.unit) ) then
					Tags:Update(text)
				end
			end
		end
	end)
end

-- Event management
local function RegisterEvent(fontString, event)
	events[event] = events[event] or {}
	table.insert(events[event], fontString)

	frame:RegisterEvent(event)
end

local function UnregisterEvent(fontString, event)
	if( not events[event] ) then
		return
	end
	
	for i=#(events[event]), 1, -1 do
		if( events[event][i] == fontString ) then
			table.remove(events[event], i)
		end
	end
	
	if( #(events[event]) == 0 ) then
		frame:UnregisterEvent(event)
	end
end

-- Register he associated events with all the tags
local function RegisterTagEvents(fontString, tags)
	-- Strip parantheses and anything inside them
	tags = string.gsub(tags, "%b()", "")
	for tag in string.gmatch(tags, "%[(.-)%]") do
		local tagEvents = Tags.defaultEvents[tag] or ShadowUF.tagEvents[tag]
		if( tagEvents ) then
			for event in string.gmatch(tagEvents, "%S+") do
				RegisterEvent(fontString, event)
			end
		end
	end
end

-- Tag needs an update!
frame:SetScript("OnEvent", function(event, ...)
	if( not events[event] ) then
		return
	end
	
	for _, fontString in pairs(fontStrings) do
		if( ( self.unitlessEvents[event] or ( not self.unitlessEvents[event] and fontString.parent.unit == unit ) ) and fontString:IsVisible() ) then
			self:Update(fontString)
		end
	end	
end

function Tags:Register(parent, fontString, tags)
	-- Unregister the font string first if we did register it already
	for _, fs in pairs(fontStrings) do
		if( fontString == fs ) then
			self:Unregister(fs)
		end
	end
	
	fontString.parent = parent
	
	local updateFunc = tagPool[tags]
	if( not updateFunc ) then
		-- Using .- prevents supporting tags such as [foo ([)]. Supporting that and having a single pattern
		-- here is a pain however (Or, so haste says!)
		local formattedText = string.gsub(string.gsub(tags, "%%", "%%%%"), "[[].-[]]", "%%s")
		local args = {}
		
		for parsedKey in string.gmatch(tags, "%[(.-)%]") do
			-- If they enter a tag such as "foo(|)" then we won't find a regular tag, meaning will go into our function pool code
			local cachedFunc = funtionPool[parsedKey] or ShadowUF.tags[parsedKey]
			if( not cachedFunc ) then
				-- ...
				local pre, tagKey, ap = string.match(tag, "(%b())([%w]+)(%b())")
				if( not pre ) then pre, tagKey = string.match(tag, "(%b())([%w]+)") end
				if( not pre ) then tagKey, ap = string.match(tag, "([%w]+)(%b())") end
				
				local tag = ShadowUF.tags[tagKey]
				if( tag ) then
					pre = pre and string.sub(pre, 2, -2) or ""
					ap = ap and string.sub(ap, 2, -2) or ""

					cachedFunc = function(unit)
						local str = tag(unit)
						if( str ) then
							return pre .. str .. ap
						end
					end
					
					functionPool[parsedKey] = cachedFunc
				end
			end
			
			if( cachedFunc ) then
				table.insert(args, cachedFunc)
			else
				return error(string.format(L["Invalid tag used %s."], parsedKey), 3)
			end
		end
		
		-- Create our update function now
		updateFunc = function(fontString)
			local unit = fontString.parent.unit
			
			for id, func in pairs(args) do
				temp[id] = func(unit) or ""
			end
			
			fontString:SetFormattedText(formattedtext, unpack(temp))
		end

		tagPool[tags] = func
	end

	local unit = parent.unit
	if( unit and string.match(unit, "%w+target") ) then
		table.insert(eventlessUnits, fontString)
		
		frame:Show()
	else
		RegisterTagEvents(fontString, tags)
		
		if( unit == "focus" ) then
			RegisterEvent(fontString, "PLAYER_FOCUS_CHANGED")
		elseif( unit == "target" ) then
			RegisterEvent(fontString, "PLAYER_TARGET_CHANGED")
		elseif( unit == "mouseover" ) then
			RegisterEvent(fontString, "UPDATE_MOUSEOVER_UNIT")
		end
	end
end

function Tags:Unregister(fontString)
	UnregisterEvents(fontString)
	
	for i=#(eventlessUnits), 1, -1 do
		if( eventlessUnits[i] == fontString ) then
			table.remove(eventlessUnits, i)
		end
	end
end

-- Update the font string
function Tags:Update(fontString)
	tagPool[fontString](fontString)
end

-- Helper functions for tags, the reason I store it in ShadowUF is it's easier to type ShadowUF
-- than ShadowUF.modules.Tags, and simpler for users who want to implement it.
function ShadowUF:Hex(r, g, b)
	if( type(r) == "table" ) then
		if( r.r ) then
			r, g, b = r.r, r.g, r.b
		else
			r, g, b = unpack(r)
		end
	end

	return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function Tags:LoadTags()
	self.defaultTags = {
		["class"]       = [[function(unit) return UnitClass(unit) end]],
		["creature"]    = [[function(unit) return UnitCreatureFamily(unit) or UnitCreatureType(unit) end]],
		["curhp"]       = "UnitHealth",
		["curpp"]       = "UnitPower",
		["dead"]        = [[function(unit) return UnitIsDead(unit) and ShadowUFLocals["Dead"] or UnitIsGhost(unit) and ShadowUFLocals["Ghost"] end]],
		["difficulty"]  = [[function(unit) if UnitCanAttack("player", unit) then local l = UnitLevel(unit); return ShadowUF:Hex(GetDifficultyColor((l > 0) and l or 99)) end end]],
		["faction"]     = [[function(unit) return UnitFactionGroup(unit) end]],
		["leader"]      = [[function(unit) return UnitIsPartyLeader(unit) and ShadowUFLocals["(L)"] end]],
		["leaderlong"]  = [[function(unit) return UnitIsPartyLeader(unit) and ShadowUFLocals["(Leader)"] end]],
		["level"]       = [[function(unit) local l = UnitLevel(unit) return (l > 0) and l or ["??"] end]],
		["maxhp"]       = "UnitHealthMax",
		["maxpp"]       = "UnitPowerMax",
		["missinghp"]   = [[function(unit) return UnitHealthMax(unit) - UnitHealth(unit) end]],
		["missingpp"]   = [[function(unit) return UnitPowerMax(unit) - UnitPower(unit) end]],
		["name"]        = [[function(unit) return UnitName(unit) end]],
		["offline"]     = [[function(unit) return  (not UnitIsConnected(unit) and ShadowUFLocals["Offline"]) end]],
		["perhp"]       = [[function(unit) local m = UnitHealthMax(unit); return m == 0 and 0 or math.floor(UnitHealth(unit)/m*100+0.5) end]],
		["perpp"]       = [[function(unit) local m = UnitPowerMax(unit); return m == 0 and 0 or math.floor(UnitPower(unit)/m*100+0.5) end]],
		["plus"]        = [[function(unit) local c = UnitClassification(unit); return (c == "elite" or c == "rareelite") and "+" end]],
		["pvp"]         = [[function(unit) return UnitIsPVP(unit) and ShadowUFLocals["PvP"] end]],
		["race"]        = [[function(unit) return UnitRace(unit) end]],
		["raidcolor"]   = [[function(unit) local _, x = UnitClass(unit); return x and ShadowUF:Hex(RAID_CLASS_COLORS[x]) end]],
		["rare"]        = [[function(unit) local c = UnitClassification(unit); return (c == "rare" or c == "rareelite") and ShadowUFLocals["Rare"] end]],
		["resting"]     = [[function(unit) return u == "player" and IsResting() and ShadowUFLocals["zzz"] end]],
		["sex"]         = [[function(unit) local s = UnitSex(unit) return s == 2 and ShadowUFLocals["Male"] or s == 3 and ShadowUFLocals["Female"] end]],
		["smartclass"]  = [[function(unit) return UnitIsPlayer(unit) and ShadowUF.tags.class(unit) or ShadowUF.tags.creature(unit) end]],
		["status"]      = [[function(unit) return UnitIsDead(unit) and ShadowUFLocals["Dead"] or UnitIsGhost(unit) and ShadowUFLocals["Ghost"] or not UnitIsConnected(unit) and ShadowUFLocals["Offline"] or ShadowUF.tags.resting(unit) end]],
		["threat"]      = [[function(unit) local s = UnitThreatSituation(unit) return s == 1 and "++" or s == 2 and "--" or s == 3 and ShadowUFLocals[""] end]],
		["threatcolor"] = [[function(unit) return ShadowUF:Hex(GetThreatStatusColor(UnitThreatSituation(unit))) end]],
		["cpoints"]     = [[function(unit) local cp = GetComboPoints(u, "target") return (cp > 0) and cp end]],
		["smartlevel"] = [[function(unit)
			local c = UnitClassification(unit)
			if(c == "worldboss") then
				return "Boss"
			else
				local plus = ShadowUF.tags.plus(unit)
				local level = ShadowUF.tags.level(unit)
				if( plus ) then
					return level .. plus
				else
					return level
				end
			end
		end]],
		["classification"] = [[function(unit)
			local c = UnitClassification(unit)
			return c == "rare" and ShadowUFLocals["Rare"] or c == "eliterare" and ShadowUFLocals["Rare Elite"] or c == "elite" and ShadowUFLocals["Elite"] or c == "worldboss" and ShadowUFLocals["Boss"]
		end]],
		["shortclassification"] = [[function(unit)
			local c = UnitClassification(unit)
			return c == "rare" and "R" or c == "eliterare" and "R+" or c == "elite" and "+" or c == "worldboss" and "B"
		end]],
	}

	-- Default tag events
	self.defaultEvents = {
		["curhp"]               = "UNIT_HEALTH",
		["curpp"]               = "UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER",
		["dead"]                = "UNIT_HEALTH",
		["leader"]              = "PARTY_LEADER_CHANGED",
		["leaderlong"]          = "PARTY_LEADER_CHANGED",
		["level"]               = "UNIT_LEVEL PLAYER_LEVEL_UP",
		["maxhp"]               = "UNIT_MAXHEALTH",
		["maxpp"]               = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER",
		["missinghp"]           = "UNIT_HEALTH UNIT_MAXHEALTH",
		["missingpp"]           = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_MAXRUNIC_POWER UNIT_RUNIC_POWER",
		["name"]                = "UNIT_NAME_UPDATE",
		["offline"]             = "UNIT_HEALTH",
		["perhp"]               = "UNIT_HEALTH UNIT_MAXHEALTH",
		["perpp"]               = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_MAXRUNIC_POWER UNIT_RUNIC_POWER",
		["pvp"]                 = "UNIT_FACTION",
		["resting"]             = "PLAYER_UPDATE_RESTING",
		["status"]              = "UNIT_HEALTH PLAYER_UPDATE_RESTING",
		["smartlevel"]          = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED",
		["threat"]              = "UNIT_THREAT_SITUATION_UPDATE",
		["threatcolor"]         = "UNIT_THREAT_SITUATION_UPDATE",
		["cpoints"]             = "UNIT_COMBO_POINTS UNIT_TARGET",
		["rare"]                = "UNIT_CLASSIFICATION_CHANGED",
		["classification"]      = "UNIT_CLASSIFICATION_CHANGED",
		["shortclassification"] = "UNIT_CLASSIFICATION_CHANGED",
	}
	
	-- Events that should call every font string, and not bother checking for unit
	self.unitlessEvents = {
		["PLAYER_TARGET_CHANGED"] = true,
		["PLAYER_FOCUS_CHANGED"] = true,
		["PLAYER_LEVEL_UP"] = true,
	}
end
