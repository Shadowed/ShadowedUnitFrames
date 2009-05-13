--[[ 
	Shadow Unit Frames, Mayen/Selari from Illidan (US) PvP
]]

ShadowUF = LibStub("AceAddon-3.0"):NewAddon("ShadowUF", "AceEvent-3.0")
ShadowUF.moduleNames = {}

local L = ShadowUFLocals
local layoutQueue
local modules = {}
local units = {"player", "pet", "target", "targettarget", "targettargettarget", "focus", "party", "partypet", "raid"}

-- The layout table controls everything layout based, are portraits shown in X unit, size, etc. Basically, anything someone building a layout would care about.
-- the units table controls things like unit visibility (Is party enabled period) or should aggro indicators be shown. Anything that someone building a layout
-- does not need control over
function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			tags = {},
			units = {},
			layout = {},
			layoutInfo = {},
			positions = {},
			visibility = {arena = {}, pvp = {}, party = {}, raid = {}},
			hidden = {player = true, pet = true, target = true, party = true, focus = true, targettarget = true},
		},
	}
	
	for _, unit in pairs(units) do
		self.defaults.profile.units[unit] = {enabled = true, healthBar = {colorBy = "percent"}}
	end
	
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults)
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "OnDatabaseShutdown")
	
	-- List of units that SUF supports
	self.units = units
		
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
	
	-- Load all defaults that we need to with nothing being loaded yet
	self:SetLayout("Default", true)
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
				else
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
function ShadowUF:CopyLayoutSettings(key, unit)
	if( not self.db.profile.layout[unit][key] ) then
		self.db.profile.layout[unit][key] = CopyTable(self.db.profile.layout[key])
		return
	elseif( self.db.profile.layout[unit][key] and not self.db.profile.layout[unit][key].enabled ) then
		return
	end
	
	for subKey, subValue in pairs(self.db.profile.layout[key]) do
		if( type(subValue) == "table" ) then
			self.db.profile.db.profile.layout[unit][subKey] = self.db.profile.db.profile.layout[unit][subKey] or {}
			
			for subKey2, subValue2 in pairs(subValue) do
				if( subKey2 ~= "enabled" ) then
					self.db.profile.layout[unit][subKey][subKey2] = subValue2
				end
			end
		elseif( subKey ~= "enabled" ) then
			self.db.profile.layout[unit][subKey] = subValue
		end
	end
end

function ShadowUF:SetLayout(name, importPositions)
	
	if( self.layoutInfo[name] ) then
		self.db.profile.activeLayout = name
		self.db.profile.layout = CopyTable(self.layoutInfo[name].layout)
		
		-- Load all of the configuration, make units inherit everything etc etc
		for _, unit in pairs(units) do
			self.db.profile.layout[unit] = self.db.profile.layout[unit] or {}
			
			-- Import the "module" settings in
			self:CopyLayoutSettings("text", unit)
			for key in pairs(self.moduleNames) do
				self:CopyLayoutSettings(key, unit)
			end

			-- Import unit positioning as well
			if( importPositions and self.db.profile.layout.positions and self.db.profile.layout.positions[unit] ) then
				self.db.profile.positions[unit] = CopyTable(self.db.profile.layout.positions[unit])
			end
		end
		
		-- Remove settings that were only used for inheritance based options
		self.db.profile.layout.text = nil
		for key in pairs(self.moduleNames) do
			self.db.profile.layout[key] = nil
		end
		
		self.db.profile.layout.positions = nil
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
function ShadowUF:RegisterModule(module, key, name)
	module.moduleKey = key
	modules[module] = true
	
	-- This lets the module indicate that it's adding something useful to the DB and needs to be listed for visibility
	-- as well as being loaded from layout code
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

-- Database is getting ready to be written, we need to convert any changed data back into text
function ShadowUF:OnDatabaseShutdown()
	for name, layout in pairs(self.layouts) do
		self.db.profile.layouts[name] = self:WriteTable(layout)
	end
end

function ShadowUF:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ShadowUF|r: " .. msg)
end
