-- Thanks to haste for the original tagging code, which I then mostly ripped apart and stole!
local Tags = {}
local tagPool, functionPool, temp, regFontStrings = {}, {}, {}, {}
local L = ShadowUFLocals

ShadowUF.Tags = Tags

-- Register the associated events with all the tags
function Tags:RegisterEvents(parent, fontString, tags)
	-- Strip parantheses and anything inside them
	for tag in string.gmatch(tags, "%[(.-)%]") do
		-- The reason the original %b() match won't work, is [( ()group())] (or any sort of tag with ( or )
		-- was breaking the logic and stripping the entire tag, this is a quick fix to stop that.
		local tagKey = select(2, string.match(tag, "(%b())([%w]+)(%b())"))
		if( not tagKey ) then tagKey = select(2, string.match(tag, "(%b())([%w]+)")) end
		if( not tagKey ) then tagKey = string.match(tag, "([%w]+)(%b())") end
		
		tag = tagKey or tag
		
		local tagEvents = Tags.defaultEvents[tag] or ShadowUF.db.profile.tags[tag] and ShadowUF.db.profile.tags[tag].events
		if( tagEvents ) then
			for event in string.gmatch(tagEvents, "%S+") do
				if( Tags.unitlessEvents[event] ) then
					parent:RegisterNormalEvent(event, fontString, "UpdateTags")
				else
					parent:RegisterUnitEvent(event, fontString, "UpdateTags")
				end
				
				-- Check if the unit has a power or health event, if they do we need to flag it as such so the power/health bar will do speedy updating
				if( ShadowUF.db.profile.units[parent.unitType].powerBar.predicted and Tags.powerEvents[event] ) then
					fontString.fastPower = true
				end
				if( ShadowUF.db.profile.units[parent.unitType].healthBar.predicted and Tags.healthEvents[event] ) then
					fontString.fastHealth = true
				end
			end
		end
	end
end

-- This pretty much means a tag was updated in some way (or deleted) so we have to do a full update to get the new values shown
function Tags:Reload()
	-- Kill cached functions, ugly I know but it ensures its fully updated with the new data
	for tag in pairs(functionPool) do
		functionPool[tag] = nil
	end
	for tag in pairs(ShadowUF.tagFunc) do
		ShadowUF.tagFunc[tag] = nil
	end
	for tag in pairs(tagPool) do
		tagPool[tag] = nil
	end
	
	-- Now update frames
	for fontString, tags in pairs(regFontStrings) do
		self:Register(fontString.parent, fontString, tags)
		fontString:UpdateTags()
	end
end

-- Register a font string with the tag system
function Tags:Register(parent, fontString, tags)
	-- Unregister the font string first if we did register it already
	if( fontString.UpdateTags ) then
		self:Unregister(fontString)
	end
	
	fontString.parent = parent
	regFontStrings[fontString] = tags
		
	local updateFunc = tagPool[tags]
	if( not updateFunc ) then
		-- Using .- prevents supporting tags such as [foo ([)]. Supporting that and having a single pattern
		local formattedText = string.gsub(string.gsub(tags, "%%", "%%%%"), "[[].-[]]", "%%s")
		local args = {}
		
		for tag in string.gmatch(tags, "%[(.-)%]") do
			-- If they enter a tag such as "foo(|)" then we won't find a regular tag, meaning will go into our function pool code
			local cachedFunc = functionPool[tag] or ShadowUF.tagFunc[tag]
			if( not cachedFunc ) then
				local hasPre, hasAp = true, true
				local tagKey = select(2, string.match(tag, "(%b())([%w]+)(%b())"))
				if( not tagKey ) then hasPre, hasAp = true, false tagKey = select(2, string.match(tag, "(%b())([%w]+)")) end
				if( not tagKey ) then hasPre, hasAp = false, true tagKey = string.match(tag, "([%w]+)(%b())") end
				
				local tagFunc = tagKey and ShadowUF.tagFunc[tagKey]
				if( tagFunc ) then
					local startOff, endOff = string.find(tag, tagKey)
					local pre = hasPre and string.sub(tag, 2, startOff - 2)
					local ap = hasAp and string.sub(tag, endOff + 2, -2)
					
					if( pre and ap ) then
						cachedFunc = function(unit, unitOwner)
							local str = tagFunc(unit, unitOwner)
							if( str ) then return pre .. str .. ap end
						end
					elseif( pre ) then
						cachedFunc = function(unit, unitOwner)
							local str = tagFunc(unit, unitOwner)
							if( str ) then return pre .. str end
						end
					elseif( ap ) then
						cachedFunc = function(unit, unitOwner)
							local str = tagFunc(unit, unitOwner)
							if( str ) then return str .. ap end
						end
					end
					
					functionPool[tag] = cachedFunc
				end
			end
			
			-- It's an invalid tag, simply return the tag itself wrapped in brackets
			if( not cachedFunc ) then
				functionPool[tag] = functionPool[tag] or function() return string.format("[%s]", tag) end
				cachedFunc = functionPool[tag]
			end
			
			table.insert(args, cachedFunc)
		end
		
		-- Create our update function now
		updateFunc = function(fontString)
			for id, func in pairs(args) do
				temp[id] = func(fontString.parent.unit, fontString.parent.unitOwner) or ""
			end
			
			fontString:SetFormattedText(formattedText, unpack(temp))
		end

		tagPool[tags] = updateFunc
	end
	
	-- And give other frames an easy way to force an update
	fontString.UpdateTags = updateFunc

	-- Register any needed event
	self:RegisterEvents(parent, fontString, tags)
end

function Tags:Unregister(fontString)
	regFontStrings[fontString] = nil
		
	-- Kill any tag data
	fontString.parent:UnregisterAll(fontString)
	fontString.fastPower = nil
	fontString.fastHealth = nil
	fontString.UpdateTags = nil
	fontString:SetText("")
end

-- Helper functions for tags, the reason I store it in ShadowUF is it's easier to type ShadowUF than ShadowUF.modules.Tags, and simpler for users who want to implement it.
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
	elseif( number < 99999999 ) then
		return string.format("%.2fm", number / 1000000)
	end
	
	return string.format("%dm", number / 1000000)
end

function ShadowUF:GetClassColor(unit)
	if( not UnitIsPlayer(unit) ) then
		return nil
	end
	
	local class = select(2, UnitClass(unit))
	return class and ShadowUF:Hex(ShadowUF.db.profile.classColors[class])
end

Tags.defaultTags = {
	["afk"] = [[function(unit, unitOwner)
		if( UnitIsAFK(unit) ) then
			return ShadowUFLocals["(AFK)"]
		elseif( UnitIsDND(unit) ) then
			return ShadowUFLocals["(DND)"]
		end
	end]],
	["close"] = [[function(unit, unitOwner) return "|r" end]],
	["smartclass"] = [[function(unit, unitOwner)
		if( not UnitIsPlayer(unit) ) then
			return UnitCreatureFamily(unit)
		end
		
		return UnitClass(unit)
	end]],
	["reactcolor"] = [[function(unit, unitOwner)
		local color
		if( not UnitIsFriend(unit, "player") and UnitPlayerControlled(unit) ) then
			if( UnitCanAttack("player", unit) ) then
				color = ShadowUF.db.profile.healthColors.hostile
			else
				color = ShadowUF.db.profile.healthColors.enemyUnattack
			end
		elseif( UnitReaction(unit, "player") ) then
			local reaction = UnitReaction(unit, "player")
			if( reaction > 4 ) then
				color = ShadowUF.db.profile.healthColors.friendly
			elseif( reaction == 4 ) then
				color = ShadowUF.db.profile.healthColors.neutral
			elseif( reaction < 4 ) then
				color = ShadowUF.db.profile.healthColors.hostile
			end
		end
		
		if( not color ) then
			return nil
		end
		
		return ShadowUF:Hex(color)
	end]],
	["class"] = [[function(unit, unitOwner) if( not UnitIsPlayer(unit) ) then return nil end return UnitClass(unit) end]],
	["classcolor"] = [[function(unit, unitOwner) return ShadowUF:GetClassColor(unit) end]],
	["creature"] = [[function(unit, unitOwner) return UnitCreatureFamily(unit) or UnitCreatureType(unit) end]],
	["curhp"] = [[function(unit, unitOwner)
		if( UnitIsDead(unit) ) then
			return ShadowUFLocals["Dead"]
		elseif( UnitIsGhost(unit) ) then
			return ShadowUFLocals["Ghost"]
		elseif( not UnitIsConnected(unit) ) then
			return ShadowUFLocals["Offline"]
		end

		local health = UnitHealth(unit)
		return health > 1 and ShadowUF:FormatLargeNumber(health) or 0
	end]],
	["colorname"] = [[function(unit, unitOwner)
		unit = unitOwner or unit
		local color = ShadowUF:GetClassColor(unit)
		if( not color ) then
			return UnitName(unit)
		end
	
		return color .. UnitName(unit) .. "|r"
	end]],
	["curpp"] = [[function(unit, unitOwner) 
		if( UnitPowerMax(unit) == 0 and not UnitIsPlayer(unit) ) then
			return nil
		elseif( UnitIsDeadOrGhost(unit) ) then
			return 0
		end
		
		return ShadowUF:FormatLargeNumber(UnitPower(unit))
	end]],
	["curmaxhp"] = [[function(unit, unitOwner)
		if( UnitIsDead(unit) ) then
			return ShadowUFLocals["Dead"]
		elseif( UnitIsGhost(unit) ) then
			return ShadowUFLocals["Ghost"]
		elseif( not UnitIsConnected(unit) ) then
			return ShadowUFLocals["Offline"]
		end
		
		local health = UnitHealth(unit)
		local maxHealth = UnitHealthMax(unit)
		return string.format("%s/%s", ShadowUF:FormatLargeNumber(health), ShadowUF:FormatLargeNumber(maxHealth))
	end]],
	["absolutehp"] = [[function(unit, unitOwner)
		if( UnitIsDead(unit) ) then
			return ShadowUFLocals["Dead"]
		elseif( UnitIsGhost(unit) ) then
			return ShadowUFLocals["Ghost"]
		elseif( not UnitIsConnected(unit) ) then
			return ShadowUFLocals["Offline"]
		end
		
		local health = UnitHealth(unit)
		local maxHealth = UnitHealthMax(unit)
		return string.format("%s/%s", health, maxHealth)
	end]],
	["abscurhp"] = [[function(unit, unitOwner)
		if( UnitIsDead(unit) ) then
			return ShadowUFLocals["Dead"]
		elseif( UnitIsGhost(unit) ) then
			return ShadowUFLocals["Ghost"]
		elseif( not UnitIsConnected(unit) ) then
			return ShadowUFLocals["Offline"]
		end
		
		return UnitHealth(unit)
	end]],
	["absmaxhp"] = [[function(unit, unitOwner) return UnitHealthMax(unit) end]],
	["abscurpp"] = [[function(unit, unitOwner)
		if( UnitPowerMax(unit) == 0 and not UnitIsPlayer(unit) ) then
			return nil
		elseif( UnitIsDeadOrGhost(unit) ) then
			return 0
		end	
	
		return UnitPower(unit)
	end]],
	["absmaxpp"] = [[function(unit, unitOwner)
		local power = UnitPowerMax(unit)
		if( power == 0 and not UnitIsPlayer(unit) ) then
			return nil
		end
		return power
	end]],
	["absolutepp"] = [[function(unit, unitOwner)
		local maxPower = UnitPowerMax(unit)
		local power = UnitPower(unit)
		if( UnitIsDeadOrGhost(unit) ) then
			return string.format("0/%s", maxPower)
		elseif( maxPower == 0 and power == 0 ) then
			return nil
		end
		
		return string.format("%s/%s", power, maxPower)
	end]],
	["curmaxpp"] = [[function(unit, unitOwner)
		local maxPower = UnitPowerMax(unit)
		local power = UnitPower(unit)
		if( UnitIsDeadOrGhost(unit) ) then
			return string.format("0/%s", maxPower)
		elseif( maxPower == 0 and power == 0 ) then
			return nil
		end
		
		return string.format("%s/%s", ShadowUF:FormatLargeNumber(power), ShadowUF:FormatLargeNumber(maxPower))
	end]],
	["levelcolor"] = [[function(unit, unitOwner)
		local level = UnitLevel(unit)
		if( level < 0 and UnitClassification(unit) == "worldboss" ) then
			return nil
		end
		
		if( UnitCanAttack("player", unit) ) then
			local color = ShadowUF:Hex(GetDifficultyColor(level > 0 and level or 99))
			if( not color ) then
				return level > 0 and level or "??"
			end
			
			return color .. (level > 0 and level or "??") .. "|r"
		else
			return level
		end
	end]],
	["faction"] = [[function(unit, unitOwner) return UnitFactionGroup(unit) end]],
	["level"] = [[function(unit, unitOwner)
		local level = UnitLevel(unit)
		return level > 0 and level or UnitClassification(unit) ~= "worldboss" and "??" or nil
	end]],
	["maxhp"] = [[function(unit, unitOwner) return ShadowUF:FormatLargeNumber(UnitHealthMax(unit)) end]],
	["maxpp"] = [[function(unit, unitOwner)
		local power = UnitPowerMax(unit)
		if( power == 0 and not UnitIsPlayer(unit) ) then
			return nil
		elseif( UnitIsDeadOrGhost(unit) ) then
			return 0
		end
		
		return ShadowUF:FormatLargeNumber(power)
	end]],
	["missinghp"] = [[function(unit, unitOwner)
		if( UnitIsDead(unit) ) then
			return ShadowUFLocals["Dead"]
		elseif( UnitIsGhost(unit) ) then
			return ShadowUFLocals["Ghost"]
		elseif( not UnitIsConnected(unit) ) then
			return ShadowUFLocals["Offline"]
		end

		local missing = UnitHealthMax(unit) - UnitHealth(unit)
		if( missing <= 0 ) then return nil end
		return "-" .. ShadowUF:FormatLargeNumber(missing) 
	end]],
	["missingpp"] = [[function(unit, unitOwner)
		local power = UnitPowerMax(unit)
		if( power == 0 and not UnitIsPlayer(unit) ) then
			return nil
		end

		local missing = power - UnitPower(unit)
		if( missing <= 0 ) then return nil end
		return "-" .. ShadowUF:FormatLargeNumber(missing)
	end]],
	["def:name"] = [[function(unit, unitOwner)
		local deficit = ShadowUF.tagFunc.missinghp(unit, unitOwner)
		if( deficit ) then return deficit end
		
		return ShadowUF.tagFunc.name(unit, unitOwner)
	end]],
	["name"] = [[function(unit, unitOwner) return UnitName(unitOwner or unit) end]],
	["perhp"] = [[function(unit, unitOwner)
		if( UnitIsDead(unit) ) then
			return ShadowUFLocals["Dead"]
		elseif( UnitIsGhost(unit) ) then
			return ShadowUFLocals["Ghost"]
		elseif( not UnitIsConnected(unit) ) then
			return ShadowUFLocals["Offline"]
		end
		
		local max = UnitHealthMax(unit);
		
		return max == 0 and 0 or math.floor(UnitHealth(unit) / max * 100 + 0.5) .. "%"
	end]],
	["perpp"] = [[function(unit, unitOwner)
		local maxPower = UnitPowerMax(unit)
		if( maxPower == 0 and not UnitIsPlayer(unit) ) then
			return nil
		elseif( UnitIsDeadOrGhost(unit) ) then
			return "0%"
		end
		
		return string.format("%d%%", math.floor(UnitPower(unit) / maxPower * 100 + 0.5))
	end]],
	["plus"] = [[function(unit, unitOwner) local c = UnitClassification(unit); return (c == "elite" or c == "rareelite") and "+" end]],
	["race"] = [[function(unit, unitOwner) return UnitRace(unit) end]],
	["rare"] = [[function(unit, unitOwner) local c = UnitClassification(unit); return (c == "rare" or c == "rareelite") and ShadowUFLocals["Rare"] end]],
	["sex"] = [[function(unit, unitOwner) local s = UnitSex(unit) return s == 2 and ShadowUFLocals["Male"] or s == 3 and ShadowUFLocals["Female"] end]],
	["smartclass"] = [[function(unit, unitOwner) return UnitIsPlayer(unit) and ShadowUF.tagFunc.class(unit) or ShadowUF.tagFunc.creature(unit) end]],
	["status"] = [[function(unit, unitOwner)
		if( UnitIsDead(unit) ) then
			return ShadowUFLocals["Dead"]
		elseif( UnitIsGhost(unit) ) then
			return ShadowUFLocals["Ghost"]
		elseif( not UnitIsConnected(unit) ) then
			return ShadowUFLocals["Offline"]
		end
	end]],
	["cpoints"] = [[function(unit, unitOwner) local cp = GetComboPoints(unit, "target") return (cp > 0) and cp end]],
	["smartlevel"] = [[function(unit, unitOwner)
		local c = UnitClassification(unit)
		if(c == "worldboss") then
			return ShadowUFLocals["Boss"]
		else
			local plus = ShadowUF.tagFunc.plus(unit)
			local level = ShadowUF.tagFunc.level(unit)
			if( plus ) then
				return level .. plus
			else
				return level
			end
		end
	end]],
	["dechp"] = [[function(unit, unitOwner) return string.format("%.1f%%", (UnitHealth(unit) / UnitHealthMax(unit)) * 100) end]],
	["classification"] = [[function(unit, unitOwner)
		local c = UnitClassification(unit)
		return c == "rare" and ShadowUFLocals["Rare"] or c == "eliterare" and ShadowUFLocals["Rare Elite"] or c == "elite" and ShadowUFLocals["Elite"] or c == "worldboss" and ShadowUFLocals["Boss"]
	end]],
	["shortclassification"] = [[function(unit, unitOwner)
		local c = UnitClassification(unit)
		return c == "rare" and "R" or c == "eliterare" and "R+" or c == "elite" and "+" or c == "worldboss" and "B"
	end]],
	["group"] = [[function(unit, unitOwner)
		if( GetNumRaidMembers() == 0 ) then return nil end
		local name, server = UnitName(unitOwner or unit)
		if( server and server ~= "" ) then
			name = string.format("%s-%s", name, server)
		end
		
		for i=1, GetNumRaidMembers() do
			local raidName, _, group = GetRaidRosterInfo(i)
			if( raidName == name ) then
				return group
			end
		end
		
		return nil
	end]],
	["druid:curpp"] = [[function(unit, unitOwner)
		if( select(2, UnitClass(unit)) ~= "DRUID" ) then return nil end
		local powerType = UnitPowerType(unit)
		if( powerType ~= 1 and powerType ~= 3 ) then return nil end
		return ShadowUF:FormatLargeNumber(UnitPower(unit, 0))
	end]],
	["druid:abscurpp"] = [[function(unit, unitOwner)
		if( select(2, UnitClass(unit)) ~= "DRUID" ) then return nil end
		local powerType = UnitPowerType(unit)
		if( powerType ~= 1 and powerType ~= 3 ) then return nil end
		return UnitPower(unit, 0)
	end]],
	["druid:curmaxpp"] = [[function(unit, unitOwner)
		if( select(2, UnitClass(unit)) ~= "DRUID" ) then return nil end
		local powerType = UnitPowerType(unit)
		if( powerType ~= 1 and powerType ~= 3 ) then return nil end
		
		local maxPower = UnitPowerMax(unit, 0)
		local power = UnitPower(unit, 0)
		if( UnitIsDeadOrGhost(unit) ) then
			return string.format("0/%s", maxPower)
		elseif( maxPower == 0 and power == 0 ) then
			return nil
		end
		
		return string.format("%s/%s", ShadowUF:FormatLargeNumber(power), ShadowUF:FormatLargeNumber(maxPower))
	end]],
	["druid:absolutepp"] = [[function(unit, unitOwner)
		if( select(2, UnitClass(unit)) ~= "DRUID" ) then return nil end
		local powerType = UnitPowerType(unit)
		if( powerType ~= 1 and powerType ~= 3 ) then return nil end
		return UnitPower(unit, 0)
	end]],
}

-- Use a new [levelcolor] tag with the renamed 3.2 API if they are on 3.2
if( select(4, GetBuildInfo()) >= 30200 ) then
	Tags.defaultTags["levelcolor"] = [[function(unit, unitOwner)
		local level = UnitLevel(unit)
		if( level < 0 and UnitClassification(unit) == "worldboss" ) then
			return nil
		end
		
		if( UnitCanAttack("player", unit) ) then
			local color = ShadowUF:Hex(GetQuestDifficultyColor(level > 0 and level or 99))
			if( not color ) then
				return level > 0 and level or "??"
			end
			
			return color .. (level > 0 and level or "??") .. "|r"
		else
			return level
		end
	end]]
end

-- Default tag events
Tags.defaultEvents = {
	["afk"]					= "PLAYER_FLAGS_CHANGED", -- Yes, I know it's called PLAYER_FLAGS_CHANGED, but arg1 is the unit including non-players.
	["curhp"]               = "UNIT_HEALTH",
	["abscurhp"]			= "UNIT_HEALTH",
	["curmaxhp"]			= "UNIT_HEALTH UNIT_MAXHEALTH UNIT_FACTION",
	["absolutehp"]			= "UNIT_HEALTH UNIT_MAXHEALTH",
	["curpp"]               = "UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER UNIT_DISPLAYPOWER",
	["abscurpp"]            = "UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER UNIT_DISPLAYPOWER",
	["curmaxpp"]			= "UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER UNIT_DISPLAYPOWER UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER",
	["absolutepp"]			= "UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER UNIT_DISPLAYPOWER UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER",
	["druid:curpp"]  	    = "UNIT_MANA UNIT_DISPLAYPOWER",
	["druid:abscurpp"]      = "UNIT_MANA UNIT_DISPLAYPOWER",
	["druid:curmaxpp"]		= "UNIT_MANA UNIT_MAXMANA UNIT_DISPLAYPOWER",
	["druid:absolutepp"]	= "UNIT_MANA UNIT_MAXMANA UNIT_DISPLAYPOWER",
	["level"]               = "UNIT_LEVEL PLAYER_LEVEL_UP",
	["maxhp"]               = "UNIT_MAXHEALTH",
	["def:name"]			= "UNIT_NAME_UPDATE UNIT_MAXHEALTH UNIT_HEALTH",
	["absmaxhp"]			= "UNIT_MAXHEALTH UNIT_FACTION",
	["maxpp"]               = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER",
	["absmaxpp"]			= "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER",
	["missinghp"]           = "UNIT_HEALTH UNIT_MAXHEALTH",
	["missingpp"]           = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_MAXRUNIC_POWER UNIT_RUNIC_POWER",
	["name"]                = "UNIT_NAME_UPDATE",
	["colorname"]			= "UNIT_NAME_UPDATE",
	["perhp"]               = "UNIT_HEALTH UNIT_MAXHEALTH",
	["perpp"]               = "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_MAXRUNIC_POWER UNIT_RUNIC_POWER",
	["status"]              = "UNIT_HEALTH PLAYER_UPDATE_RESTING",
	["smartlevel"]          = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED",
	["cpoints"]             = "UNIT_COMBO_POINTS UNIT_TARGET",
	["rare"]                = "UNIT_CLASSIFICATION_CHANGED",
	["classification"]      = "UNIT_CLASSIFICATION_CHANGED",
	["shortclassification"] = "UNIT_CLASSIFICATION_CHANGED",
	["level"]				= "PARTY_MEMBERS_CHANGED UNIT_LEVEL",
	["dechp"]				= "UNIT_HEALTH UNIT_MAXHEALTH",
	["group"]				= "RAID_ROSTER_UPDATE",
}

-- Default tag help
Tags.defaultHelp = {
	["afk"]					= L["Shows AFK or DND flags if they are toggled."],
	["cpoints"]				= L["Total number of combo points you have on your target."],
	["smartlevel"]			= L["Smart level, returns Boss for bosses, +50 for a level 50 elite mob, or just 80 for a level 80."],
	["classification"]		= L["Units classification, Rare, Rare Elite, Elite, Boss, nothing is shown if they aren't any of those."],
	["shortclassification"]	= L["Short classifications, R for Rare, R+ for Rare Elite, + for Elite, B for boss, nothing is shown if they aren't any of those."],
	["rare"]				= L["Returns Rare if the unit is a rare or rare elite mob."],
	["plus"]				= L["Returns + if the unit is an elite or rare elite mob."],
	["sex"]					= L["Returns the units sex."],
	["smartclass"]			= L["For players, it will return a class, for mobs than it will return their creature type."],
	["status"]				= L["Units status, Dead, Ghost, Offline, nothing is shown if they aren't any of those."],
	["race"]				= L["Unit race, for a Blood Elf then Blood Elf is returned, for a Night Elf than Night Elf is returned and so on."],
	["level"]				= L["Level without any coloring."],
	["maxhp"]				= L["Max health, uses a short format, 17750 is formatted as 17.7k, values below 10000 are formatted as is."],
	["maxpp"]				= L["Max power, uses a short format, 16000 is formatted as 16k, values below 10000 are formatted as is."],
	["missinghp"]			= L["Amount of health missing, if none is missing nothing is shown. Uses a short format, -18500 is shown as -18.5k, values below 10000 are formatted as is."],
	["missingpp"]			= L["Amount of power missing,  if none is missing nothing is shown. Uses a short format, -13850 is shown as 13.8k, values below 10000 are formatted as is."],
	["name"]				= L["Unit name"],
	["perhp"]				= L["Returns current health as a percentage, if the unit is dead or offline than that is shown instead."],
	["perpp"]				= L["Returns current power as a percentage."],
	["class"]				= L["Class name, use [classcolor][class][close] if you want a colored class name."],
	["classcolor"]			= L["Color code for the class, use [classcolor][class][close] if you want the class text to be colored by class"],
	["creature"]			= L["Create type, for example, if you're targeting a Felguard then this will return Felguard."],
	["curhp"]				= L["Current health, uses a short format, 11500 is formatted as 11.5k, values below 10000 are formatted as is."],
	["curpp"]				= L["Current power, uses a short format, 12750 is formatted as 12.7k, values below 10000 are formatted as is."],
	["curmaxhp"]			= L["Current and maximum health, formatted as [curhp]/[maxhp], if the unit is dead or offline then that is shown instead."],
	["curmaxpp"]			= L["Current and maximum power, formatted as [curpp]/[maxpp]."],
	["levelcolor"]			= L["Colored level by difficulty, no color used if you cannot attack the unit."],
	["def:name"]			= L["When the unit is mising health, the [missinghp] tag is shown, when they are at full health then the [name] tag is shown. This lets you see -1000 when they are missing 1000 HP, but their name when they are not missing any."],
	["faction"]				= L["Units alignment, Thrall will return Horde, Magni Bronzebeard will return Alliance."],
	["colorname"]			= L["Unit name colored by class."],
	["absolutepp"]			= L["Absolute current/max power, without any formating so 17750 is still formatted as 17750."],
	["absolutehp"]			= L["Absolute current/max health, without any formating so 17750 is still formatted as 17750."],
	["absmaxhp"]			= L["Absolute maximum health value without any formating so 15000 is still shown as 15000."],
	["abscurhp"]			= L["Absolute current health value without any formating so 15000 is still shown as 15000."],
	["absmaxpp"]			= L["Absolute maximum power value without any formating so 15000 is still shown as 15000."],
	["abscurpp"]			= L["Absolute current power value without any formating so 15000 is still shown as 15000."],
	["reactcolor"]			= L["Reaction color code, use [reactcolor][name][close] to color the units name by their reaction."],
	["dechp"]				= L["Shows the units health as a percentage rounded to the first decimal, meaning 61 out of 110 health is shown as 55.4%."],
	["group"]				= L["Shows the current group number of the unit."],
	["close"]				= L["Closes a color code, pretends colors from showing up on text that you do not want it to."],
	["druid:curpp"]         = string.format(L["Same tag as %s, but this only shows up if the unit is in Bear or Cat form."], "curpp"),
	["druid:abscurpp"]      = string.format(L["Same tag as %s, but this only shows up if the unit is in Bear or Cat form."], "abscurpp"),
	["druid:curmaxpp"]		= string.format(L["Same tag as %s, but this only shows up if the unit is in Bear or Cat form."], "curmaxpp"),
	["druid:absolutepp"]	= string.format(L["Same tag as %s, but this only shows up if the unit is in Bear or Cat form."], "absolutepp"),
}

-- Health and power events that if a tag uses them, they need to be automatically set to update faster
Tags.powerEvents = {
	["UNIT_ENERGY"] = true,
	["UNIT_FOCUS"] = true,
	["UNIT_MANA"] = true,
	["UNIT_RAGE"] = true,
	["UNIT_RUNIC_POWER"] = true,
}

Tags.healthEvents = {
	["UNIT_HEALTH"] = true,
	["UNIT_MAXHEALTH"] = true,
}

-- Events that do not provide a unit, so if the fontstring registered it, it's called regardless
Tags.unitlessEvents = {
	["RAID_ROSTER_UPDATE"] = true,
	["RAID_TARGET_UPDATE"] = true,
	["PARTY_MEMBERS_CHANGED"] = true,
	["PARTY_LEADER_CHANGED"] = true,
	["PLAYER_ENTERING_WORLD"] = true,
	["PLAYER_FLAGS_CHANGED"] = true,
	["PLAYER_XP_UPDATE"] = true,
	["PLAYER_TOTEM_UPDATE"] = true,
	["UPDATE_EXHAUSTION"] = true,
}

-- Event scanner to automatically figure out what events a tag will need
local function loadAPIEvents()
	if( Tags.APIEvents ) then return end
	Tags.APIEvents = {
		["UnitLevel"]				= "UNIT_LEVEL",
		["UnitName"]				= "UNIT_NAME_UPDATE",
		["UnitClassification"]		= "UNIT_CLASSIFICATION_CHANGED",
		["UnitFactionGroup"]		= "UNIT_FACTION PLAYER_FLAGS_CHANGED",
		["UnitHealth%("]			= "UNIT_HEALTH",
		["UnitHealthMax"]			= "UNIT_MAXHEALTH",
		["UnitPower%("]				= "UNIT_ENERGY UNIT_FOCUS UNIT_MANA UNIT_RAGE UNIT_RUNIC_POWER",
		["UnitPowerMax"]			= "UNIT_MAXENERGY UNIT_MAXFOCUS UNIT_MAXMANA UNIT_MAXRAGE UNIT_MAXRUNIC_POWER",
		["UnitPowerType"]			= "UNIT_DISPLAYPOWER",
		["UnitIsDead"]				= "UNIT_HEALTH",
		["UnitIsGhost"]				= "UNIT_HEALTH",
		["UnitIsConnected"]			= "UNIT_HEALTH",
		["UnitIsAFK"]				= "PLAYER_FLAGS_CHANGED",
		["UnitIsDND"]				= "PLAYER_FLAGS_CHANGED",
		["UnitIsPVP"]				= "PLAYER_FLAGS_CHANGED UNIT_FACTION",
		["UnitIsPartyLeader"]		= "PARTY_LEADER_CHANGED PARTY_MEMBERS_CHANGED",
		["UnitIsPVPFreeForAll"]		= "PLAYER_FLAGS_CHANGED UNIT_FACTION",
		["UnitCastingInfo"]			= "UNIT_SPELLCAST_START UNIT_SPELLCAST_STOP UNIT_SPELLCAST_FAILED UNIT_SPELLCAST_INTERRUPTED UNIT_SPELLCAST_DELAYED",
		["UnitChannelInfo"]			= "UNIT_SPELLCAST_CHANNEL_START UNIT_SPELLCAST_CHANNEL_STOP UNIT_SPELLCAST_CHANNEL_INTERRUPTED UNIT_SPELLCAST_CHANNEL_UPDATE",
		["UnitAura"]				= "UNIT_AURA",
		["UnitBuff"]				= "UNIT_AURA",
		["UnitDebuff"]				= "UNIT_AURA",
		["UnitXPMax"]				= "UNIT_PET_EXPERIENCE PLAYER_XP_UPDATE PLAYER_LEVEL_UPDATE",
		["UnitXP%("]				= "UNIT_PET_EXPERIENCE PLAYER_XP_UPDATE PLAYER_LEVEL_UPDATE",
		["GetTotemInfo"]			= "PLAYER_TOTEM_UPDATE",
		["GetXPExhaustion"]			= "UPDATE_EXHAUSTION",
		["GetWatchedFactionInfo"]	= "UPDATE_FACTION",
		["GetRuneCooldown"]			= "RUNE_POWER_UPDATE",
		["GetRuneType"]				= "RUNE_TYPE_UPDATE",
		["GetRaidTargetIndex"]		= "RAID_TARGET_UPDATE",
		["GetComboPoints"]			= "UNIT_COMBO_POINTS",
		["GetNumPartyMembers"]		= "PARTY_MEMBERS_CHANGED",
		["GetNumRaidMembers"]		= "RAID_ROSTER_UPDATE",
		["GetRaidRosterInfo"]		= "RAID_ROSTER_UPDATE",
		["GetPetHappiness"]			= "UNIT_HAPPINESS",
		["GetReadyCheckStatus"]		= "READY_CHECK READY_CHECK_CONFIRM READY_CHECK_FINISHED",
		["GetLootMethod"]			= "PARTY_LOOT_METHOD_CHANGED",
	}
end

-- Scan the actual tag code to find the events it uses
local alreadyScanned = {}
function Tags:IdentifyEvents(code, parentTag)
	-- Already scanned this tag, prevents infinite recursion
	if( parentTag and alreadyScanned[parentTag] ) then
		return ""
	-- Flagged that we already took care of this
	elseif( parentTag ) then
		alreadyScanned[parentTag] = true
	else
		for k in pairs(alreadyScanned) do alreadyScanned[k] = nil end
		loadAPIEvents()
	end
			
	-- Scan our function list to see what APIs are used
	local eventList = ""
	for func, events in pairs(self.APIEvents) do
		if( string.match(code, func) ) then
			eventList = eventList .. events .. " " 
		end
	end
	
	-- Scan if they use any tags, if so we need to check them as well to see what content is used
	for tag in string.gmatch(code, "tagFunc\.(%w+)%(") do
		local code = ShadowUF.Tags.defaultTags[tag] or ShadowUF.db.profile.tags[tag] and ShadowUF.db.profile.tags[tag].func
		eventList = eventList .. " " .. self:IdentifyEvents(code, tag)
	end
	
	-- Remove any duplicate events
	if( not parentTag ) then
		local tagEvents = {}
		for event in string.gmatch(string.trim(eventList), "%S+") do
			tagEvents[event] = true
		end
		
		eventList = ""
		for event in pairs(tagEvents) do
			eventList = eventList .. event .. " "
		end
	end
		
	-- And give them our nicely outputted data
	return string.trim(eventList or "")
end

-- Checker function, makes sure tags are all happy
--[[
function Tags:Verify()
	local fine = true
	for tag, events in pairs(self.defaultEvents) do
		if( not self.defaultTags[tag] ) then
			print(string.format("Found event for %s, but no tag associated with it.", tag))
			fine = nil
		end
	end
	
	for tag, data in pairs(self.defaultTags) do
		if( not self.defaultTags[tag] ) then
			print(string.format("Found tag for %s, but no event associated with it.", tag))
			fine = nil
		end
		
		if( not self.defaultHelp[tag] ) then
			print(string.format("Found tag for %s, but no help text associated with it.", tag))
			fine = nil
		end
		
		local funct, msg = loadstring("return " .. data)
		if( not funct and msg ) then
			print(string.format("Failed to load tag %s.", tag))
			print(msg)
			fine = nil
		end
	end
	
	for tag, data in pairs(self.defaultTags) do
		if( not self.defaultEvents[tag] ) then
			--print(string.format("No event found for %s.", tag))
		end
	end
	
	if( fine ) then
		print("Verified tags, everything is fine.")
	end
end
]]