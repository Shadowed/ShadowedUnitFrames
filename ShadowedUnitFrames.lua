--[[ 
	Shadow Unit Frames, Mayen/Selari from Illidan (US) PvP
]]

ShadowUF = LibStub("AceAddon-3.0"):NewAddon("ShadowUF", "AceEvent-3.0")

local L = ShadowUFLocals
local layoutQueue
local modules = {}

--[[
		layoutInfo = stores information about the layout, this includes author, default layout config, ect
		layout = this is the current layouts configuration
		tags = all custom tag functions, stored as strings
		tagEvents = all custom tag events, stored as strings
		units = all unit specific configuration
]]

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			tags = {},
			tagEvents = {},
			units = {},
			layout = {},
			layoutInfo = {},
			unitDefault = {
				enabled = true,
				portrait = {
					enabled = true,
				},
				healthBar = {
					smoothUpdates = false,
					colorBy = "percent",
				},
				manaBar = {
					enabled = true,
					smoothUpdates = false,
				},
			},
		},
	}
	
	-- Initialize default unit configuration
	local units = {"target", "player", "pet", "focus"}
	for _, unit in pairs(units) do
		self.defaults.profile.units[unit] = CopyTable(self.defaults.profile.unitDefault)
	end
	
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults)
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "OnDatabaseShutdown")
			
	-- Setup tag cache
	self.tags = setmetatable({}, {
		__index = function(tbl, index)
			if( not ShadowUF.modules.Tags.defaultTags[index] and not ShadowUF.db.profile.tags[index] ) then
				tbl[index] = false
				return false
			end
			
			local funct, msg = loadstring("return " .. (ShadowUF.modules.Tags.defaultTags[index] or ShadowUF.db.profile.tags[index]))
			if( funct ) then
				funct = funct()
			elseif( msg ) then
				error(msg, 3)
			end
			
			tbl[index] = funct
			return tbl[index]
		end
	})
	
	-- For consistency mostly
	self.tagEvents = self.db.profile.tagEvents
	
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
	
	-- Load SML info
	self.modules.Layout:LoadSML()
	
	-- Load all defaults that we need to with nothing being loaded yet
	self:SetLayout("Default")
end

function ShadowUF:LoadUnits()
	for unit, data in pairs(self.db.profile.units) do
		if( data.enabled ) then
			self.modules.Unit:InitializeFrame(data, unit)
		else
			self.modules.Unit:UninitializeFrame(data, unit)
		end
	end
end

-- Plugin APIs
function ShadowUF:SetLayout(name)
	if( self.layoutInfo[name] ) then
		self.db.profile.activeLayout = name
		self.db.profile.layout = CopyTable(self.layoutInfo[name].layout)
		
		local units = {"player", "target", "party", "pet", "focus", "targettarget"}
		for _, unit in pairs(units) do
			self.db.profile.units[unit] = CopyTable(self.defaults.profile.unitDefault)
			if( self.db.profile.layout[unit] ) then
				for k, v in pairs(self.db.profile.layout[unit]) do
					if( type(v) == "table" and self.db.profile.units[unit][k] ) then
						for k2, v2 in pairs(v) do
							self.db.profile.units[unit][k][k2] = v2
						end
					elseif( type(v) == "table" and not self.db.profile.units[unit][k] ) then
						self.db.profile.units[unit][k] = CopyTable(v)
					else
						self.db.profile.units[unit][k] = v
					end
				end
			end
		end
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
function ShadowUF:RegisterModule(module)
	modules[module] = true
end

function ShadowUF:FireModuleEvent(event, frame, unit)
	for module in pairs(modules) do
		if( module[event] ) then
			module[event](module, frame, unit)
		end
	end
end

-- Tag APIs
function ShadowUF:IsTagReistered(name)
	return self.db.profile.tags[name] or self.modules.Tags.defaultTags[name]
end

function ShadowUF:RegisterTag(name, tag)
	if( not name ) then
		error(L["Cannot register tag, no name passed."])
	end
	
	if( type(data) == "string" ) then
		self.db.profile.tags[name] = tag
	else
		error(L["Cannot register tag %s, string expected got %s."], name, type(tag))
	end
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
