--[[ 
	Shadow Unit Frames, Mayen/Selari from Illidan (US) PvP
]]

ShadowUF = LibStub("AceAddon-3.0"):NewAddon("ShadowUF", "AceEvent-3.0")
ShadowUF.moduleNames = {}

local L = ShadowUFLocals
local layoutQueue
local modules = {}
local units = {"player", "pet", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "raid"}

-- Main layout keys, this does not include units or inherited module options
local mainLayout = {["bars"] = true, ["backdrop"] = true, ["font"] = true, ["powerColor"] = true, ["healthColor"] = true, ["xpColor"] = true, ["positions"] = true}
-- Sub layout keys inside layouts that are accepted
local subLayout = {["growth"] = true, ["name"] = true, ["text"] = true, ["alignment"] = true, ["width"] = true, ["background"] = true, ["order"] = true, ["height"] = true, ["scale"] = true, ["xOffset"] = true, ["yOffset"] = true, ["groupBy"] = true, ["maxColumns"] = true, ["unitsPerColumn"] = true, ["columnSpacing"] = true, ["attribAnchorPoint"] = true, ["size"] = true, ["point"] = true,["anchorTo"] = true, ["anchorPoint"] = true, ["relativePoint"] = true, ["x"] = true, ["y"] = true}

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			locked = true,
			advanced = false,
			tags = {},
			units = {},
			layoutInfo = {},
			positions = {},
			visibility = {arena = {}, pvp = {}, party = {}, raid = {}},
			hidden = {player = true, pet = true, target = true, party = true, focus = true, targettarget = true, cast = false},
		},
	}
	
	self:LoadUnitDefaults()
	
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "OnDatabaseShutdown")
	
	-- List of units that SUF supports
	self.units = units
	self.regModules = modules
		
	-- Setup tag cache
	self.tagFunc = setmetatable({}, {
		__index = function(tbl, index)
			if( not ShadowUF.Tags.defaultTags[index] and not ShadowUF.db.profile.tags[index] ) then
				tbl[index] = false
				return false
			end
			
			local funct, msg = loadstring("return " .. (ShadowUF.Tags.defaultTags[index] or ShadowUF.db.profile.tags[index].func))
			
			if( funct ) then
				funct = funct()
			elseif( msg ) then
				error(msg, 3)
			end
			
			tbl[index] = funct
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
	
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "LoadUnits")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		ShadowUF:UnregisterEvent("PLAYER_ENTERING_WORLD")
		ShadowUF:LoadUnits()
	end)
	
	-- Load any layouts that were waiting
	if( layoutQueue ) then
		for name, data in pairs(layoutQueue) do
			self:RegisterLayout(name, data)
		end
		
		layoutQueue = nil
	end
	
	self.Layout = self.modules.Layout
	self.Units = self.modules.Units
	self.Tags = self.modules.Tags

	-- Hide any Blizzard frames
	self:HideBlizzardFrames()
	
	-- Load SML info
	self.Layout:LoadSML()
	
	-- No layout is loaded, so set this as our active one
	if( not self.db.profile.activeLayout ) then
		self:SetLayout("Default", true)
	end
end

function ShadowUF:LoadUnits()
	local zone = select(2, IsInInstance())
	for _, type in pairs(units) do
		local config = self.db.profile.units[type]
		if( config ) then
			local enabled = config.enabled
			if( zone ~= "none" ) then
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
			height = 0,
			width = 0,
			scale = 1.0,
			enabled = false,
			effectiveScale = true,
			healthBar = {enabled = true, colorType = "percent"},
			powerBar = {enabled = true},
			portrait = {enabled = false, type = "3D"},
			castBar = {
				enabled = false,
				castName = {anchorTo = "$parent", anchorPoint = "ICL", x = 1, y = 0},
				castTime = {anchorTo = "$parent", anchorPoint = "ICR", x = -1, y = 0},
			},
			fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60},
			xpBar = {enabled = false},
			comboPoints = {enabled = false, anchorTo = "$parent", anchorPoint = "BR", x = 0, y = 0},
			combatText = {enabled = true, anchorTo = "$parent", anchorPoint = "C", x = 0, y = 0},
			text = {
				{enabled = true, name = L["Left text"], width = 0.60, text = "[name]", anchorTo = "$healthBar", anchorPoint = "ICL", x = 3, y = 0},
				{enabled = true, name = L["Right text"], width = 0.40, text = "[curmaxhp]", anchorTo = "$healthBar", anchorPoint = "ICR", x = -3, y = 0},
				
				{enabled = true, name = L["Left text"], width = 0.60, text = "[level] [race]", anchorTo = "$powerBar", anchorPoint = "ICL", x = 3, y = 0},
				{enabled = true, name = L["Right text"], width = 0.40, text = "[curmaxpp]", anchorTo = "$powerBar", anchorPoint = "ICR", x = -3, y = 0},
			},
			indicators = {
				status = {enabled = false, size = 19, anchorTo = "$parent", x = 0, y = 0},
				pvp = {enabled = false, size = 22, anchorTo = "$parent", x = 10, y = 2},
				leader = {enabled = false, size = 14, anchorTo = "$parent", x = 3, y = 2},
				masterLoot = {enabled = false, size = 12, anchorTo = "$parent",  x = 15, y = 2},
				raidTarget = {enabled = true, size = 22, anchorTo = "$parent", x = 0, y = -8},
				happiness = {enabled = false, size = 16, anchorTo = "$parent", x = 2, y = -2},	
			},
			auras = {
				buffs = {enabled = false, inColumn = 10, rows = 4, enlargeSelf = false, anchorPoint = "TOP", size = 16, x = 0, y = 0, HELPFUL = true},
				debuffs = {enabled = false, inColumn = 10, rows = 4, enlargeSelf = true, anchorPoint = "BOTTOM", size = 16, x = 0, y = 0, HARMFUL = true},
			},
		}
	end
		
	self.defaults.profile.units.player.enabled = true
	self.defaults.profile.units.player.portrait.enabled = true
	self.defaults.profile.units.focus.enabled = true
	self.defaults.profile.units.focustarget.enabled = true
	self.defaults.profile.units.target.enabled = true
	self.defaults.profile.units.target.portrait.enabled = true
	self.defaults.profile.units.targettarget.enabled = true
	self.defaults.profile.units.targettargettarget.enabled = true
	self.defaults.profile.units.pet.enabled = true
	self.defaults.profile.units.party.enabled = true
	self.defaults.profile.units.party.portrait.enabled = true

	self.defaults.profile.positions.partypet.anchorTo = "$parent"
	self.defaults.profile.positions.partypet.anchorPoint = "BR"
		
	-- Only can show one row for party without clipping
	self.defaults.profile.units.party.auras.buffs.rows = 1
	
	-- Disable all indicators quickly
	for _, unit in pairs(units) do
		if( unit == "player" or unit == "party" or unit == "target" ) then
			self.defaults.profile.units[unit].indicators.status.enabled = true
			self.defaults.profile.units[unit].indicators.pvp.enabled = true
			self.defaults.profile.units[unit].indicators.leader.enabled = true
			self.defaults.profile.units[unit].indicators.masterLoot.enabled = true

			self.defaults.profile.units[unit].auras.buffs.enabled = false
			self.defaults.profile.units[unit].auras.debuffs.enabled = false
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
	if( type == "player" ) then
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
local function verifyTable(tbl)
	for key, value in pairs(tbl) do
		if( type(value) == "table" ) then
			tbl[key] = verifyTable(value)
		else
			tbl[key] = nil
		end
	end
	
	return tbl
end

local function mergeTable(parent, child)
	for key, value in pairs(child) do
		if( type(parent[key]) == "table" ) then
			parent[key] = mergeTable(parent[key], value)
		elseif( type(value) == "table" ) then
			parent[key] = CopyTable(value)
		else
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
				end
			end
		end
	end
	
	-- Now go through and verify all of the unit settings
	for unit in pairs(units) do
		if( layout[unit] ) then
			verifyTable(layout[unit])
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

function ShadowUF:RegisterLayout(name, data)
	if( not name ) then
		error(L["Cannot register layout, no name passed."])
	elseif( type(data) ~= "table" ) then
		error(L["Cannot register layout, configuration should be a table got %s."])
	-- We aren't ready for the layout yet, queue it and will load it once everything is initialized
	elseif( not self.db ) then
		layoutQueue = layoutQueue or {}
		layoutQueue[name] = data
		return
	end
	
	if( type(data) == "table" ) then
		self.db.profile.layoutInfo[name] = self:WriteTable(data)
	else
		self.db.profile.layoutInfo[name] = data
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
	-- Check if we need to reimport the layout
	if( not self.db.profile.activeLayout ) then
		self:SetLayout("Default", true)
	end

	ShadowUF.Units:ProfileChanged()
	ShadowUF:LoadUnits()
	ShadowUF.Layout:ReloadAll()
end

-- Database is getting ready to be written, we need to convert any changed data back into text
function ShadowUF:OnDatabaseShutdown()
	for name, layout in pairs(self.layouts) do
		self.db.profile.layouts[name] = self:WriteTable(layout)
	end
end

function ShadowUF:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ShadowUF|r: " .. msg)
end
