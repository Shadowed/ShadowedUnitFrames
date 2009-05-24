--[[ 
	Shadow Unit Frames, Mayen/Selari from Illidan (US) PvP
]]

ShadowUF = {}
ShadowUF.moduleNames = {}

local L = ShadowUFLocals
local layoutQueue
local modules = {}
local units = {"player", "pet", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "partytarget", "raid"}
local defaultDB

-- Main layout keys, this does not include units or inherited module options
local mainLayout = {["classColors"] = true, ["bars"] = true, ["backdrop"] = true, ["font"] = true, ["powerColors"] = true, ["healthColors"] = true, ["xpColors"] = true, ["positions"] = true}
-- Sub layout keys inside layouts that are accepted
local subLayout = {["runebar"] = true, ["growth"] = true, ["name"] = true, ["text"] = true, ["alignment"] = true, ["width"] = true, ["background"] = true, ["order"] = true, ["height"] = true, ["scale"] = true, ["xOffset"] = true, ["yOffset"] = true, ["maxColumns"] = true, ["unitsPerColumn"] = true, ["columnSpacing"] = true, ["attribAnchorPoint"] = true, ["size"] = true, ["point"] = true,["anchorTo"] = true, ["anchorPoint"] = true, ["relativePoint"] = true, ["x"] = true, ["y"] = true}

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			locked = false,
			advanced = false,
			tags = {},
			units = {},
			layoutInfo = {},
			positions = {},
			visibility = {arena = {}, pvp = {}, party = {}, raid = {}},
			hidden = {player = true, pet = true, target = true, party = true, focus = true, targettarget = true, cast = false, runes = true, buffs = true},
		},
	}
	
	self:LoadUnitDefaults()
	
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfilesChanged")
	
	-- Things other modules need to access
	self.units = units
	self.regModules = modules
	self.mainLayout = mainLayout
	self.subLayout = subLayout
	
	-- Setup tag cache
	self.tagFunc = setmetatable({}, {
		__index = function(tbl, index)
			if( not ShadowUF.Tags.defaultTags[index] and not ShadowUF.db.profile.tags[index] ) then
				tbl[index] = false
				return false
			end
			
			local func, msg = loadstring("return " .. (ShadowUF.Tags.defaultTags[index] or ShadowUF.db.profile.tags[index].func or ""))
			
			if( func ) then
				func = func()
			elseif( msg ) then
				error(msg, 3)
			end
			
			tbl[index] = func
			return tbl[index]
		end
	})
	
	-- Setup layout cache
	self.layoutInfo = setmetatable({}, {
		__index = function(tbl, index)
			if( not index ) then return false end
			if( ShadowUF.db.profile.layoutInfo[index] ) then
				local msg
				tbl[index], msg = loadstring("return " .. ShadowUF.db.profile.layoutInfo[index])()
				
				if( msg ) then
					error(msg, 3)
				end
			else
				tbl[index] = false
			end
			
			return tbl[index]
		end,
	})

	-- Reset the "Defaults" layout as it's now named default
	if( self.db.profile.layoutInfo.Defaults ) then
		self.db.profile.layoutInfo.Defaults = nil
		if( self.db.profile.activeLayout == "Defaults" ) then
			self.db.profile.activeLayout = "default"
		end
	end
	
	-- Load any layouts that were waiting
	if( layoutQueue ) then
		for name, data in pairs(layoutQueue) do
			self:RegisterLayout(name, data)
		end
		
		layoutQueue = nil
	end
	
	-- Hide any Blizzard frames
	self:HideBlizzardFrames()
	
	-- No layout is loaded, so set this as our active one
	if( not self.db.profile.activeLayout ) then
		self:SetLayout("default", true)
	end

	-- Load SML info
	self.Layout:LoadSML()

	-- Upgrade power formats
	if( ShadowUF.db.profile.powerColor ) then
		ShadowUF.db.profile.healthColors = CopyTable(ShadowUF.db.profile.healthColor)
		ShadowUF.db.profile.healthColor = nil
		ShadowUF.db.profile.xpColors = CopyTable(ShadowUF.db.profile.xpColor)
		ShadowUF.db.profile.xpColor = nil
		ShadowUF.db.profile.powerColor = nil
		ShadowUF.db.profile.powerColors = {
			MANA = {r = 0.30, g = 0.50, b = 0.85}, 
			RAGE = {r = 0.90, g = 0.20, b = 0.30},
			FOCUS = {r = 1.0, g = 0.85, b = 0}, 
			ENERGY = {r = 1.0, g = 0.85, b = 0.10}, 
			HAPPINESS = {r = 0.50, g = 0.90, b = 0.70},
			RUNES = {r = 0.50, g = 0.50, b = 0.50}, 
			RUNIC_POWER = {b = 0.60, g = 0.45, r = 0.35}, 
		}
	end
end

local partyDisabled
function ShadowUF:RAID_ROSTER_UPDATE()
	if( GetNumRaidMembers() > 5 and self.db.profile.units.party.enabled and self.db.profile.units.party.hideInRaid ) then
		if( not partyDisabled ) then
			partyDisabled = true
			self.Units:UninitializeFrame(self.db.profile.units.party, "party")
		end
	elseif( partyDisabled ) then
		partyDisabled = false
		self:LoadUnits()
	end
end

function ShadowUF:LoadUnits()
	local zone = select(2, IsInInstance())
	for _, type in pairs(units) do
		local config = self.db.profile.units[type]
		if( config ) then
			local enabled = config.enabled
			if( type == "party" and partyDisabled ) then
				enabled = false
			elseif( zone ~= "none" ) then
				if( self.db.profile.visibility[zone][type] == false ) then
					enabled = false
				elseif( self.db.profile.visibility[zone][type] == true ) then
					enabled = true
				end
			end
			
			if( enabled ) then
				self.Units:InitializeFrame(config, type)
			else
				self.Units:UninitializeFrame(config, type)
			end
		else
			self.Units:UninitializeFrame(config, type)
		end
	end
end

function ShadowUF:LoadUnitDefaults()
	for _, unit in pairs(units) do
		self.defaults.profile.positions[unit] = {point = "", relativePoint = "", anchorPoint = "", anchorTo = "UIParent", x = 0, y = 0}
		
		self.defaults.profile.units[unit] = {
			height = 0, width = 0, scale = 1.0, enabled = false, effectiveScale = true,
			healthBar = {enabled = true, colorType = "percent", reaction = true}, powerBar = {enabled = true}, portrait = {enabled = false, type = "3D"}, runeBar = {enabled = false}, totemBar = {enabled = false},
			incHeal = {enabled = false, showSelf = true}, range = {enabled = false, oorAlpha = 0.80, inAlpha = 1.0},
			castBar = {enabled = false, castName = {anchorTo = "$parent", anchorPoint = "ICL", x = 1, y = 0}, castTime = {anchorTo = "$parent", anchorPoint = "ICR", x = -1, y = 0},},
			fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60},xpBar = {enabled = false},
			comboPoints = {enabled = false, anchorTo = "$parent", anchorPoint = "BR", x = 0, y = 0},
			combatText = {enabled = true, anchorTo = "$parent", anchorPoint = "C", x = 0, y = 0},
			text = {
				{enabled = true, name = L["Left text"], width = 0.60, text = "[name]", anchorTo = "$healthBar", anchorPoint = "ICL", x = 3, y = 0},
				{enabled = true, name = L["Right text"], width = 0.40, text = "[curmaxhp]", anchorTo = "$healthBar", anchorPoint = "ICR", x = -3, y = 0},
				{enabled = true, name = L["Left text"], width = 0.60, text = "[level] [race]", anchorTo = "$powerBar", anchorPoint = "ICL", x = 3, y = 0},
				{enabled = true, name = L["Right text"], width = 0.40, text = "[curmaxpp]", anchorTo = "$powerBar", anchorPoint = "ICR", x = -3, y = 0},
			},
			indicators = {
				status = {enabled = false, size = 19, anchorPoint = "LB", anchorTo = "$parent", x = 0, y = 0},
				pvp = {enabled = false, size = 22, anchorPoint = "BL", anchorTo = "$parent", x = 10, y = 2},
				leader = {enabled = false, size = 14, anchorPoint = "TL", anchorTo = "$parent", x = 3, y = 2},
				masterLoot = {enabled = false, size = 12, anchorPoint = "TL", anchorTo = "$parent",  x = 15, y = 2},
				raidTarget = {enabled = true, size = 22, anchorPoint = "TC", anchorTo = "$parent", x = 0, y = -8},
				happiness = {enabled = false, size = 16, anchorPoint = "BR", anchorTo = "$parent", x = 2, y = -2},	
			},
			auras = {
				buffs = {enabled = false, perRow = 11, maxRows = 4, prioritize = true, enlargeSelf = false, anchorPoint = "TOP", size = 16, x = 0, y = 0, HELPFUL = true},
				debuffs = {enabled = false, perRow = 11, maxRows = 4, enlargeSelf = true, anchorPoint = "BOTTOM", size = 16, x = 0, y = 0, HARMFUL = true},
			},
		}
	end
	
	self.defaults.profile.units.player.enabled = true
	self.defaults.profile.units.player.portrait.enabled = true
	self.defaults.profile.units.player.indicators.status.enabled = true
	self.defaults.profile.units.focus.enabled = true
	self.defaults.profile.units.focustarget.enabled = true
	self.defaults.profile.units.target.enabled = true
	self.defaults.profile.units.target.portrait.enabled = true
	self.defaults.profile.units.targettarget.enabled = true
	self.defaults.profile.units.targettargettarget.enabled = true
	self.defaults.profile.units.pet.enabled = true
	self.defaults.profile.units.party.enabled = true
	self.defaults.profile.units.party.portrait.enabled = true
	self.defaults.profile.units.party.auras.debuffs.maxRows = 1
	self.defaults.profile.units.party.auras.buffs.maxRows = 1

	self.defaults.profile.units.raid.auras.debuffs.enabled = false
	self.defaults.profile.units.raid.auras.buffs.enabled = false

	self.defaults.profile.units.raid.groupBy = "GROUP"
	self.defaults.profile.units.raid.sortOrder = "ASC"

	self.defaults.profile.positions.partypet.anchorTo = "$parent"
	self.defaults.profile.positions.partypet.anchorPoint = "RB"
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
					
	-- Only can show one row for party without clipping
	self.defaults.profile.units.party.auras.buffs.rows = 1
	
	-- Disable all indicators quickly
	for _, unit in pairs(units) do
		if( unit == "player" or unit == "party" or unit == "target" ) then
			self.defaults.profile.units[unit].indicators.pvp.enabled = true
			self.defaults.profile.units[unit].indicators.leader.enabled = true
			self.defaults.profile.units[unit].indicators.masterLoot.enabled = true

			self.defaults.profile.units[unit].auras.buffs.enabled = true
			self.defaults.profile.units[unit].auras.debuffs.enabled = true
		elseif( unit == "pet" ) then
			self.defaults.profile.units[unit].indicators.happiness.enabled = true
		end
	end
end

-- Hiding Blizzard stuff (Stolen from haste)
function ShadowUF:HideBlizzardFrames()
	-- Hide Blizzard frames
	for type, hidden in pairs(self.db.profile.hidden) do
		if( hidden ) then
			self:HideBlizzard(type)
		end
	end
end

local function dummy() end
function ShadowUF:HideBlizzard(type)
	if( type == "runes" ) then
		RuneFrame.Show = dummy
		RuneFrame:Hide()
	elseif( type == "buffs" ) then
		BuffFrame:UnregisterEvent("UNIT_AURA")
		TemporaryEnchantFrame:Hide()
		BuffFrame:Hide()
	elseif( type == "player" ) then
		PlayerFrame:UnregisterAllEvents()
		PlayerFrame.Show = dummy
		PlayerFrame:Hide()

		PlayerFrameHealthBar:UnregisterAllEvents()
		PlayerFrameManaBar:UnregisterAllEvents()
	elseif( type == "pet" ) then
		PetFrame:UnregisterAllEvents()
		PetFrame.Show = dummy
		PetFrame:Hide()

		PetFrameHealthBar:UnregisterAllEvents()
		PetFrameManaBar:UnregisterAllEvents()
	elseif( type == "target" ) then
		TargetFrame:UnregisterAllEvents()
		TargetFrame.Show = dummy
		TargetFrame:Hide()

		TargetFrameHealthBar:UnregisterAllEvents()
		TargetFrameManaBar:UnregisterAllEvents()
		TargetFrameSpellBar:UnregisterAllEvents()

		ComboFrame:UnregisterAllEvents()
		ComboFrame.Show = dummy
		ComboFrame:Hide()
	elseif( type == "focus" ) then
		FocusFrame:UnregisterAllEvents()
		FocusFrame.Show = dummy
		FocusFrame:Hide()

		FocusFrameHealthBar:UnregisterAllEvents()
		FocusFrameManaBar:UnregisterAllEvents()
		FocusFrameSpellBar:UnregisterAllEvents()
	elseif( type == "targettarget" ) then
		TargetofTargetFrame:UnregisterAllEvents()
		TargetofTargetFrame.Show = dummy
		TargetofTargetFrame:Hide()

		TargetofTargetHealthBar:UnregisterAllEvents()
		TargetofTargetManaBar:UnregisterAllEvents()
	elseif( type == "cast" ) then
		CastingBarFrame:UnregisterAllEvents()
		PetCastingBarFrame:UnregisterAllEvents()
	elseif( type == "party" ) then
		for i=1, MAX_PARTY_MEMBERS do
			local party = "PartyMemberFrame" .. i
			local frame = getglobal(party)

			frame:UnregisterAllEvents()
			frame.Show = dummy
			frame:Hide()

			getglobal(party .. "HealthBar"):UnregisterAllEvents()
			getglobal(party .. "ManaBar"):UnregisterAllEvents()
		end
	end
end

-- Plugin APIs
function ShadowUF:VerifyTable(tbl)
	for key, value in pairs(tbl) do
		if( type(value) == "table" ) then
			tbl[key] = self:VerifyTable(value)
		elseif( not subLayout[key] ) then
			tbl[key] = nil
		end
	end
	
	return tbl
end

local function mergeTable(parent, child, safeMerge)
	for key, value in pairs(child) do
		if( type(parent[key]) == "table" ) then
			parent[key] = mergeTable(parent[key], value, safeMerge)
		elseif( type(value) == "table" ) then
			if( safeMerge ) then
				parent[key] = mergeTable(parent[key], value, safeMerge)
			else
				parent[key] = CopyTable(value)
			end
		elseif( not safeMerge or parent[key] == nil ) then
			parent[key] = value
		end
	end
	
	return parent
end

function ShadowUF:SetLayout(name, importPositions)
	if( not self.layoutInfo[name] ) then
		return
	end
	
	self.db.profile.activeLayout = name
	local layout = CopyTable(self.layoutInfo[name].layout)
	
	-- Merge all parent module settings into the units module setting (If there are none)
	for module in pairs(self.moduleNames) do
		if( layout[module] ) then
			for _, unit in pairs(units) do
				layout[unit] = layout[unit] or {}
				if( not layout[unit][module] ) then
					layout[unit][module] = CopyTable(layout[module])
				else
					layout[unit][module] = mergeTable(layout[unit][module], layout[module], true)
				end
			end
		end
	end
	
	-- Now go through and verify all of the unit settings
	for unit in pairs(units) do
		if( layout[unit] ) then
			self:VerifyTable(layout[unit])
		end
	end
	
	-- Don't overwrite positioning data
	if( not importPositions ) then
		layout.positions = nil
	end
	
	-- Merge all the units now
	for _, unit in pairs(units) do
		if( layout[unit] ) then
			ShadowUF.db.profile.units[unit] = mergeTable(ShadowUF.db.profile.units[unit], layout[unit])
		end
	end
	
	-- Do a full merge on the main layout keys, nothing we want to save in them
	for key in pairs(mainLayout) do
		ShadowUF.db.profile[key] = layout[key]
	end
end

function ShadowUF:IsLayoutRegistered(name)
	return self.db.profile.layoutInfo[name]
end

-- Reduces the total size of a layout by renaming some common variables
--20000 characters
local compressionMap
function ShadowUF:CompressLayout(data)
	compressionMap = compressionMapor or {[";anchorTo="]=";aT=",[";anchorPoint="]=";aP=",[";width="]=";w=",[";height="]=";h=",[";background="]=";bg=",[";castName="]=";cN=",[";castTime="]=";cT=",[";relativePoint="]=";rP=",[";point="]=";p=",[";indicators="]=";is=",[";size="]=";s=",[";name="]=";n=",[";text="]=";t=",[";comboPoints="]=";cP=",[";combatText="]=";coT=",["{anchorTo="]="{aT=",["{anchorPoint="]="{aP=",["{width="]="{w=",["{height="]="{h=",["{background="]="{bg=",["{castName="]="{cN=",["{castTime="]="{cT=",["{relativePoint="]="{rP=",["{point="]="{p=",["{indicators="]="{is=",["{size="]="{s=",["{name="]="{n=",["{text="]="{t=",["{comboPoints="]="{cP=",["{combatText="]="{coT=",}
	
	for find, replace in pairs(compressionMap) do
		data = string.gsub(data, find, replace)
	end
	
	-- Strip any empty tables
	data = string.gsub(data, "([a-zA-Z]+={})", "")
	data = string.gsub(data, ";;", ";")
	data = string.gsub(data, ";}", "}")
	
	return data
end

function ShadowUF:UncompressLayout(data)
	compressionMap = compressionMapor or {[";anchorTo="]=";aT=",[";anchorPoint="]=";aP=",[";width="]=";w=",[";height="]=";h=",[";background="]=";bg=",[";castName="]=";cN=",[";castTime="]=";cT=",[";relativePoint="]=";rP=",[";point="]=";p=",[";indicators="]=";is=",[";size="]=";s=",[";name="]=";n=",[";text="]=";t=",[";comboPoints="]=";cP=",[";combatText="]=";coT=",["{anchorTo="]="{aT=",["{anchorPoint="]="{aP=",["{width="]="{w=",["{height="]="{h=",["{background="]="{bg=",["{castName="]="{cN=",["{castTime="]="{cT=",["{relativePoint="]="{rP=",["{point="]="{p=",["{indicators="]="{is=",["{size="]="{s=",["{name="]="{n=",["{text="]="{t=",["{comboPoints="]="{cP=",["{combatText="]="{coT=",}
	
	for replace, find in pairs(compressionMap) do
		data = string.gsub(data, find, replace)
	end
	
	return data
end

function ShadowUF:RegisterLayout(id, data)
	if( not id ) then
		error(L["Cannot register layout, no name passed."])
	-- We aren't ready for the layout yet, queue it and will load it once everything is initialized
	elseif( not self.db ) then
		layoutQueue = layoutQueue or {}
		layoutQueue[id] = data
		return
	end
	
	if( type(data) == "table" ) then
		self.db.profile.layoutInfo[id] = self:WriteTable(data)
	else
		self.db.profile.layoutInfo[id] = self:UncompressLayout(data)
	end
	
	-- Store a copy of the default DB, so if someone does a layout reset we can still keep data.
	if( id == "default" ) then
		defaultDB = self.db.profile.layoutInfo[id]
	end
end

-- Module APIs
function ShadowUF:RegisterModule(module, key, name, type)
	module.moduleKey = key
	module.moduleType = type
	modules[module] = true
	
	-- This lets the module indicate that it's adding something useful to the DB and needs to be listed for visibility as well as being loaded from layout code
	if( key and name ) then
		self.moduleNames[key] = name
	end
end

function ShadowUF:FireModuleEvent(event, frame, unit)
	for module in pairs(modules) do
		if( module[event] ) then
			module[event](module, frame, unit)
		end
	end
end

-- Tag APIs
function ShadowUF:IsTagRegistered(name)
	return self.db.profile.tags[name] or self.Tags.defaultTags[name]
end

function ShadowUF:RegisterTag(name, tag)
	if( not name ) then
		error(L["Cannot register tag, no name passed."])
	elseif( type(data) ~= "table" ) then
		error(L["Cannot register tag, data should be a table got %s."])
	elseif( not data.help or not data.events or not data.func ) then
		error(L["Cannot register tag, data should be passed as {help = \"help text\", events = \"EVENT_A EVENT_B\", funct = \"function(unit) return \"Foo\" end}"], 3)
	end
	
	self.db.profile.tags[name] = CopyTable(tag)
end

-- Converts a table back to a format we can loadstring
function ShadowUF:WriteTable(tbl)
	local data = ""
	
	for key, value in pairs(tbl) do
		local valueType = type(value)
		
		-- Wrap the key in brackets if it's a number
		if( type(key) == "number" ) then
			key = string.format("[%s]", key)
		end
		
		-- foo = {bar = 5}
		if( valueType == "table" ) then
			data = string.format("%s%s=%s;", data, key, self:WriteTable(value))
		
		-- foo = true / foo = 5
		elseif( valueType == "number" or valueType == "boolean" ) then
			data = string.format("%s%s=%s;", data, key, tostring(value))
		-- foo = "bar"
		else
			data = string.format("%s%s=\"%s\";", data, key, tostring(value))
		end
	end
	
	return "{" .. data .. "}"
end

-- Profiles changed
function ShadowUF:ProfilesChanged()
	-- Reset any loaded caches
	for k in pairs(self.tagFunc) do self.tagFunc[k] = nil end
	for k in pairs(self.layoutInfo) do self.layoutInfo[k] = nil end

	if( not self.layoutInfo.default ) then
		self.layoutInfo.default = nil
		self.db.profile.layoutInfo.default = defaultDB
	end
	
	-- Check if we need to reimport the layout
	if( not self.db.profile.activeLayout ) then
		self:SetLayout("default", true)
	end

	ShadowUF.Units:ProfileChanged()
	ShadowUF:LoadUnits()
	ShadowUF.Layout:ReloadAll()
end

function ShadowUF:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ShadowUF|r: " .. msg)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
	if( event == "ADDON_LOADED" ) then
		if( IsAddOnLoaded("ShadowedUnitFrames") ) then
			frame:UnregisterEvent("ADDON_LOADED")
			
			ShadowUF:OnInitialize()
		end
	elseif( event == "ZONE_CHANGED_NEW_AREA" ) then
		ShadowUF:LoadUnits()
	elseif( event == "PLAYER_ENTERING_WORLD" ) then
		ShadowUF:LoadUnits()
		ShadowUF:RAID_ROSTER_UPDATE()
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	else
		ShadowUF[event](ShadowUF, event, ...)
	end
end)
