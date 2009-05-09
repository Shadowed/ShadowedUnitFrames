-- Thanks to haste for the original tagging code, which I then mostly ripped apart and stole!
local Tags = ShadowUF:NewModule("Tags")
local eventlessUnits, events, tagPool, functionPool, fastTagUpdates, temp = {}, {}, {}, {}, {}, {}
local frame
local L = ShadowUFLocals

function Tags:OnInitialize()
	self:LoadTags()
end

-- Event management
local function RegisterEvent(fontString, event)
	events[event] = events[event] or {}
	table.insert(events[event], fontString)
	
	frame:RegisterEvent(event)
end

-- Register the associated events with all the tags
local function RegisterTagEvents(fontString, tags)
	-- Strip parantheses and anything inside them
	tags = string.gsub(tags, "%b()", "")
	for tag in string.gmatch(tags, "%[(.-)%]") do
		local tagEvents = Tags.defaultEvents[tag] or ShadowUF.tagEvents[tag]
		if( tagEvents ) then
			for event in string.gmatch(tagEvents, "%S+") do
				RegisterEvent(fontString, event)
				
				-- If it's for the player, and the tag uses a power event, flag it as needing to be OnUpdate monitored
				if( fontString.parent.unit == "player" and Tags.powerEvents[event] ) then
					fastTagUpdates[fontString] = true
				end
			end
		end
	end
end

-- Unregister all events for this tag
local function UnregisterTagEvents(fontString)
	for event, fsList in pairs(events) do
		for i=#(fsList), 1, -1 do
			if( fsList[i] == fontString ) then
				table.remove(fsList, i)
				
				if( #(fsList) == 0 ) then
					frame:UnregisterEvent(event)
				end
			end
		end
	end
end

-- Tag needs an update!
local timeElapsed = 0
frame = CreateFrame("Frame")
frame:Hide()

frame:SetScript("OnUpdate", function(self, elapsed)
	timeElapsed = timeElapsed + elapsed
	
	if( timeElapsed >= 0.50 ) then
		for _, text in pairs(eventlessUnits) do
			if( text.parent:IsVisible() and UnitExists(text.parent.unit) ) then
				text:UpdateTags()
			end
		end
		
		timeElapsed = 0
	end
end)

frame:SetScript("OnEvent", function(self, event, unit)
	if( not events[event] ) then
		return
	end
	
	for _, fontString in pairs(events[event]) do
		if( Tags.unitlessEvents[event] or ( not Tags.unitlessEvents[event] and fontString.parent.unit == unit ) ) then
			fontString:UpdateTags()
		end
	end	
end)

-- Tag updating for power to make it smooth
local fastFrame = CreateFrame("Frame")
fastFrame:SetScript("OnUpdate", function(self, elapsed)
	for fontString in pairs(fastTagUpdates) do
		fontString:UpdateTags()
	end
end)

function Tags:Register(parent, fontString, tags)
	-- Unregister the font string first if we did register it already
	if( fontString.UpdateTags ) then
	--	self:Unregister(fontString)
	end
	
	fontString.parent = parent
	
	fastTagUpdates[fontString] = nil
	
	local updateFunc = tagPool[tags]
	if( not updateFunc ) then
		-- Using .- prevents supporting tags such as [foo ([)]. Supporting that and having a single pattern
		-- here is a pain however (Or, so haste says!)
		local formattedText = string.gsub(string.gsub(tags, "%%", "%%%%"), "[[].-[]]", "%%s")
		local args = {}
		
		for tag in string.gmatch(tags, "%[(.-)%]") do
			-- If they enter a tag such as "foo(|)" then we won't find a regular tag, meaning will go into our function pool code
			local cachedFunc = functionPool[tag] or ShadowUF.tags[tag]
			if( not cachedFunc ) then
				local pre, tagKey, ap = string.match(tag, "(%b())([%w]+)(%b())")
				if( not pre ) then pre, tagKey = string.match(tag, "(%b())([%w]+)") end
				if( not pre ) then tagKey, ap = string.match(tag, "([%w]+)(%b())") end
				
				local tag = tagKey and ShadowUF.tags[tagKey]
				if( tag ) then
					pre = pre and string.sub(pre, 2, -2) or ""
					ap = ap and string.sub(ap, 2, -2) or ""

					cachedFunc = function(unit)
						local str = tag(unit)
						if( str ) then
							return pre .. str .. ap
						end
					end
					
					functionPool[tag] = cachedFunc
				end
			end			
			
			if( cachedFunc ) then
				table.insert(args, cachedFunc)
			else
				return error(string.format(L["Invalid tag used %s."], tag), 3)
			end
		end
		
		-- Create our update function now
		updateFunc = function(fontString)
			local unit = fontString.parent.unit
			for id, func in pairs(args) do
				temp[id] = func(unit) or ""
			end
			
			fontString:SetFormattedText(formattedText, unpack(temp))
		end

		tagPool[tags] = updateFunc
	end
	
	fontString.UpdateTags = updateFunc
	
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
	UnregisterTagEvents(fontString)
		
	for i=#(eventlessUnits), 1, -1 do
		if( eventlessUnits[i] == fontString ) then
			table.remove(eventlessUnits, i)
		end
	end
	
	if( #(eventlessUnits) == 0 ) then
		frame:Hide()
	end
	
	fastTagUpdates[fontString] = nil
	fontString.UpdateTags = nil
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

function ShadowUF:FormatLargeNumber(number)
	if( number < 9999 ) then
		return number
	elseif( number < 999999 ) then
		return string.format("%.1fk", number / 1000)
	end
	
	return string.format("%.2fm", number / 1000000)
end

function Tags:LoadTags()
	self.defaultTags = {
		["class"]       = [[function(unit) return UnitClass(unit) end]],
		["creature"]    = [[function(unit) return UnitCreatureFamily(unit) or UnitCreatureType(unit) end]],
		["curhp"]       = [[function(unit) return ShadowUF:FormatLargeNumber(UnitHealth(unit)) end]],
		["curpp"]       = [[function(unit) return ShadowUF:FormatLargeNumber(UnitPower(unit)) end]],
		["curmaxhp"] = [[function(unit)
			local dead = ShadowUF.tags.dead(unit)
			if( dead ) then
				return dead
			end
			
			return string.format("%s/%s", ShadowUF.tags.curhp(unit), ShadowUF.tags.maxhp(unit))
		end]],
		["curmaxpp"] = [[function(unit)
			local dead = ShadowUF.tags.dead(unit)
			if( dead ) then
				return string.format("0/%s", ShadowUF.tags.maxpp(unit))
			end
			
			return string.format("%s/%s", ShadowUF.tags.curpp(unit), ShadowUF.tags.maxpp(unit))
		end]],
		["dead"]        = [[function(unit) return UnitIsDead(unit) and ShadowUFLocals["Dead"] or UnitIsGhost(unit) and ShadowUFLocals["Ghost"] end]],
		["difficulty"]  = [[function(unit) if UnitCanAttack("player", unit) then local l = UnitLevel(unit); return ShadowUF:Hex(GetDifficultyColor((l > 0) and l or 99)) end end]],
		["faction"]     = [[function(unit) return UnitFactionGroup(unit) end]],
		["leader"]      = [[function(unit) return UnitIsPartyLeader(unit) and ShadowUFLocals["(L)"] end]],
		["leaderlong"]  = [[function(unit) return UnitIsPartyLeader(unit) and ShadowUFLocals["(Leader)"] end]],
		["level"]       = [[function(unit) local l = UnitLevel(unit) return (l > 0) and l or ShadowUFLocals["??"] end]],
		["maxhp"]       = [[function(unit) return ShadowUF:FormatLargeNumber(UnitHealthMax(unit)) end]],
		["maxpp"]       = [[function(unit) return ShadowUF:FormatLargeNumber(UnitPowerMax(unit)) end]],
		["missinghp"]   = [[function(unit) return UnitHealthMax(unit) - UnitHealth(unit) end]],
		["missingpp"]   = [[function(unit) return UnitPowerMax(unit) - UnitPower(unit) end]],
		["name"]        = [[function(unit) return UnitName(unit) end]],
		["offline"]     = [[function(unit) return  (not UnitIsConnected(unit) and ShadowUFLocals["Offline"]) end]],
		["perhp"]       = [[function(unit) local m = UnitHealthMax(unit); return m == 0 and 0 or math.floor(UnitHealth(unit)/m*100+0.5) end]],
		["perpp"]       = [[function(unit) local m = UnitPowerMax(unit); return m == 0 and 0 or math.floor(UnitPower(unit)/m*100+0.5) end]],
		["plus"]        = [[function(unit) local c = UnitClassification(unit); return (c == "elite" or c == "rareelite") and "+" end]],
		["pvp"]         = [[function(unit) return UnitIsPVP(unit) and ShadowUFLocals["PvP"] end]],
		["race"]        = [[function(unit) return UnitRace(unit) end]],
		["raidcolor"]   = [[function(unit) if( not UnitIsPlayer(unit) ) then return end local _, x = UnitClass(unit); return x and ShadowUF:Hex(RAID_CLASS_COLORS[x]) end]],
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
		["curmaxhp"]			= "UNIT_HEALTH UNIT_MAXHEALTH",
		["curpp"]               = "UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER UNIT_DISPLAYPOWER",
		["curmaxpp"]			= "UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER UNIT_DISPLAYPOWER UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER",
		["dead"]                = "UNIT_HEALTH",
		["leader"]              = "PARTY_LEADER_CHANGED",
		["leaderlong"]          = "PARTY_LEADER_CHANGED",
		["level"]               = "UNIT_LEVEL PLAYER_LEVEL_UP",
		["maxhp"]               = "UNIT_MAXHEALTH",
		["maxpp"]               = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER",
		["missinghp"]           = "UNIT_HEALTH UNIT_MAXHEALTH",
		["missingpp"]           = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_MAXRUNIC_POWER UNIT_RUNIC_POWER",
		["name"]                = "UNIT_NAME_UPDATE",
		["coloredname"]			= "UNIT_NAME_UPDATE",
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
	
	self.powerEvents = {
		["UNIT_ENERGY"] = true,
		["UNIT_FOCUS"] = true,
		["UNIT_MANA"] = true,
		["UNIT_RAGE"] = true,
		["UNIT_RUNIC_POWER"] = true,
	}
	
	-- Events that should call every font string, and not bother checking for unit
	self.unitlessEvents = {
		["PLAYER_TARGET_CHANGED"] = true,
		["PLAYER_FOCUS_CHANGED"] = true,
		["PLAYER_LEVEL_UP"] = true,
	}
end
